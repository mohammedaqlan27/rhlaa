// lib/services/commission_service.dart
//
// Utility مستقل لحساب تقسيم المدفوعات والعمولات.
// يُستدعى من payment_service.dart أو أي مكان يحتاج حساب العمولة.
// يعيد CommissionResult يحتوي على النسب والمبالغ المفصّلة.
//
// الاستخدام النموذجي:
// final result = CommissionService.calculateSplit(
//   totalAmount: 100.0,
//   govFee: 2.0,
//   agencyId: 'agency123', // أو null للسائق الحر
//   appRateIfDriverFree: 0.04, // 4% للسائق الحر
//   appRateIfAgencyDriver: 0.08, // 8% إذا تابع لمكتب
//   agencyRate: 0.08, // نسبة المكتب من المبلغ (إن وُجد)
// );
//
// ثم استخدم result.appCommissionAmount, result.driverNetAmount، إلخ.

import 'dart:math';

/// نتيجة حساب العمولة وتقسيم المبلغ
class CommissionResult {
  final double totalAmount; // المبلغ الإجمالي المدفوع من الراكب (قبل أي خصومات)
  final double govFee; // رسوم الحكومة الثابتة (إن وُجدت) تُخصم قبل حساب العمولة أم بعد؟ (نستخدمها كحقل مرجعي)
  final String? agencyId; // null => سائق حر
  final double appCommissionRate; // نسبة التطبيق المطبقة (مثلاً 0.04)
  final double appCommissionAmount; // قيمة العمولة للتطبيق
  final double? agencyCommissionRate; // نسبة المكتب إن وُجد (مثلاً 0.08)
  final double agencyCommissionAmount; // قيمة العمولة للمكتب (0 إذا لا يوجد مكتب)
  final double driverNetAmount; // المبلغ الصافي الذي يستلمه السائق بعد خصم العمولة والمصاريف إن وُجدت
  final double platformReceives; // إجمالي ما يستلمه التطبيق (قد يساوي appCommissionAmount)
  final double roundingDelta; // الفرق الناتج عن التقريب (للتدقيق إن لزم)

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
  CommissionService._(); // لا يمكن إنشاء مثيل

  /// تقريب آمن إلى منزلتين عشريتين
  static double _round2(double v) => (v * 100).roundToDouble() / 100.0;

  /// التحقق من صحة النسبة (بين 0 و 1)
  static double _normalizeRate(double? rate, {required double fallback}) {
    if (rate == null) return fallback;
    if (rate.isNaN) return fallback;
    if (rate < 0) return 0.0;
    if (rate > 1) return fallback;
    return rate;
  }

  /// حساب تقسيم المبلغ لرحلة مفردة.
  ///
  /// [totalAmount] = المبلغ الإجمالي المدفوع من الراكب (قد يشمل govFee أو لا).
  /// [govFee] = رسوم الحكومة الثابتة المرتبطة بالرحلة (تُعرض في النتيجة، لا نخصمها تلقائياً من الحساب هنا إلا إذا طلبت ذلك).
  /// [agencyId] = معرف المكتب إن وُجد؛ إذا كان null => سائق حر.
  /// [appRateIfDriverFree] = نسبة التطبيق عندما السائق حر (مثلاً 0.04).
  /// [appRateIfAgencyDriver] = نسبة التطبيق عندما السائق تابع لمكتب (مثلاً 0.08).
  /// [agencyRate] = نسبة المكتب من المبلغ (مثلاً 0.08). إذا null أو 0 => لا يوجد مكتب.
  /// [deductGovFeeBeforeCommission] = إذا true نخصم govFee من المبلغ قبل حساب العمولة (بعض السياسات تفعل ذلك).
  ///
  /// تُعيد CommissionResult مع القيم المقربة إلى منزلتين عشريتين.
  static CommissionResult calculateSplit({
    required double totalAmount,
    double govFee = 0.0,
    String? agencyId,
    double appRateIfDriverFree = 0.04,
    double appRateIfAgencyDriver = 0.08,
    double? agencyRate,
    bool deductGovFeeBeforeCommission = false,
  }) {
    // تأكيد القيم الأساسية
    final safeTotal = totalAmount.isFinite && totalAmount > 0 ? totalAmount : 0.0;
    final safeGovFee = govFee.isFinite && govFee > 0 ? govFee : 0.0;

    // تحديد نسبة التطبيق حسب وجود مكتب أم لا
    final bool hasAgency = agencyId != null && (agencyId.trim().isNotEmpty);
    final double appRate = _normalizeRate(
      hasAgency ? appRateIfAgencyDriver : appRateIfDriverFree,
      fallback: hasAgency ? 0.08 : 0.04,
    );

    final double normalizedAgencyRate = _normalizeRate(agencyRate, fallback: 0.0);

    // المبلغ الذي سيُحتسب عليه العمولة
    final double baseForCommission = deductGovFeeBeforeCommission ? max(0.0, safeTotal - safeGovFee) : safeTotal;

    // حساب مبالغ العمولة
    final double rawAppCommission = baseForCommission * appRate;
    final double rawAgencyCommission = hasAgency ? baseForCommission * normalizedAgencyRate : 0.0;

    // المبلغ الصافي للسائق قبل التقريب
    final double rawDriverNet = safeTotal - rawAppCommission - rawAgencyCommission;

    // تقريب القيم إلى منزلتين عشريتين
    final double appCommissionAmount = _round2(rawAppCommission);
    final double agencyCommissionAmount = _round2(rawAgencyCommission);
    final double driverNetAmount = _round2(rawDriverNet);

    // ما تستلمه المنصة (قد تساوي appCommissionAmount؛ إذا أردت إضافة رسوم بوابة دفع هنا يمكن إضافتها)
    final double platformReceives = appCommissionAmount;

    // حساب الفرق الناتج عن التقريب (لأغراض التدقيق)
    final double roundingDelta = _round2((safeTotal) - (appCommissionAmount + agencyCommissionAmount + driverNetAmount));

    return CommissionResult(
      totalAmount: _round2(safeTotal),
      govFee: _round2(safeGovFee),
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

  /// حساب تقسيم لمبلغ مقسوم على عدد مقاعد (مثلاً حجز عدة مقاعد)
  ///
  /// يعيد CommissionResult مجمّع للمبلغ الكلي.
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

  /// دالة مساعدة لإنتاج خريطة جاهزة للحفظ في مستند الدفع (payments collection)
  /// تحوي الحقول الأساسية: appCommissionRate, appCommissionAmount, agencyCommissionRate, agencyCommissionAmount, driverNetAmount
  static Map<String, dynamic> buildPaymentSplitMap(CommissionResult result) {
    return {
      'totalAmount': result.totalAmount,
      'govFee': result.govFee,
      'agencyId': result.agencyId,
      'appCommissionRate': result.appCommissionRate,
      'appCommissionAmount': result.appCommissionAmount,
      'agencyCommissionRate': result.agencyCommissionRate,
      'agencyCommissionAmount': result.agencyCommissionAmount,
      'driverNetAmount': result.driverNetAmount,
      'platformReceives': result.platformReceives,
      'roundingDelta': result.roundingDelta,
      'calculatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
