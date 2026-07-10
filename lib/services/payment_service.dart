// lib/services/payment_service.dart
//
// خدمة معالجة المدفوعات المتكاملة.
// - تدعم مزود دفع قابل للتبديل (PaymentProviderAdapter).
// - تسجل المدفوعات في مجموعة "payments" في Firestore.
// - تتعامل مع شحن/خصم محافظ المكاتب (agencies) والمحافظ الشخصية (users).
// - تستخدم CommissionService لحساب تقسيم المبالغ (عمولة التطبيق، عمولة المكتب، صافي السائق).
// - تؤكد الحجز عبر BookingService بعد نجاح الدفع.
// - ترسل إشعارات عبر NotificationService.

import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// بعض الأكواد كانت تتوقع paymentIntentId؛ نعيد transactionId كقيمة افتراضية
  String? get paymentIntentId => transactionId;

  @override
  String toString() => 'PaymentResult(success:$success, transactionId:$transactionId, message:$message)';
}

/// واجهة مزود الدفع القابلة للتبديل
abstract class PaymentProviderAdapter {
  Future<PaymentResult> process({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    required String currency,
  });

  Future<PaymentResult> verify({required String transactionId});
}

/// مزود محاكاة للاختبار المحلي
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

    if (amount <= 0) {
      return PaymentResult(success: false, message: 'المبلغ غير صالح', amount: amount);
    }
    if (paymentMethod.toLowerCase().contains('fail')) {
      return PaymentResult(success: false, message: 'محاكاة فشل الدفع من المزود', amount: amount);
    }

    if (_rnd.nextDouble() < failureRate) {
      return PaymentResult(success: false, message: 'محاكاة فشل عشوائي من المزود', amount: amount);
    }

    final txId = 'mock-${const Uuid().v4()}';
    final raw = {
      'provider': 'mock',
      'status': 'success',
      'transactionId': txId,
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'bookingId': bookingId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    return PaymentResult(
      success: true,
      message: 'محاكاة نجاح الدفع',
      transactionId: txId,
      amount: amount,
      raw: raw,
    );
  }

  @override
  Future<PaymentResult> verify({required String transactionId}) async {
    await _maybeDelay();
    final success = transactionId.startsWith('mock-') && _rnd.nextDouble() >= failureRate;
    return PaymentResult(
      success: success,
      message: success ? 'محاكاة: تم التحقق من المعاملة' : 'محاكاة: المعاملة غير مؤكدة',
      transactionId: transactionId,
    );
  }
}

/// خدمة الدفع الأساسية
class PaymentService {
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;
  final BookingService _bookingService;
  final AgenciesService _agenciesService; // اسم موحّد ومهيأ في الـ ctor
  final Uuid _uuid = const Uuid();

  /// اسماء المجموعات
  final String _bookingsCollection = 'bookings';
  final String _paymentsCollection = 'payments';
  final String _usersCollection = 'users';

  /// مزود الدفع القابل للتبديل (يمكن استبداله بمزود حقيقي)
  PaymentProviderAdapter providerAdapter = MockProviderAdapter();

  PaymentService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
    BookingService? bookingService,
    AgenciesService? agenciesService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationService = notificationService ?? NotificationService(),
        _bookingService = bookingService ?? BookingService(),
        _agenciesService = agenciesService ?? AgenciesService();

  // ============================
  // Helpers
  // ============================

