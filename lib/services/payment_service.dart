// lib/services/payment_service.dart
import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/booking_model.dart';
import '../services/notification_service.dart';
import '../services/booking_service.dart';
import '../services/agencies_service.dart';
import '../services/commission_service.dart';

class PaymentResult {
  final bool success;
  final String? message;
  final String? transactionId;
  final double? amount;
  final Map<String, dynamic>? raw;

  PaymentResult({
    required this.success,
    this.message,
    this.transactionId,
    this.amount,
    this.raw,
  });

  String? get paymentIntentId => transactionId;
  @override
  String toString() => 'PaymentResult(success:$success, transactionId:$transactionId, message:$message)';
}

abstract class PaymentProviderAdapter {
  Future<PaymentResult> process({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    required String currency,
  });

  Future<PaymentResult> verify({required String transactionId});
}

class MockProviderAdapter implements PaymentProviderAdapter {
  final double failureRate;
  final int minDelayMs;
  final int maxDelayMs;
  final Random _rnd = Random();

  MockProviderAdapter({
    this.failureRate = 0.0,
    this.minDelayMs = 600,
    this.maxDelayMs = 1000,
  }) : assert(failureRate >= 0 && failureRate <= 1);

  Future<void> _maybeDelay() async {
    final ms = minDelayMs + _rnd.nextInt(max(1, maxDelayMs - minDelayMs + 1));
    await Future.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<PaymentResult> process({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    required String currency,
  }) async {
    await _maybeDelay();
    if (amount <= 0) return PaymentResult(success: false, message: 'المبلغ غير صالح', amount: amount);
    if (paymentMethod.toLowerCase().contains('fail')) return PaymentResult(success: false, message: 'محاكاة فشل الدفع', amount: amount);
    if (_rnd.nextDouble() < failureRate) return PaymentResult(success: false, message: 'محاكاة فشل عشوائي', amount: amount);
    final txId = 'mock-${const Uuid().v4()}';
    final raw = {'provider': 'mock', 'transactionId': txId, 'amount': amount, 'currency': currency, 'paymentMethod': paymentMethod};
    return PaymentResult(success: true, message: 'محاكاة نجاح الدفع', transactionId: txId, amount: amount, raw: raw);
  }

  @override
  Future<PaymentResult> verify({required String transactionId}) async {
    await _maybeDelay();
    final success = transactionId.startsWith('mock-') && _rnd.nextDouble() >= failureRate;
    return PaymentResult(success: success, message: success ? 'محاكاة: تم التحقق' : 'محاكاة: غير مؤكدة', transactionId: transactionId);
  }
}

class PaymentService {
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;
  final BookingService _bookingService;
  final AgenciesService _agenciesService;
  final Uuid _uuid = const Uuid();

  final String _bookingsCollection = 'bookings';
  final String _paymentsCollection = 'payments';
  final String _usersCollection = 'users';

  /// قابل للاستبدال بمزود حقيقي
  PaymentProviderAdapter providerAdapter = MockProviderAdapter();

