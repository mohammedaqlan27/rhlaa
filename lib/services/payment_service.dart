// lib/services/payment_service.dart
import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';

/// نتيجة موحّدة لعمليات الدفع
class PaymentResult {
  final bool success;
  final String? message;
  final String? transactionId;
  final double? amount;
  final Map<String, dynamic>? raw; // ردّ مزود الدفع الخام (للتدقيق)

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

/// واجهة مزوّد الدفع (adapter)
abstract class PaymentProviderAdapter {
  /// محاكاة أو تنفيذ عملية الدفع الفعلية
  /// يعيد PaymentResult (ناجح أو فاشل)
  Future<PaymentResult> process({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    required String currency,
  });

  /// (اختياري) تحقق من حالة معاملة موجودة لدى المزود
  Future<PaymentResult> verify({
    required String transactionId,
  });
}

/// Adapter تجريبي للمراحل الاختبارية (sandbox) مع إعدادات قابلة للتعديل
class MockProviderAdapter implements PaymentProviderAdapter {
  final double failureRate; // 0.0 .. 1.0
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

    // حالات فشل محددة للاختبار: amount <= 0 أو paymentMethod يحتوي 'fail'
    if (amount <= 0) {
      return PaymentResult(success: false, message: 'المبلغ غير صالح', amount: amount);
    }
    if (paymentMethod.toLowerCase().contains('fail')) {
      return PaymentResult(success: false, message: 'محاكاة فشل الدفع من المزود', amount: amount);
    }

    // فشل عشوائي حسب failureRate
    if (_rnd.nextDouble() < failureRate) {
      return PaymentResult(success: false, message: 'محاكاة فشل عشوائي من المزود', amount: amount);
    }

    // نجاح: transactionId وهمي و raw response
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

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final Uuid _uuid = const Uuid();

  final String _bookingsCollection = 'bookings';

  /// Adapter المستخدم حالياً؛ افتراضياً Mock (sandbox).
  /// عند الانتقال إلى مزود حقيقي، استبدل هذا الـ adapter بواحد يطبّق PaymentProviderAdapter.
  PaymentProviderAdapter providerAdapter = MockProviderAdapter();

  PaymentService();