  double _toDoubleSafe(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  // ============================
  // معالجة الدفع العامّة
  // ============================
  Future<PaymentResult> processPayment({
    required String bookingId,
    required double amount,
    required String paymentMethod, // 'wallet' أو اسم مزود/deeplink
    String currency = 'YER',
    bool useWalletFirst = false,
    double appRateIfDriverFree = 0.04,
    double appRateIfAgencyDriver = 0.08,
    double? agencyRate,
    double govFee = 0.0,
    bool deductGovFeeBeforeCommission = false,
  }) async {
    try {
      final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingSnap = await bookingRef.get();

      if (!bookingSnap.exists) {
        return PaymentResult(success: false, message: 'الحجز غير موجود.');
      }

      final booking = Booking.fromDocument(bookingSnap);

      // حاول استخراج agencyId من بيانات المستند مباشرة (لأن نموذج Booking قد لا يحتوي عليه)
      final bookingData = bookingSnap.data() as Map<String, dynamic>? ?? {};
      final agencyIdFromDoc = bookingData['agencyId'] ?? bookingData['agency_id'];
      final String? agencyId = agencyIdFromDoc != null ? agencyIdFromDoc.toString() : null;

      // تحقق مبسط للمبلغ
      if (booking.totalPrice > 0 && (booking.totalPrice - amount).abs() > 0.01) {
        return PaymentResult(success: false, message: 'المبلغ المدفوع لا يطابق مبلغ الحجز.', amount: amount);
      }

      // إذا طلب الدفع من المحفظة فقط
      if (paymentMethod.toLowerCase() == 'wallet') {
        final walletResult = await _processWalletPayment(
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
        return walletResult;
      }

      // خيار: استخدام المحفظة أولاً ثم الباقي عبر مزود خارجي
      if (useWalletFirst) {
        final userDoc = await _firestore.collection(_usersCollection).doc(booking.passengerId).get();
        final userData = userDoc.data() as Map<String, dynamic>? ?? {};
        final walletBalance = _toDoubleSafe(userData['walletBalance']);
        if (walletBalance >= amount) {
          final walletResult = await _processWalletPayment(
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
          return walletResult;
        }
      }

      // معالجة الدفع عبر مزود خارجي
      final providerResult = await providerAdapter.process(
        bookingId: bookingId,
        amount: amount,
        paymentMethod: paymentMethod,
        currency: currency,
      );

      if (!providerResult.success) {
        return providerResult;
      }

      final transactionId = providerResult.transactionId ?? _uuid.v4();

      // سجل الدفع في Firestore وتوزيع الأموال داخل معاملة آمنة
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
        try {
          await _bookingService.cancelBooking(bookingId: booking.id, passengerId: booking.passengerId);
        } catch (e) {
          debugPrint('PaymentService: failed to cancel booking after distribution failure: $e');
        }
        return PaymentResult(success: false, message: recordResult.message);
      }

      // تأكيد الحجز على الخادم عبر BookingService
      final confirmError = await _booking_service_confirmSafe(
        bookingId: booking.id,
        paymentIntentId: transactionId,
        payerId: booking.passengerId,
      );

      if (confirmError != null) {
        return PaymentResult(success: false, message: confirmError);
      }

      // تحديث بيانات الحجز
      await bookingRef.update({
        'paidAt': FieldValue.serverTimestamp(),
        'paymentMethod': paymentMethod,
        'transactionId': transactionId,
        'amountPaid': amount,
        'paymentStatus': 'paid',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // إشعار الراكب
      try {
        await _notificationService.sendNotification(
          userId: booking.passengerId,
          title: 'تم استلام الدفع',
          body: '✅ تم استلام دفعتك للحجز بمبلغ ${amount.toStringAsFixed(2)} $currency.',
          type: 'payment',
        );
      } catch (e) {
        debugPrint('PaymentService.notification error: $e');
      }

      return PaymentResult(
        success: true,
        message: providerResult.message ?? 'تم الدفع بنجاح',
        transactionId: transactionId,
        amount: amount,
        raw: providerResult.raw,
      );
    } catch (e, st) {
      debugPrint('PaymentService.processPayment error: $e\n$st');
      return PaymentResult(success: false, message: 'حدث خطأ أثناء معالجة الدفع.');
    }
  }

  // ============================
  // دفع من المحفظة (wallet)
  // ============================
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
      await _firestore.runTransaction((tx) async {
        final passengerSnap = await tx.get(passengerRef);
        if (!passengerSnap.exists) throw Exception('المستخدم غير موجود');

        final passengerData = passengerSnap.data() as Map<String, dynamic>? ?? {};
        final passengerBalance = _toDoubleSafe(passengerData['walletBalance']);

        if (passengerBalance < amount) throw Exception('رصيد المحفظة غير كافٍ');

        final newPassengerBalance = passengerBalance - amount;
        tx.update(passengerRef, {'walletBalance': newPassengerBalance, 'updatedAt': FieldValue.serverTimestamp()});

        final commission = CommissionService.calculateSplit(
          totalAmount: amount,
          govFee: govFee,
          agencyId: agencyId,
          appRateIfDriverFree: appRateIfDriverFree,
          appRateIfAgencyDriver: appRateIfAgencyDriver,
          agencyRate: agencyRate,
          deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
        );

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

        if (agencyId != null && agencyId.trim().isNotEmpty) {
          final agencyRef = _firestore.collection('agencies').doc(agencyId);
          final agencySnap = await tx.get(agencyRef);
          if (!agencySnap.exists) throw Exception('المكتب غير موجود');
          final agencyData = agencySnap.data() as Map<String, dynamic>? ?? {};
          final currentAgencyBalance = _toDoubleSafe(agencyData['walletBalance']);
          final newAgencyBalance = currentAgencyBalance + commission.agencyCommissionAmount;
          tx.update(agencyRef, {'walletBalance': newAgencyBalance, 'updatedAt': FieldValue.serverTimestamp()});
        } else {
          final driverSnap = await tx.get(driverRef);
          if (!driverSnap.exists) throw Exception('السائق غير موجود');
          final driverData = driverSnap.data() as Map<String, dynamic>? ?? {};
          final currentDriverBalance = _toDoubleSafe(driverData['walletBalance']);
          final newDriverBalance = currentDriverBalance + commission.driverNetAmount;
          tx.update(driverRef, {'walletBalance': newDriverBalance, 'updatedAt': FieldValue.serverTimestamp()});
        }

        tx.update(_firestore.collection(_bookingsCollection).doc(booking.id), {
          'paymentStatus': 'paid',
          'transactionId': txId,
          'amountPaid': amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final confirmError = await _booking_service_confirmSafe(
        bookingId: booking.id,
        paymentIntentId: txId,
        payerId: booking.passengerId,
      );

      if (confirmError != null) {
        return PaymentResult(success: false, message: confirmError);
      }

      try {
        await _notificationService.sendNotification(
          userId: booking.passengerId,
          title: 'تم الدفع من المحفظة',
          body: '✅ تم خصم ${amount.toStringAsFixed(2)} من محفظتك للحجز ${booking.id}.',
          type: 'payment',
        );
      } catch (e) {
        debugPrint('PaymentService.notification error: $e');
      }

      return PaymentResult(success: true, message: 'تم الدفع من المحفظة بنجاح', transactionId: txId, amount: amount);
    } catch (e, st) {
      debugPrint('PaymentService._processWalletPayment error: $e\n$st');
      return PaymentResult(success: false, message: e.toString());
    }
  }

  // ============================
  // تسجيل وتوزيع الدفع (للمزود الخارجي)
  // ============================
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
      await _firestore.runTransaction((tx) async {
        final bookingSnap = await tx.get(bookingRef);
        if (!bookingSnap.exists) throw Exception('الحجز غير موجود داخل المعاملة');

        final commission = CommissionService.calculateSplit(
          totalAmount: amount,
          govFee: govFee,
          agencyId: agencyId,
          appRateIfDriverFree: appRateIfDriverFree,
          appRateIfAgencyDriver: appRateIfAgencyDriver,
          agencyRate: agencyRate,
          deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
        );

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

        if (agencyRef != null) {
          final agencySnap = await tx.get(agencyRef);
          if (!agencySnap.exists) throw Exception('المكتب غير موجود');
          final agencyData = agencySnap.data() as Map<String, dynamic>? ?? {};
          final currentAgencyBalance = _toDoubleSafe(agencyData['walletBalance']);
          final newAgencyBalance = currentAgencyBalance + commission.agencyCommissionAmount;
          tx.update(agencyRef, {'walletBalance': newAgencyBalance, 'updatedAt': FieldValue.serverTimestamp()});
        }

        final driverSnap = await tx.get(driverRef);
        if (!driverSnap.exists) throw Exception('السائق غير موجود');
        final driverData = driverSnap.data() as Map<String, dynamic>? ?? {};
        final currentDriverBalance = _toDoubleSafe(driverData['walletBalance']);
        final newDriverBalance = currentDriverBalance + commission.driverNetAmount;
        tx.update(driverRef, {'walletBalance': newDriverBalance, 'updatedAt': FieldValue.serverTimestamp()});

        tx.update(bookingRef, {
          'paymentStatus': 'paid',
          'transactionId': transactionId,
          'amountPaid': amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return PaymentResult(success: true, message: 'تم تسجيل وتوزيع الدفع بنجاح', transactionId: transactionId, amount: amount);
    } catch (e, st) {
      debugPrint('PaymentService._recordAndDistributePayment error: $e\n$st');
      return PaymentResult(success: false, message: 'فشل تسجيل/توزيع الدفع: $e');
    }
  }

  // ============================
  // استرجاع الأموال (Refund) - مبسّط
  // ============================
  Future<PaymentResult> refundPayment({
    String? transactionId,
    String? bookingId,
    required String reason,
  }) async {
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
          final passengerData = passengerSnap.data() as Map<String, dynamic>? ?? {};
          final passengerBalance = _toDoubleSafe(passengerData['walletBalance']);
          tx.update(passengerRef, {'walletBalance': passengerBalance + amount, 'updatedAt': FieldValue.serverTimestamp()});

          if (agencyRef != null) {
            final agencySnap = await tx.get(agencyRef);
            if (!agencySnap.exists) throw Exception('المكتب غير موجود');
            final agencyData = agencySnap.data() as Map<String, dynamic>? ?? {};
            final agencyBalance = _toDoubleSafe(agencyData['walletBalance']);
            final agencyNew = max<double>(0.0, agencyBalance - amount);
            tx.update(agencyRef, {'walletBalance': agencyNew, 'updatedAt': FieldValue.serverTimestamp()});
          } else {
            final driverSnap = await tx.get(driverRef);
            if (!driverSnap.exists) throw Exception('السائق غير موجود');
            final driverData = driverSnap.data() as Map<String, dynamic>? ?? {};
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
            await _notificationService.sendNotification(
              userId: passengerId,
              title: 'تم استرجاع المبلغ',
              body: 'تم استرجاع مبلغ ${amount.toStringAsFixed(2)} إلى محفظتك.',
              type: 'refund',
            );
          } catch (e) {
            debugPrint('PaymentService.refund notification error: $e');
          }
        }

        return PaymentResult(success: true, message: 'تم استرجاع المبلغ بنجاح', transactionId: transactionId, amount: amount);
      }

      return PaymentResult(success: false, message: 'استرجاع المدفوعات عبر المزود الخارجي غير مفعّل في هذه النسخة. نفّذ الاسترجاع عبر لوحة المزود ثم حدّث سجل الدفع.');
    } catch (e, st) {
      debugPrint('PaymentService.refundPayment error: $e\n$st');
      return PaymentResult(success: false, message: 'حدث خطأ أثناء محاولة الاسترجاع: $e');
    }
  }

  // ============================
  // دوال مساعدة عامة مطلوبة من Providers/واجهات أخرى
  // ============================

  Future<String> getPaymentStatus(String bookingId) async {
    try {
      final snap = await _firestore.collection(_paymentsCollection).where('bookingId', isEqualTo: bookingId).limit(1).get();
      if (snap.docs.isEmpty) return 'unknown';
      final data = snap.docs.first.data() as Map<String, dynamic>;
      return (data['status'] ?? 'unknown') as String;
    } catch (e) {
      debugPrint('PaymentService.getPaymentStatus error: $e');
      return 'unknown';
    }
  }

  Map<String, dynamic> buildDeepLinkPayload({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    required String callbackUrl,
  }) {
    return {
      'bookingId': bookingId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'callbackUrl': callbackUrl,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  String buildDeepLinkUri({required String schemeHost, required Map<String, dynamic> payload}) {
    final encoded = Uri.encodeComponent(jsonEncode(payload));
    return '$schemeHost://pay?payload=$encoded';
  }

  Future<PaymentResult> confirmPayment({
    required String transactionId,
    required String bookingId,
    required double amount,
    String? paymentMethod,
    String currency = 'YER',
    String? payerId, // أصبح اختياريًا لتوافق الاستدعاءات الحالية
  }) async {
    try {
      final verifyResult = await providerAdapter.verify(transactionId: transactionId);
      if (!verifyResult.success) {
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
        await _firestore.collection(_paymentsCollection).doc(existing.docs.first.id).update({
          'status': 'paid',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final confirmError = await _booking_service_confirmSafe(
        bookingId: bookingId,
        paymentIntentId: transactionId,
        payerId: payerId ?? '',
      );

      if (confirmError != null) {
        return PaymentResult(success: false, message: confirmError, transactionId: transactionId);
      }

      return PaymentResult(success: true, message: 'تم تأكيد الدفع', transactionId: transactionId, amount: amount);
    } catch (e, st) {
      debugPrint('PaymentService.confirmPayment error: $e\n$st');
      return PaymentResult(success: false, message: 'خطأ أثناء تأكيد الدفع', transactionId: transactionId);
    }
  }

  Future<String?> _booking_service_confirmSafe({
    required String bookingId,
    required String paymentIntentId,
    required String payerId,
  }) async {
    try {
      return await _bookingService.confirmBookingAfterPayment(
        bookingId: bookingId,
        paymentIntentId: paymentIntentId,
        payerId: payerId,
      );
    } catch (e, st) {
      debugPrint('PaymentService._booking_service_confirmSafe error: $e\n$st');
      return 'فشل تأكيد الحجز على الخادم.';
    }
  }
}