  /// Constructor: يقبل استدعاء بدون معاملات افتراضية
  PaymentService({
    AgenciesService? agenciesService,
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
    BookingService? bookingService,
  })  : _agenciesService = agenciesService ?? AgenciesService(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationService = notificationService ?? NotificationService(),
        _bookingService = bookingService ?? BookingService();

  // -------------------------
  // Helpers
  // -------------------------
  double _toDoubleSafe(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  Future<PaymentResult> processPayment({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    String currency = 'YER',
    bool useWalletFirst = false,
    double appRateIfDriverFree = 0.04,
    double appRateIfAgencyDriver = 0.08,
    double? agencyRate,
    double govFee = 0.0,
    bool deductGovFeeBeforeCommission = false,
  }) async {
    try {
      debugPrint('PaymentService.processPayment called: bookingId=$bookingId, amount=$amount, paymentMethod=$paymentMethod, currency=$currency, useWalletFirst=$useWalletFirst');

      final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) {
        debugPrint('PaymentService.processPayment: booking not found: $bookingId');
        return PaymentResult(success: false, message: 'الحجز غير موجود.');
      }
      final booking = Booking.fromDocument(bookingSnap);
      final bookingData = bookingSnap.data() ?? {};
      final agencyIdFromDoc = bookingData['agencyId'] ?? bookingData['agency_id'];
      final String? agencyId = agencyIdFromDoc?.toString();

      if (booking.totalPrice > 0 && (booking.totalPrice - amount).abs() > 0.01) {
        debugPrint('PaymentService.processPayment: amount mismatch booking.totalPrice=${booking.totalPrice} amount=$amount');
        return PaymentResult(success: false, message: 'المبلغ المدفوع لا يطابق مبلغ الحجز.', amount: amount);
      }

      if (paymentMethod.toLowerCase() == 'wallet') {
        debugPrint('PaymentService.processPayment: using wallet flow');
        return _processWalletPayment(
          booking: booking,
          amount: amount,
          currency: currency,
          appRateIfDriverFree: appRateIfDriverFree,
          appRateIfAgencyDriver: appRateIfAgencyDriver,
          agencyRate: agencyRate,
          govFee: govFee,
          deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
          agencyId: agencyId,
        );
      }

      if (useWalletFirst) {
        debugPrint('PaymentService.processPayment: checking wallet first for passenger ${booking.passengerId}');
        final userDoc = await _firestore.collection(_usersCollection).doc(booking.passengerId).get();
        final userData = userDoc.data() ?? {};
        final walletBalance = _toDoubleSafe(userData['walletBalance']);
        debugPrint('Passenger walletBalance=$walletBalance');
        if (walletBalance >= amount) {
          debugPrint('PaymentService.processPayment: wallet covers amount, switching to wallet flow');
          return _processWalletPayment(
            booking: booking,
            amount: amount,
            currency: currency,
            appRateIfDriverFree: appRateIfDriverFree,
            appRateIfAgencyDriver: appRateIfAgencyDriver,
            agencyRate: agencyRate,
            govFee: govFee,
            deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
            agencyId: agencyId,
          );
        }
      }

      // استدعاء المزود الخارجي (أو المحاكاة)
      debugPrint('PaymentService.processPayment: calling providerAdapter.process with bookingId=$bookingId amount=$amount paymentMethod=$paymentMethod currency=$currency');
      final providerResult = await providerAdapter.process(bookingId: bookingId, amount: amount, paymentMethod: paymentMethod, currency: currency);
      debugPrint('PaymentService.processPayment: providerResult=$providerResult');

      if (!providerResult.success) {
        debugPrint('PaymentService.processPayment: provider failed: ${providerResult.message}');
        return providerResult;
      }

      final transactionId = providerResult.transactionId ?? _uuid.v4();

      final recordResult = await _recordAndDistributePayment(
        booking: booking,
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
        transactionId: transactionId,
        rawProviderResponse: providerResult.raw,
        appRateIfDriverFree: appRateIfDriverFree,
        appRateIfAgencyDriver: appRateIfAgencyDriver,
        agencyRate: agencyRate,
        govFee: govFee,
        deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
        agencyId: agencyId,
      );

      if (!recordResult.success) {
        debugPrint('PaymentService.processPayment: record/distribute failed: ${recordResult.message}');
        try {
          await _bookingService.cancelBooking(bookingId: booking.id, passengerId: booking.passengerId);
          debugPrint('PaymentService.processPayment: booking cancelled due to failure');
        } catch (cancelErr, cancelSt) {
          debugPrint('PaymentService.processPayment: cancelBooking failed: $cancelErr\n$cancelSt');
        }
        return PaymentResult(success: false, message: recordResult.message);
      }

      final confirmError = await _booking_service_confirmSafe(bookingId: booking.id, paymentIntentId: transactionId, payerId: booking.passengerId);
      if (confirmError != null) {
        debugPrint('PaymentService.processPayment: booking confirm error: $confirmError');
        return PaymentResult(success: false, message: confirmError);
      }

      await bookingRef.update({
        'paidAt': FieldValue.serverTimestamp(),
        'paymentMethod': paymentMethod,
        'transactionId': transactionId,
        'amountPaid': amount,
        'paymentStatus': 'paid',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      try {
        debugPrint('PaymentService.processPayment: sending notification to passenger ${booking.passengerId}');
        await _notificationService.sendNotification(
          userId: booking.passengerId,
          title: 'تم استلام الدفع',
          body: '✅ تم استلام دفعتك بمبلغ ${amount.toStringAsFixed(2)} $currency.',
          type: 'payment',
        );
      } catch (notifErr, notifSt) {
        debugPrint('PaymentService.processPayment: notification send failed: $notifErr\n$notifSt');
      }

      return PaymentResult(success: true, message: providerResult.message ?? 'تم الدفع بنجاح', transactionId: transactionId, amount: amount, raw: providerResult.raw);
    } catch (e, st) {
      if (kDebugMode) debugPrint('PaymentService.processPayment error: $e\n$st');
      return PaymentResult(success: false, message: 'حدث خطأ أثناء معالجة الدفع: ${e.toString()}');
    }
  }

  Future<PaymentResult> _processWalletPayment({
    required Booking booking,
    required double amount,
    required String currency,
    double appRateIfDriverFree = 0.04,
    double appRateIfAgencyDriver = 0.08,
    double? agencyRate,
    double govFee = 0.0,
    bool deductGovFeeBeforeCommission = false,
    String? agencyId,
  }) async {
    final passengerRef = _firestore.collection(_usersCollection).doc(booking.passengerId);
    final driverRef = _firestore.collection(_usersCollection).doc(booking.driverId);
    final txId = 'wallet-${_uuid.v4()}';

    try {
      debugPrint('PaymentService._processWalletPayment: starting wallet flow for booking ${booking.id} amount=$amount');

      // حساب العمولة قبل المعاملة لتجنب عمليات حسابية داخل المعاملة
      final commission = CommissionService.calculateSplit(
        totalAmount: amount,
        govFee: govFee,
        agencyId: agencyId,
        appRateIfDriverFree: appRateIfDriverFree,
        appRateIfAgencyDriver: appRateIfAgencyDriver,
        agencyRate: agencyRate,
        deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
      );

      if (commission.totalAmount.isNaN || commission.driverNetAmount.isNaN) {
        final msg = 'نتيجة حساب العمولة غير صالحة';
        debugPrint('PaymentService._processWalletPayment: $msg');
        return PaymentResult(success: false, message: msg);
      }

      await _firestore.runTransaction((tx) async {
        // 1) اقرأ كل المستندات المطلوبة أولاً
        final passengerSnap = await tx.get(passengerRef);
        if (!passengerSnap.exists) throw Exception('المستخدم غير موجود');
        final passengerData = passengerSnap.data() ?? {};
        final passengerBalance = _toDoubleSafe(passengerData['walletBalance']);
        if (passengerBalance < amount) throw Exception('رصيد المحفظة غير كافٍ');

        DocumentSnapshot? agencySnap;
        DocumentSnapshot? driverSnap;
        if (agencyId != null && agencyId.trim().isNotEmpty) {
          final agencyRef = _firestore.collection('agencies').doc(agencyId);
          agencySnap = await tx.get(agencyRef);
          if (!agencySnap.exists) throw Exception('المكتب غير موجود');
        } else {
          driverSnap = await tx.get(driverRef);
          if (!driverSnap.exists) throw Exception('السائق غير موجود');
        }

        // 2) بعد الانتهاء من كل القراءات، قم بالكتابات
        final paymentDocRef = _firestore.collection(_paymentsCollection).doc();
        final paymentRecord = {
          'bookingId': booking.id,
          'passengerId': booking.passengerId,
          'driverId': booking.driverId,
          'agencyId': agencyId,
          'amount': commission.totalAmount,
          'currency': currency,
          'paymentMethod': 'wallet',
          'transactionId': txId,
          'status': 'paid',
          'split': CommissionService.buildPaymentSplitMap(commission),
          'rawProvider': {'provider': 'wallet'},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        tx.set(paymentDocRef, paymentRecord);
        debugPrint('PaymentService._processWalletPayment: transaction - payment record set id=${paymentDocRef.id}');

        // تحديث أرصدة المكتب أو السائق
        if (agencyId != null && agencyId.trim().isNotEmpty) {
          final agencyRef = _firestore.collection('agencies').doc(agencyId);
          final agencyData = agencySnap!.data() ?? {};
          final currentAgencyBalance = _toDoubleSafe(agencyData['walletBalance']);
          final newAgencyBalance = currentAgencyBalance + commission.agencyCommissionAmount;
          tx.update(agencyRef, {'walletBalance': newAgencyBalance, 'updatedAt': FieldValue.serverTimestamp()});
          debugPrint('PaymentService._processWalletPayment: transaction - agency balance updated from $currentAgencyBalance to $newAgencyBalance');
        } else {
          final driverData = driverSnap!.data() ?? {};
          final currentDriverBalance = _toDoubleSafe(driverData['walletBalance']);
          final newDriverBalance = currentDriverBalance + commission.driverNetAmount;
          tx.update(driverRef, {'walletBalance': newDriverBalance, 'updatedAt': FieldValue.serverTimestamp()});
          debugPrint('PaymentService._processWalletPayment: transaction - driver balance updated from $currentDriverBalance to $newDriverBalance');
        }

        // خصم من محفظة الراكب
        final newPassengerBalance = passengerBalance - amount;
        tx.update(passengerRef, {'walletBalance': newPassengerBalance, 'updatedAt': FieldValue.serverTimestamp()});
        debugPrint('PaymentService._processWalletPayment: transaction - passenger balance updated from $passengerBalance to $newPassengerBalance');

        // تحديث الحجز
        tx.update(_firestore.collection(_bookingsCollection).doc(booking.id), {
          'paymentStatus': 'paid',
          'transactionId': txId,
          'amountPaid': amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('PaymentService._processWalletPayment: transaction - booking updated');
      });

      final confirmError = await _booking_service_confirmSafe(bookingId: booking.id, paymentIntentId: txId, payerId: booking.passengerId);
      if (confirmError != null) {
        debugPrint('PaymentService._processWalletPayment: booking confirm error: $confirmError');
        return PaymentResult(success: false, message: confirmError);
      }

      try {
        await _notificationService.sendNotification(
          userId: booking.passengerId,
          title: 'تم الدفع من المحفظة',
          body: '✅ تم خصم ${amount.toStringAsFixed(2)} من محفظتك للحجز ${booking.id}.',
          type: 'payment',
        );
      } catch (notifErr, notifSt) {
        debugPrint('PaymentService._processWalletPayment: notification failed: $notifErr\n$notifSt');
      }

      return PaymentResult(success: true, message: 'تم الدفع من المحفظة بنجاح', transactionId: txId, amount: amount);
    } catch (e, st) {
      if (kDebugMode) debugPrint('PaymentService._processWalletPayment error: $e\n$st');
      return PaymentResult(success: false, message: e.toString());
    }
  }

  Future<PaymentResult> _recordAndDistributePayment({
    required Booking booking,
    required double amount,
    required String currency,
    required String paymentMethod,
    required String transactionId,
    Map<String, dynamic>? rawProviderResponse,
    double appRateIfDriverFree = 0.04,
    double appRateIfAgencyDriver = 0.08,
    double? agencyRate,
    double govFee = 0.0,
    bool deductGovFeeBeforeCommission = false,
    String? agencyId,
  }) async {
    final bookingRef = _firestore.collection(_bookingsCollection).doc(booking.id);
    final driverRef = _firestore.collection(_usersCollection).doc(booking.driverId);
    final agencyRef = agencyId != null ? _firestore.collection('agencies').doc(agencyId) : null;

    try {
      debugPrint('PaymentService._recordAndDistributePayment: starting transaction for booking ${booking.id} transactionId=$transactionId amount=$amount');

      // فحوصات سريعة قبل المعاملة لتقليل فرص الفشل داخل runTransaction
      if (booking.driverId == null || booking.driverId!.isEmpty) {
        final msg = 'السائق غير محدد في الحجز ${booking.id}';
        debugPrint('PaymentService._recordAndDistributePayment pre-check failed: $msg');
        return PaymentResult(success: false, message: msg);
      }

      // حساب العمولة مسبقًا والتحقق من القيم
      final commission = CommissionService.calculateSplit(
        totalAmount: amount,
        govFee: govFee,
        agencyId: agencyId,
        appRateIfDriverFree: appRateIfDriverFree,
        appRateIfAgencyDriver: appRateIfAgencyDriver,
        agencyRate: agencyRate,
        deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
      );

      debugPrint('PaymentService._recordAndDistributePayment: commission computed: total=${commission.totalAmount}, driverNet=${commission.driverNetAmount}, agency=${commission.agencyCommissionAmount}');

      if (commission.totalAmount.isNaN || commission.driverNetAmount.isNaN) {
        final msg = 'نتيجة حساب العمولة غير صالحة';
        debugPrint('PaymentService._recordAndDistributePayment: $msg');
        return PaymentResult(success: false, message: msg);
      }

      // المعاملة نفسها مع ترتيب صحيح: كل القراءات أولاً ثم الكتابات
      await _firestore.runTransaction((tx) async {
        try {
          debugPrint('PaymentService._recordAndDistributePayment: transaction - fetching booking doc');
          final bookingSnap = await tx.get(bookingRef);
          if (!bookingSnap.exists) throw Exception('الحجز غير موجود داخل المعاملة');

          // اقرأ كل المستندات المطلوبة أولاً
          DocumentSnapshot? agencySnap;
          if (agencyRef != null) {
            agencySnap = await tx.get(agencyRef);
            if (!agencySnap.exists) throw Exception('المكتب غير موجود');
          }

          final driverSnap = await tx.get(driverRef);
          if (!driverSnap.exists) throw Exception('السائق غير موجود');

          // بعد الانتهاء من كل القراءات، قم بالكتابات
          debugPrint('PaymentService._recordAndDistributePayment: transaction - creating payment record');
          final paymentDocRef = _firestore.collection(_paymentsCollection).doc();
          final paymentRecord = {
            'bookingId': booking.id,
            'passengerId': booking.passengerId,
            'driverId': booking.driverId,
            'agencyId': agencyId,
            'amount': commission.totalAmount,
            'currency': currency,
            'paymentMethod': paymentMethod,
            'transactionId': transactionId,
            'status': 'paid',
            'split': CommissionService.buildPaymentSplitMap(commission),
            'rawProvider': rawProviderResponse ?? {},
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          tx.set(paymentDocRef, paymentRecord);
          debugPrint('PaymentService._recordAndDistributePayment: transaction - payment record set id=${paymentDocRef.id}');

          if (agencyRef != null) {
            final agencyData = agencySnap!.data() ?? {};
            final currentAgencyBalance = _toDoubleSafe(agencyData['walletBalance']);
            final newAgencyBalance = currentAgencyBalance + commission.agencyCommissionAmount;
            tx.update(agencyRef, {'walletBalance': newAgencyBalance, 'updatedAt': FieldValue.serverTimestamp()});
            debugPrint('PaymentService._recordAndDistributePayment: transaction - agency balance updated from $currentAgencyBalance to $newAgencyBalance');
          }

          final driverData = driverSnap.data() ?? {};
          final currentDriverBalance = _toDoubleSafe(driverData['walletBalance']);
          final newDriverBalance = currentDriverBalance + commission.driverNetAmount;
          tx.update(driverRef, {'walletBalance': newDriverBalance, 'updatedAt': FieldValue.serverTimestamp()});
          debugPrint('PaymentService._recordAndDistributePayment: transaction - driver balance updated from $currentDriverBalance to $newDriverBalance');

          tx.update(bookingRef, {
            'paymentStatus': 'paid',
            'transactionId': transactionId,
            'amountPaid': amount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('PaymentService._recordAndDistributePayment: transaction - booking updated');
        } catch (innerErr, innerSt) {
          debugPrint('PaymentService._recordAndDistributePayment: transaction inner error: $innerErr\n$innerSt');
          rethrow;
        }
      });

      debugPrint('PaymentService._recordAndDistributePayment: transaction committed successfully for booking ${booking.id}');
      return PaymentResult(success: true, message: 'تم تسجيل وتوزيع الدفع بنجاح', transactionId: transactionId, amount: amount);
    } catch (e, st) {
      if (kDebugMode) debugPrint('PaymentService._recordAndDistributePayment error: $e\n$st');

      String errMsg = 'فشل تسجيل/توزيع الدفع: ${e.toString()}';
      try {
        if (e is FirebaseException) {
          errMsg = 'فشل تسجيل/توزيع الدفع: ${e.code} - ${e.message}';
        }
      } catch (_) {}

      return PaymentResult(success: false, message: errMsg);
    }
  }

  Future<PaymentResult> refundPayment({String? transactionId, String? bookingId, required String reason}) async {
    try {
      QuerySnapshot snap;
      if (transactionId != null) {
        snap = await _firestore.collection(_paymentsCollection).where('transactionId', isEqualTo: transactionId).limit(1).get();
      } else if (bookingId != null) {
        snap = await _firestore.collection(_paymentsCollection).where('bookingId', isEqualTo: bookingId).limit(1).get();
      } else {
        return PaymentResult(success: false, message: 'مطلوب transactionId أو bookingId لبدء الاسترجاع');
      }

      if (snap.docs.isEmpty) return PaymentResult(success: false, message: 'سجل الدفع غير موجود');

      final doc = snap.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '') as String;
      if (status == 'refunded') return PaymentResult(success: false, message: 'تم استرجاع هذه المعاملة سابقاً');

      final paymentId = doc.id;
      final bookingIdFound = data['bookingId'] as String?;
      final passengerId = data['passengerId'] as String?;
      final driverId = data['driverId'] as String?;
      final agencyId = data['agencyId'] as String?;
      final amount = _toDoubleSafe(data['amount']);
      final paymentMethod = (data['paymentMethod'] ?? 'unknown') as String;

      if (paymentMethod == 'wallet') {
        await _firestore.runTransaction((tx) async {
          final paymentRef = _firestore.collection(_paymentsCollection).doc(paymentId);
          final passengerRef = _firestore.collection(_usersCollection).doc(passengerId);
          final driverRef = _firestore.collection(_usersCollection).doc(driverId);
          final agencyRef = agencyId != null ? _firestore.collection('agencies').doc(agencyId) : null;

          final passengerSnap = await tx.get(passengerRef);
          if (!passengerSnap.exists) throw Exception('المستخدم غير موجود');
          final passengerData = passengerSnap.data() ?? {};
          final passengerBalance = _toDoubleSafe(passengerData['walletBalance']);
          tx.update(passengerRef, {'walletBalance': passengerBalance + amount, 'updatedAt': FieldValue.serverTimestamp()});

          if (agencyRef != null) {
            final agencySnap = await tx.get(agencyRef);
            if (!agencySnap.exists) throw Exception('المكتب غير موجود');
            final agencyData = agencySnap.data() ?? {};
            final agencyBalance = _toDoubleSafe(agencyData['walletBalance']);
            final agencyNew = max<double>(0.0, agencyBalance - amount);
            tx.update(agencyRef, {'walletBalance': agencyNew, 'updatedAt': FieldValue.serverTimestamp()});
          } else {
            final driverSnap = await tx.get(driverRef);
            if (!driverSnap.exists) throw Exception('السائق غير موجود');
            final driverData = driverSnap.data() ?? {};
            final driverBalance = _toDoubleSafe(driverData['walletBalance']);
            final driverNew = max<double>(0.0, driverBalance - amount);
            tx.update(driverRef, {'walletBalance': driverNew, 'updatedAt': FieldValue.serverTimestamp()});
          }

          tx.update(paymentRef, {
            'status': 'refunded',
            'refundedAt': FieldValue.serverTimestamp(),
            'refundReason': reason,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (bookingIdFound != null) {
            final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingIdFound);
            tx.update(bookingRef, {
              'paymentStatus': 'refunded',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        });

        if (passengerId != null) {
          try {
            await _notificationService.sendNotification(userId: passengerId, title: 'تم استرجاع المبلغ', body: 'تم استرجاع مبلغ ${amount.toStringAsFixed(2)} إلى محفظتك.', type: 'refund');
          } catch (notifErr, notifSt) {
            debugPrint('PaymentService.refundPayment: notification failed: $notifErr\n$notifSt');
          }
        }

        return PaymentResult(success: true, message: 'تم استرجاع المبلغ بنجاح', transactionId: transactionId, amount: amount);
      }

      return PaymentResult(success: false, message: 'استرجاع المدفوعات عبر المزود الخارجي غير مفعّل في هذه النسخة.');
    } catch (e, st) {
      if (kDebugMode) debugPrint('PaymentService.refundPayment error: $e\n$st');
      return PaymentResult(success: false, message: 'حدث خطأ أثناء محاولة الاسترجاع: $e');
    }
  }

  /// غلاف متوافق مع استدعاءات Providers القديمة
  Future<PaymentResult> refund(String transactionId) async {
    return await refundPayment(transactionId: transactionId, reason: 'Refund requested by system');
  }

  Future<String> getPaymentStatus(String bookingId) async {
    try {
      final snap = await _firestore.collection(_paymentsCollection).where('bookingId', isEqualTo: bookingId).limit(1).get();
      if (snap.docs.isEmpty) return 'unknown';
      final data = snap.docs.first.data();
      return (data['status'] ?? 'unknown') as String;
    } catch (e) {
      if (kDebugMode) debugPrint('PaymentService.getPaymentStatus error: $e');
      return 'unknown';
    }
  }

  Map<String, dynamic> buildDeepLinkPayload({required String bookingId, required double amount, required String paymentMethod, required String callbackUrl}) {
    return {'bookingId': bookingId, 'amount': amount, 'paymentMethod': paymentMethod, 'callbackUrl': callbackUrl, 'timestamp': DateTime.now().toIso8601String()};
  }

  String buildDeepLinkUri({required String schemeHost, required Map<String, dynamic> payload}) {
    final encoded = Uri.encodeComponent(jsonEncode(payload));
    return '$schemeHost://pay?payload=$encoded';
  }

  Future<PaymentResult> confirmPayment({required String transactionId, required String bookingId, required double amount, String? paymentMethod, String currency = 'YER', String? payerId}) async {
    try {
      debugPrint('PaymentService.confirmPayment: verifying transactionId=$transactionId');
      final verifyResult = await providerAdapter.verify(transactionId: transactionId);
      debugPrint('PaymentService.confirmPayment: verifyResult=$verifyResult');
      if (!verifyResult.success) {
        debugPrint('PaymentService.confirmPayment: provider verification failed for $transactionId');
        return PaymentResult(success: false, message: 'فشل التحقق من المزود', transactionId: transactionId);
      }

      final existing = await _firestore.collection(_paymentsCollection).where('transactionId', isEqualTo: transactionId).limit(1).get();
      if (existing.docs.isEmpty) {
        await _firestore.collection(_paymentsCollection).add({
          'bookingId': bookingId,
          'transactionId': transactionId,
          'amount': amount,
          'currency': currency,
          'paymentMethod': paymentMethod ?? 'unknown',
          'status': 'paid',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection(_paymentsCollection).doc(existing.docs.first.id).update({'status': 'paid', 'updatedAt': FieldValue.serverTimestamp()});
      }

      final confirmError = await _booking_service_confirmSafe(bookingId: bookingId, paymentIntentId: transactionId, payerId: payerId ?? '');
      if (confirmError != null) {
        debugPrint('PaymentService.confirmPayment: booking confirm error: $confirmError');
        return PaymentResult(success: false, message: confirmError, transactionId: transactionId);
      }

      return PaymentResult(success: true, message: 'تم تأكيد الدفع', transactionId: transactionId, amount: amount);
    } catch (e, st) {
      if (kDebugMode) debugPrint('PaymentService.confirmPayment error: $e\n$st');
      return PaymentResult(success: false, message: 'خطأ أثناء تأكيد الدفع', transactionId: transactionId);
    }
  }

  Future<String?> _booking_service_confirmSafe({required String bookingId, required String paymentIntentId, required String payerId}) async {
    try {
      debugPrint('PaymentService._booking_service_confirmSafe: calling bookingService.confirmBookingAfterPayment bookingId=$bookingId paymentIntentId=$paymentIntentId');
      return await _bookingService.confirmBookingAfterPayment(bookingId: bookingId, paymentIntentId: paymentIntentId, payerId: payerId);
    } catch (e, st) {
      if (kDebugMode) debugPrint('PaymentService._booking_service_confirmSafe error: $e\n$st');
      return 'فشل تأكيد الحجز على الخادم.';
    }
  }
}

extension on Object {
  operator [](String other) {}
}
