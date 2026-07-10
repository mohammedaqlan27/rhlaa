// lib/services/payment_service.dart
//
// خدمة معالجة المدفوعات المتكاملة.
// - تدعم مزود دفع قابل للتبديل (PaymentProviderAdapter).
// - تسجل المدفوعات في مجموعة "payments" في Firestore.
// - تتعامل مع شحن/خصم محافظ المكاتب (agencies) والمحافظ الشخصية (users).
// - تستخدم CommissionService لحساب تقسيم المبالغ (عمولة التطبيق، عمولة المكتب، صافي السائق).
// - تؤكد الحجز عبر BookingService بعد نجاح الدفع.
// - ترسل إشعارات عبر NotificationService.
//
// ملاحظات:
// - تأكد من وجود الحقول المناسبة في مستندات Firestore (bookings, users, agencies, payments).
// - هذا الملف يفترض وجود الخدمات: BookingService, NotificationService, AgenciesService, CommissionService.
// - MockProviderAdapter موجود هنا كموفر افتراضي للاختبار. استبدله بمزود حقيقي عند التكامل.

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
  final AgenciesService _agenciesService;
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
  // معالجة الدفع العامّة
  // ============================
  /// processPayment:
  /// - يدعم طرق دفع خارجية (paymentMethod != 'wallet') و الدفع من المحفظة (wallet).
  /// - يسجل عملية الدفع في مجموعة payments.
  /// - يؤكد الحجز عبر BookingService.confirmBookingAfterPayment.
  /// - يوزع الأموال (app commission, agency commission, driver net) ويحدّث محافظ الجهات المعنية.
  Future<PaymentResult> processPayment({
    required String bookingId,
    required double amount,
    required String paymentMethod, // 'wallet' أو اسم مزود/deeplink
    String currency = 'YER',
    bool useWalletFirst = false, // إن أردت محاولة خصم المحفظة أولاً
    double appRateIfDriverFree = 0.04,
    double appRateIfAgencyDriver = 0.08,
    double? agencyRate, // إن وُجد
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
        );
        return walletResult;
      }

      // خيار: استخدام المحفظة أولاً ثم الباقي عبر مزود خارجي (غير مفعل افتراضياً)
      if (useWalletFirst) {
        final userDoc = await _firestore.collection(_usersCollection).doc(booking.passengerId).get();
        final userData = userDoc.data() as Map<String, dynamic>? ?? {};
        final walletBalance = (userData['walletBalance'] ?? 0).toDouble();
        if (walletBalance >= amount) {
          // خصم كامل من المحفظة
          final walletResult = await _processWalletPayment(
            booking: booking,
            amount: amount,
            currency: currency,
            appRateIfDriverFree: appRateIfDriverFree,
            appRateIfAgencyDriver: appRateIfAgencyDriver,
            agencyRate: agencyRate,
            govFee: govFee,
            deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
          );
          return walletResult;
        }
        // خلاف ذلك، ندفع جزء من المحفظة ثم نكمل عبر المزود الخارجي (غير مفصل هنا)
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
      );

      if (!recordResult.success) {
        // إذا فشل التسجيل/التوزيع، حاول إلغاء الحجز لاسترجاع المقاعد
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
        // إذا فشل التأكيد، نحاول التراجع (لا نعيد الأموال هنا تلقائياً)
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
  }) async {
    final passengerRef = _firestore.collection(_usersCollection).doc(booking.passengerId);
    final driverRef = _firestore.collection(_usersCollection).doc(booking.driverId);
    final agencyId = booking.agencyId;

    final txId = 'wallet-${_uuid.v4()}';

    try {
      // معاملة Firestore لضمان التزامن
      await _firestore.runTransaction((tx) async {
        final passengerSnap = await tx.get(passengerRef);
        if (!passengerSnap.exists) throw Exception('المستخدم غير موجود');

        final passengerData = passengerSnap.data() as Map<String, dynamic>? ?? {};
        final passengerBalance = (passengerData['walletBalance'] ?? 0).toDouble();

        if (passengerBalance < amount) throw Exception('رصيد المحفظة غير كافٍ');

        // خصم من رصيد الراكب
        final newPassengerBalance = passengerBalance - amount;
        tx.update(passengerRef, {'walletBalance': newPassengerBalance, 'updatedAt': FieldValue.serverTimestamp()});

        // حساب التقسيم
        final commission = CommissionService.calculateSplit(
          totalAmount: amount,
          govFee: govFee,
          agencyId: agencyId,
          appRateIfDriverFree: appRateIfDriverFree,
          appRateIfAgencyDriver: appRateIfAgencyDriver,
          agencyRate: agencyRate,
          deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
        );

        // سجل الدفع في مجموعة payments
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

        // تحديث رصيد المكتب (إن وُجد) أو رصيد السائق مباشرة
        if (agencyId != null && agencyId.trim().isNotEmpty) {
          // خصم/إضافة إلى رصيد المكتب: عادة المكتب يستلم حصته ثم يدفع للسائق لاحقاً
          final agencyRef = _firestore.collection('agencies').doc(agencyId);
          final agencySnap = await tx.get(agencyRef);
          if (!agencySnap.exists) throw Exception('المكتب غير موجود');
          final agencyData = agencySnap.data() as Map<String, dynamic>? ?? {};
          final currentAgencyBalance = (agencyData['walletBalance'] ?? 0).toDouble();
          final newAgencyBalance = currentAgencyBalance + commission.agencyCommissionAmount;
          tx.update(agencyRef, {'walletBalance': newAgencyBalance, 'updatedAt': FieldValue.serverTimestamp()});
        } else {
          // سائق حر: نضيف صافي المبلغ إلى رصيد السائق مباشرة
          final driverSnap = await tx.get(driverRef);
          if (!driverSnap.exists) throw Exception('السائق غير موجود');
          final driverData = driverSnap.data() as Map<String, dynamic>? ?? {};
          final currentDriverBalance = (driverData['walletBalance'] ?? 0).toDouble();
          final newDriverBalance = currentDriverBalance + commission.driverNetAmount;
          tx.update(driverRef, {'walletBalance': newDriverBalance, 'updatedAt': FieldValue.serverTimestamp()});
        }

        // التطبيق يستلم عمولته (يمكن تسجيلها في وثيقة منفصلة أو تركها في حساب خارجي)
        // هنا نكتفي بتسجيل الحقول في payment record فقط.

        // تحديث حالة الحجز (مؤقت) - التأكيد النهائي يتم بعد الخروج من المعاملة
        tx.update(_firestore.collection(_bookingsCollection).doc(booking.id), {
          'paymentStatus': 'paid',
          'transactionId': txId,
          'amountPaid': amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // بعد نجاح المعاملة، تأكيد الحجز عبر BookingService
      final confirmError = await _booking_service_confirmSafe(
        bookingId: booking.id,
        paymentIntentId: txId,
        payerId: booking.passengerId,
      );

      if (confirmError != null) {
        // حاول التراجع إن لزم (غير مفصل هنا)
        return PaymentResult(success: false, message: confirmError);
      }

      // إشعار الراكب
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
  }) async {
    final bookingRef = _firestore.collection(_bookingsCollection).doc(booking.id);
    final driverRef = _firestore.collection(_usersCollection).doc(booking.driverId);
    final agencyId = booking.agencyId;
    final agencyRef = agencyId != null ? _firestore.collection('agencies').doc(agencyId) : null;

    try {
      await _firestore.runTransaction((tx) async {
        // إعادة جلب الحجز داخل المعاملة للتأكد من الحالة
        final bookingSnap = await tx.get(bookingRef);
        if (!bookingSnap.exists) throw Exception('الحجز غير موجود داخل المعاملة');

        // حساب التقسيم
        final commission = CommissionService.calculateSplit(
          totalAmount: amount,
          govFee: govFee,
          agencyId: agencyId,
          appRateIfDriverFree: appRateIfDriverFree,
          appRateIfAgencyDriver: appRateIfAgencyDriver,
          agencyRate: agencyRate,
          deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
        );

        // سجل الدفع
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

        // توزيع الأموال:
        // 1) إضافة عمولة المكتب إلى رصيد المكتب (إن وُجد)
        if (agencyRef != null) {
          final agencySnap = await tx.get(agencyRef);
          if (!agencySnap.exists) throw Exception('المكتب غير موجود');
          final agencyData = agencySnap.data() as Map<String, dynamic>? ?? {};
          final currentAgencyBalance = (agencyData['walletBalance'] ?? 0).toDouble();
          final newAgencyBalance = currentAgencyBalance + commission.agencyCommissionAmount;
          tx.update(agencyRef, {'walletBalance': newAgencyBalance, 'updatedAt': FieldValue.serverTimestamp()});
        }

        // 2) إضافة صافي السائق إلى رصيد السائق (أو تركه لدفعات لاحقة عبر المكتب)
        final driverSnap = await tx.get(driverRef);
        if (!driverSnap.exists) throw Exception('السائق غير موجود');
        final driverData = driverSnap.data() as Map<String, dynamic>? ?? {};
        final currentDriverBalance = (driverData['walletBalance'] ?? 0).toDouble();

        // إذا كان هناك مكتب، قد يكون منطقك أن المكتب يدفع للسائق لاحقاً.
        // هنا سنضيف صافي السائق مباشرة إلى رصيد السائق (يمكن تغييره حسب سياسة العمل).
        final newDriverBalance = currentDriverBalance + commission.driverNetAmount;
        tx.update(driverRef, {'walletBalance': newDriverBalance, 'updatedAt': FieldValue.serverTimestamp()});

        // 3) تحديث حالة الحجز
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
  /// refundPayment: محاولة استرجاع دفعة مسجلة.
  /// - يبحث عن سجل الدفع في payments حسب transactionId أو bookingId.
  /// - إذا كان الدفع من المحفظة، يعيد المبلغ إلى محفظة الراكب ويخصم من رصيد السائق/المكتب إن أمكن.
  /// - إذا كان الدفع عبر مزود خارجي، يجب استدعاء واجهة المزود (غير مفعّل هنا).
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
      final amount = (data['amount'] ?? 0).toDouble();
      final paymentMethod = (data['paymentMethod'] ?? 'unknown') as String;

      // إذا كانت المحفظة
      if (paymentMethod == 'wallet') {
        // إجراء معاملة لإعادة الأموال
        await _firestore.runTransaction((tx) async {
          final paymentRef = _firestore.collection(_paymentsCollection).doc(paymentId);
          final passengerRef = _firestore.collection(_usersCollection).doc(passengerId);
          final driverRef = _firestore.collection(_usersCollection).doc(driverId);
          final agencyRef = agencyId != null ? _firestore.collection('agencies').doc(agencyId) : null;

          // إعادة رصيد الراكب
          final passengerSnap = await tx.get(passengerRef);
          if (!passengerSnap.exists) throw Exception('المستخدم غير موجود');
          final passengerData = passengerSnap.data() as Map<String, dynamic>? ?? {};
          final passengerBalance = (passengerData['walletBalance'] ?? 0).toDouble();
          tx.update(passengerRef, {'walletBalance': passengerBalance + amount, 'updatedAt': FieldValue.serverTimestamp()});

          // خصم من رصيد السائق أو المكتب إن أمكن
          if (agencyRef != null) {
            final agencySnap = await tx.get(agencyRef);
            if (!agencySnap.exists) throw Exception('المكتب غير موجود');
            final agencyData = agencySnap.data() as Map<String, dynamic>? ?? {};
            final agencyBalance = (agencyData['walletBalance'] ?? 0).toDouble();
            final agencyNew = max(0.0, agencyBalance - amount);
            tx.update(agencyRef, {'walletBalance': agencyNew, 'updatedAt': FieldValue.serverTimestamp()});
          } else {
            final driverSnap = await tx.get(driverRef);
            if (!driverSnap.exists) throw Exception('السائق غير موجود');
            final driverData = driverSnap.data() as Map<String, dynamic>? ?? {};
            final driverBalance = (driverData['walletBalance'] ?? 0).toDouble();
            final driverNew = max(0.0, driverBalance - amount);
            tx.update(driverRef, {'walletBalance': driverNew, 'updatedAt': FieldValue.serverTimestamp()});
          }

          // تحديث سجل الدفع
          tx.update(paymentRef, {
            'status': 'refunded',
            'refundedAt': FieldValue.serverTimestamp(),
            'refundReason': reason,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // تحديث الحجز
          if (bookingIdFound != null) {
            final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingIdFound);
            tx.update(bookingRef, {
              'paymentStatus': 'refunded',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        });

        // إشعار الراكب
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

      // إذا كان الدفع عبر مزود خارجي: هنا يجب استدعاء API المزود لإجراء الاسترجاع
      // في هذا المثال نرجع رسالة تفصيلية تفيد بضرورة تنفيذ الاسترجاع عبر المزود الخارجي.
      return PaymentResult(success: false, message: 'استرجاع المدفوعات عبر المزود الخارجي غير مفعّل في هذه النسخة. نفّذ الاسترجاع عبر لوحة المزود ثم حدّث سجل الدفع.');
    } catch (e, st) {
      debugPrint('PaymentService.refundPayment error: $e\n$st');
      return PaymentResult(success: false, message: 'حدث خطأ أثناء محاولة الاسترجاع: $e');
    }
  }

  // ============================
  // دوال مساعدة
  // ============================
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
