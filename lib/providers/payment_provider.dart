// lib/providers/payment_provider.dart
import 'package:flutter/material.dart';
import '../services/payment_service.dart';

class PaymentProvider with ChangeNotifier {
  final PaymentService _paymentService = PaymentService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _lastTransactionId;
  String _currentPaymentStatus = 'unknown';

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get lastTransactionId => _lastTransactionId;
  String get currentPaymentStatus => _currentPaymentStatus;

  /// معالجة عملية دفع جديدة لحجز محدد
  Future<bool> executePayment({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    String currency = 'YER',
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      final result = await _paymentService.processPayment(
        bookingId: bookingId,
        amount: amount,
        paymentMethod: paymentMethod,
        currency: currency,
      );

      if (result.success) {
        _successMessage = result.message ?? 'تمت عملية الدفع بنجاح ✅';
        _lastTransactionId = result.transactionId;
        _currentPaymentStatus = 'paid';
        _setLoading(false);
        return true;
      } else {
        _errorMessage = result.message ?? 'فشلت عملية الدفع، يرجى المحاولة لاحقاً.';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع أثناء معالجة الدفع: $e';
      _setLoading(false);
      return false;
    }
  }

  /// طلب استرجاع مبلغ مالي لحجز ملغى
  Future<bool> requestRefund({
    required String bookingId,
    required double amount,
    String reason = 'user_request',
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      final result = await _paymentService.refundPayment(
        bookingId: bookingId,
        amount: amount,
        reason: reason,
      );

      if (result.success) {
        _successMessage = result.message ?? 'تم تسجيل طلب استرجاع المبلغ بنجاح 🔁';
        _currentPaymentStatus = 'refund_pending';
        _setLoading(false);
        return true;
      } else {
        _errorMessage = result.message ?? 'تعذر تقديم طلب الاسترجاع.';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'خطأ أثناء طلب الاسترجاع: $e';
      _setLoading(false);
      return false;
    }
  }

  /// الاستعلام عن حالة الدفع الحالية للحجز من السيرفر مباشرة
  Future<void> checkPaymentStatus(String bookingId) async {
    _setLoading(true);
    _clearMessages();

    try {
      _currentPaymentStatus = await _paymentService.getPaymentStatus(bookingId);
      _setLoading(false);
    } catch (e) {
      _errorMessage = 'تعذر جلب حالة الدفع الحالية.';
      _setLoading(false);
    }
  }

  /// إنشاء روابط الدفع العميق (Deep Links) للبوابات المحلية (مثل الكريمي، محفظة جوالي، إلخ)
  String generateDeepLink({
    required String schemeHost,
    required String bookingId,
    required double amount,
    required String paymentMethod,
    required String callbackUrl,
  }) {
    final payload = _paymentService.buildDeepLinkPayload(
      bookingId: bookingId,
      amount: amount,
      paymentMethod: paymentMethod,
      callbackUrl: callbackUrl,
    );
    return _paymentService.buildDeepLinkUri(schemeHost: schemeHost, payload: payload);
  }

  // ميثود داخلي لإدارة حالة التحميل
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // تصفير الرسائل لتفادي بقاء الأخطاء القديمة في الواجهة
  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  /// تنظيف عام للحالة عند الخروج من شاشات الدفع
  void resetProvider() {
    _isLoading = false;
    _errorMessage = null;
    _successMessage = null;
    _lastTransactionId = null;
    _currentPaymentStatus = 'unknown';
    notifyListeners();
  }
}