  /// معالجة دفع لحجز محدد عبر adapter (sandbox أو حقيقي)
  /// يعيد PaymentResult موحّد يصف النتيجة.
  Future<PaymentResult> processPayment({
    required String bookingId,
    required double amount,
    required String paymentMethod, // مثال: 'yemenpay', 'bank_transfer', 'stc_pay'
    String currency = 'YER',
  }) async {
    try {
      final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingSnap = await bookingRef.get();

      if (!bookingSnap.exists) {
        return PaymentResult(success: false, message: 'الحجز غير موجود.');
      }

      final booking = Booking.fromDocument(bookingSnap);

      // تحقق من أن المبلغ المتوقع يطابق مبلغ الحجز (مرن: إذا كان totalPrice == 0 نتجاهل)
      if (booking.totalPrice > 0 && (booking.totalPrice - amount).abs() > 0.01) {
        return PaymentResult(success: false, message: 'المبلغ المدفوع لا يطابق مبلغ الحجز.', amount: amount);
      }

      // استدعاء adapter لمعالجة الدفع (قد يكون محاكاة أو استدعاء API حقيقي)
      final providerResult = await providerAdapter.process(
        bookingId: bookingId,
        amount: amount,
        paymentMethod: paymentMethod,
        currency: currency,
      );

      if (!providerResult.success) {
        // فشل من المزود: لا نغيّر حالة الحجز
        return providerResult;
      }

      // نجاح المزود: نحدّث الحجز داخل معاملة لضمان الاتساق
      final transactionId = providerResult.transactionId ?? _uuid.v4();
      await _firestore.runTransaction((tx) async {
        final freshSnap = await tx.get(bookingRef);
        if (!freshSnap.exists) throw Exception('الحجز اختفى أثناء المعاملة.');

        // تحديث الحقول بصيغة camelCase فقط
        tx.update(bookingRef, {
          'paymentStatus': 'paid',
          'paidAt': FieldValue.serverTimestamp(),
          'paymentMethod': paymentMethod,
          'transactionId': transactionId,
          'amountPaid': amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // إرسال إشعار للمستخدم (خارج المعاملة)
      try {
        await _notificationService.sendNotification(
          userId: booking.passengerId,
          title: 'تم استلام الدفع',
          body: '✅ تم استلام دفعتك للحجز رقم $bookingId بمبلغ ${amount.toStringAsFixed(2)} $currency.',
          type: 'payment',
        );
      } catch (e) {
        debugPrint('PaymentService.notification error: $e');
      }

      // أعد نتيجة المزود (مع transactionId)
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

  /// تأكيد الدفع (مفيد للـ webhooks أو عمليات التحقق الخارجية)
  /// يعيد PaymentResult
  Future<PaymentResult> confirmPayment({
    required String bookingId,
    required String transactionId,
    required double amount,
    String paymentMethod = 'unknown',
    String currency = 'YER',
  }) async {
    try {
      final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) return PaymentResult(success: false, message: 'الحجز غير موجود.');

      // تحديث بصيغة camelCase فقط
      await bookingRef.update({
        'paymentStatus': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'transactionId': transactionId,
        'paymentMethod': paymentMethod,
        'amountPaid': amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final booking = Booking.fromDocument(await bookingRef.get());

      // إرسال إشعار
      try {
        await _notificationService.sendNotification(
          userId: booking.passengerId,
          title: 'تم تأكيد الدفع',
          body: '✅ تم تأكيد دفعتك للحجز رقم $bookingId.',
          type: 'payment',
        );
      } catch (e) {
        debugPrint('PaymentService.confirmPayment notification error: $e');
      }

      return PaymentResult(success: true, message: 'تم تأكيد الدفع', transactionId: transactionId, amount: amount);
    } catch (e, st) {
      debugPrint('PaymentService.confirmPayment error: $e\n$st');
      return PaymentResult(success: false, message: 'فشل تأكيد الدفع.');
    }
  }

  /// طلب استرجاع (Refund) لمبلغ الحجز.
  Future<PaymentResult> refundPayment({
    required String bookingId,
    required double amount,
    String reason = 'user_request',
  }) async {
    try {
      final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) return PaymentResult(success: false, message: 'الحجز غير موجود.');

      final booking = Booking.fromDocument(bookingSnap);

      // تحقق مبدئي: هل الحجز مدفوع؟
      final currentStatus = booking.paymentStatus.toLowerCase();
      if (currentStatus != 'paid') {
        return PaymentResult(success: false, message: 'لا يمكن استرجاع مبلغ غير مدفوع.');
      }

      final refundId = _uuid.v4();

      await bookingRef.update({
        'paymentStatus': 'refund_pending',
        'refundRequestedAt': FieldValue.serverTimestamp(),
        'refundId': refundId,
        'refundAmount': amount,
        'refundReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      try {
        await _notificationService.sendNotification(
          userId: booking.passengerId,
          title: 'طلب استرجاع',
          body: '🔁 تم استلام طلب استرجاع لمبلغ ${amount.toStringAsFixed(2)}. سنوافيك بالتحديثات.',
          type: 'refund',
        );
      } catch (e) {
        debugPrint('PaymentService.refundPayment notification error: $e');
      }

      return PaymentResult(success: true, message: 'تم تسجيل طلب الاسترجاع', transactionId: refundId, amount: amount);
    } catch (e, st) {
      debugPrint('PaymentService.refundPayment error: $e\n$st');
      return PaymentResult(success: false, message: 'فشل طلب الاسترجاع.');
    }
  }

  /// تأكيد نجاح الاسترجاع (يُستخدم بعد استلام رد من بوابة الدفع)
  Future<PaymentResult> confirmRefund({
    required String bookingId,
    required String refundId,
    required double refundedAmount,
  }) async {
    try {
      final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) return PaymentResult(success: false, message: 'الحجز غير موجود.');

      await bookingRef.update({
        'paymentStatus': 'refunded',
        'refundConfirmedAt': FieldValue.serverTimestamp(),
        'refundedAmount': refundedAmount,
        'refundId': refundId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final booking = Booking.fromDocument(await bookingRef.get());

      try {
        await _notificationService.sendNotification(
          userId: booking.passengerId,
          title: 'تم استرجاع المبلغ',
          body: '✅ تم استرجاع مبلغ ${refundedAmount.toStringAsFixed(2)} بنجاح.',
          type: 'refund',
        );
      } catch (e) {
        debugPrint('PaymentService.confirmRefund notification error: $e');
      }

      return PaymentResult(success: true, message: 'تم تأكيد الاسترجاع', amount: refundedAmount, transactionId: refundId);
    } catch (e, st) {
      debugPrint('PaymentService.confirmRefund error: $e\n$st');
      return PaymentResult(success: false, message: 'فشل تأكيد الاسترجاع.');
    }
  }

  /// استعلام عن حالة الدفع الحالية لحجز
  Future<String> getPaymentStatus(String bookingId) async {
    try {
      final snap = await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      if (!snap.exists) return 'not_found';
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final status = data['paymentStatus'] ?? 'unknown';
      return status.toString();
    } catch (e, st) {
      debugPrint('PaymentService.getPaymentStatus error: $e\n$st');
      return 'error';
    }
  }

  /// بناء payload ل deep link أو QR لاختبار التكامل مع تطبيقات التحويل
  /// يُرجى الاتفاق مع الطرف الآخر على صيغة الـ callbackUrl وحقول الـ payload
  Map<String, dynamic> buildDeepLinkPayload({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    String currency = 'YER',
    required String callbackUrl, // مثال: myapp://payment-callback
  }) {
    final payload = {
      'bookingId': bookingId,
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'callbackUrl': callbackUrl,
      'nonce': _uuid.v4(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    return payload;
  }

  /// تحويل payload إلى URI string (يمكن تحويلها إلى QR)
  String buildDeepLinkUri({
    required String schemeHost, // مثال: 'yemenpay://pay'
    required Map<String, dynamic> payload,
  }) {
    // نضع الـ payload كـ JSON مشفّر في query param 'data'
    final encoded = Uri.encodeComponent(jsonEncode(payload));
    return '$schemeHost?data=$encoded';
  }
}
