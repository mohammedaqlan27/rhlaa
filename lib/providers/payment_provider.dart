// lib/providers/payment_provider.dart
//
// مزود (Provider) لإدارة حالة الدفع في الواجهة.
// - يربط PaymentService مع CommissionService لعرض معاينة التقسيم (العمولات) قبل الدفع.
// - يدعم تنفيذ الدفع عبر PaymentService مع تمرير إعدادات العمولة (appRate, agencyRate, govFee).
// - يحتفظ بحالة التحميل، رسائل الخطأ/النجاح، ومعاينة نتيجة التقسيم الأخيرة.
//
// الاستخدام:
// 1. استدعاء previewCommission(...) لعرض ما سيحصل عليه كل طرف قبل تنفيذ الدفع.
// 2. استدعاء executePayment(...) لبدء عملية الدفع الفعلية وتمرير نفس إعدادات العمولة إن رغبت.

import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import '../services/commission_service.dart';

class PaymentProvider with ChangeNotifier {
  final PaymentService _paymentService = PaymentService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _lastTransactionId;
  String _currentPaymentStatus = 'unknown';

  // معاينة نتيجة التقسيم (العمولات) الأخيرة
  CommissionResult? _lastCommissionResult;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get lastTransactionId => _lastTransactionId;
  String get currentPaymentStatus => _currentPaymentStatus;
  CommissionResult? get lastCommissionResult => _lastCommissionResult;

  /// معاينة حساب العمولة قبل الدفع.
  /// يمكنك تمرير agencyId=null للسائق الحر.
  /// يعيد CommissionResult جاهز للعرض في الواجهة.
  CommissionResult previewCommission({
    required double totalAmount,
    double govFee = 0.0,
    String? agencyId,
    double appRateIfDriverFree = 0.04,
    double appRateIfAgencyDriver = 0.08,
    double? agencyRate,
    bool deductGovFeeBeforeCommission = false,
  }) {
    final result = CommissionService.calculateSplit(
      totalAmount: totalAmount,
      govFee: govFee,
      agencyId: agencyId,
      appRateIfDriverFree: appRateIfDriverFree,
      appRateIfAgencyDriver: appRateIfAgencyDriver,
      agencyRate: agencyRate,
      deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
    );
    _lastCommissionResult = result;
    notifyListeners();
    return result;
  }

  /// معالجة عملية دفع جديدة
  ///
  /// تمت إضافة معلمات اختيارية لتمرير إعدادات العمولة و govFee إلى PaymentService.
  /// إذا لم تمرر إعدادات العمولة، سيستخدم PaymentService القيم الافتراضية داخله.
  Future<bool> executePayment({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    String currency = 'YER',

    // إعدادات العمولة (اختياري)
    double appRateIfDriverFree = 0.04,
    double appRateIfAgencyDriver = 0.08,
    double? agencyRate,
    String? agencyId,
    double govFee = 0.0,
    bool deductGovFeeBeforeCommission = false,

    // خيارات سلوكية
    bool useWalletFirst = false,
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      // احسب معاينة العمولة قبل الدفع (للعرض أو التدقيق)
      _lastCommissionResult = CommissionService.calculateSplit(
        totalAmount: amount,
        govFee: govFee,
        agencyId: agencyId,
        appRateIfDriverFree: appRateIfDriverFree,
        appRateIfAgencyDriver: appRateIfAgencyDriver,
        agencyRate: agencyRate,
        deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
      );
      notifyListeners();

      final result = await _paymentService.processPayment(
        bookingId: bookingId,
        amount: amount,
        paymentMethod: paymentMethod,
        currency: currency,
        useWalletFirst: useWalletFirst,
        appRateIfDriverFree: appRateIfDriverFree,
        appRateIfAgencyDriver: appRateIfAgencyDriver,
        agencyRate: agencyRate,
        govFee: govFee,
        deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
      );

      if (result.success) {
        _successMessage = result.message ?? 'تمت عملية الدفع بنجاح ✅';
        _lastTransactionId = result.transactionId;
        _currentPaymentStatus = 'paid';
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.message ?? 'فشلت عملية الدفع.';
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'خطأ في الدفع: $e';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// طلب استرجاع مبلغ
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
        reason: reason,
      );

      if (result.success) {
        _successMessage = result.message ?? 'تم طلب الاسترجاع بنجاح';
        _currentPaymentStatus = 'refund_pending';
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.message ?? 'فشل طلب الاسترجاع';
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'خطأ أثناء الاسترجاع: $e';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// الاستعلام عن حالة الدفع
  Future<void> checkPaymentStatus(String bookingId) async {
    _setLoading(true);
    _clearMessages();

    try {
      _currentPaymentStatus = await _paymentService.getPaymentStatus(bookingId);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'تعذر جلب الحالة.';
      _setLoading(false);
      notifyListeners();
    }
  }

  /// إنشاء روابط الدفع (deep link)
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

  // ============================
  // Helpers
  // ============================
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  void resetProvider() {
    _isLoading = false;
    _errorMessage = null;
    _successMessage = null;
    _lastTransactionId = null;
    _currentPaymentStatus = 'unknown';
    _lastCommissionResult = null;
    notifyListeners();
  }
}
