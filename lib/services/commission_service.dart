// lib/services/commission_service.dart
//
// Utility مستقل لحساب تقسيم المدفوعات والعمولات.
// يُستدعى من payment_service.dart أو أي مكان يحتاج حساب العمولة.
// يعيد CommissionResult يحتوي على النسب والمبالغ المفصّلة.

import 'dart:math';

/// نتيجة حساب العمولة وتقسيم المبلغ
class CommissionResult {
  final double totalAmount; // المبلغ الإجمالي المدفوع من الراكب
  final double govFee; // رسوم الحكومة الثابتة
  final String? agencyId; // null => سائق حر
  final double appCommissionRate; // نسبة التطبيق المطبقة
  final double appCommissionAmount; // قيمة العمولة للتطبيق
  final double? agencyCommissionRate; // نسبة المكتب إن وُجد
  final double agencyCommissionAmount; // قيمة العمولة للمكتب
  final double driverNetAmount; // المبلغ الصافي الذي يستلمه السائق (بعد خصم كل شيء)
  final double platformReceives; // إجمالي ما يستلمه التطبيق
  final double roundingDelta; // الفرق الناتج عن التقريب (للتدقيق المالي)

  CommissionResult({
    required this.totalAmount,
    required this.govFee,
    required this.agencyId,
    required this.appCommissionRate,
    required this.appCommissionAmount,
    required this.agencyCommissionRate,
    required this.agencyCommissionAmount,
    required this.driverNetAmount,
    required this.platformReceives,
    required this.roundingDelta,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalAmount': totalAmount,
      'govFee': govFee,
      'agencyId': agencyId,
      'appCommissionRate': appCommissionRate,
      'appCommissionAmount': appCommissionAmount,
      'agencyCommissionRate': agencyCommissionRate,
      'agencyCommissionAmount': agencyCommissionAmount,
      'driverNetAmount': driverNetAmount,
      'platformReceives': platformReceives,
      'roundingDelta': roundingDelta,
    };
  }

  @override
  String toString() => toMap().toString();
}

/// خدمة حساب العمولة (Utility)
class CommissionService {
  CommissionService._();

  /// تقريب آمن إلى منزلتين عشريتين
  static double _round2(double v) => (v * 100).roundToDouble() / 100.0;

  /// التحقق من صحة النسبة (بين 0 و 1)
  static double _normalizeRate(double? rate, {required double fallback}) {
    if (rate == null || rate.isNaN || rate < 0 || rate > 1) return fallback;
    return rate;
  }

  /// حساب تقسيم المبلغ لرحلة مفردة.
  static CommissionResult calculateSplit({
    required double totalAmount,
    double govFee = 0.0,
    String? agencyId,
    double appRateIfDriverFree = 0.04,
    double appRateIfAgencyDriver = 0.08,
    double? agencyRate,
    bool deductGovFeeBeforeCommission = false,
  }) {
    final safeTotal = totalAmount.isFinite && totalAmount > 0 ? totalAmount : 0.0;
    final safeGovFee = govFee.isFinite && govFee > 0 ? govFee : 0.0;

    final bool hasAgency = agencyId != null && (agencyId.trim().isNotEmpty);
    final double appRate = _normalizeRate(
      hasAgency ? appRateIfAgencyDriver : appRateIfDriverFree,
      fallback: hasAgency ? 0.08 : 0.04,
    );

    final double normalizedAgencyRate = _normalizeRate(agencyRate, fallback: 0.0);

    // 1. تحديد الوعاء الذي تُحسب عليه العمولة
    final double baseForCommission = deductGovFeeBeforeCommission
        ? max(0.0, safeTotal - safeGovFee)
        : safeTotal;

    // 2. حساب مبالغ العمولة
    final double rawAppCommission = baseForCommission * appRate;
    final double rawAgencyCommission = hasAgency ? baseForCommission * normalizedAgencyRate : 0.0;

    // --- التعديل الجوهري هنا ---
    // 3. حساب المبلغ الصافي للسائق:
    // الصافي = (المبلغ الكلي) - (عمولة التطبيق) - (عمولة المكتب) - (رسوم الحكومة)
    // قمنا بطرح safeGovFee لأنها ليست من حق السائق بل تذهب للحكومة.
    final double rawDriverNet = safeTotal - rawAppCommission - rawAgencyCommission - safeGovFee;

    // 4. تقريب القيم للتعامل المالي الصحيح
    final double appCommissionAmount = _round2(rawAppCommission);
    final double agencyCommissionAmount = _round2(rawAgencyCommission);
    final double driverNetAmount = max(0.0, _round2(rawDriverNet)); // ضمان عدم وجود صافي سالب
    final double finalGovFee = _round2(safeGovFee);

    final double platformReceives = appCommissionAmount;

    // 5. تحديث حساب فرق التقريب (Rounding Delta)
    // لضمان أن مجموع (التطبيق + المكتب + السائق + الحكومة) يساوي تماماً المبلغ الكلي
    final double roundingDelta = _round2(
        safeTotal - (appCommissionAmount + agencyCommissionAmount + driverNetAmount + finalGovFee)
    );

    return CommissionResult(
      totalAmount: _round2(safeTotal),
      govFee: finalGovFee,
      agencyId: agencyId,
      appCommissionRate: appRate,
      appCommissionAmount: appCommissionAmount,
      agencyCommissionRate: hasAgency ? normalizedAgencyRate : null,
      agencyCommissionAmount: agencyCommissionAmount,
      driverNetAmount: driverNetAmount,
      platformReceives: platformReceives,
      roundingDelta: roundingDelta,
    );
  }

  /// حساب تقسيم لمبلغ مقسوم على عدد مقاعد
  static CommissionResult calculateSplitForSeats({
    required double pricePerSeat,
    required int seatsCount,
    double govFeePerSeat = 0.0,
    String? agencyId,
    double appRateIfDriverFree = 0.04,
    double appRateIfAgencyDriver = 0.08,
    double? agencyRate,
    bool deductGovFeeBeforeCommission = false,
  }) {
    final safeSeats = max(0, seatsCount);
    final totalAmount = _round2(pricePerSeat * safeSeats);
    final totalGovFee = _round2(govFeePerSeat * safeSeats);
    return calculateSplit(
      totalAmount: totalAmount,
      govFee: totalGovFee,
      agencyId: agencyId,
      appRateIfDriverFree: appRateIfDriverFree,
      appRateIfAgencyDriver: appRateIfAgencyDriver,
      agencyRate: agencyRate,
      deductGovFeeBeforeCommission: deductGovFeeBeforeCommission,
    );
  }

  static Map<String, dynamic> buildPaymentSplitMap(CommissionResult result) {
    return {
      ...result.toMap(),
      'calculatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}