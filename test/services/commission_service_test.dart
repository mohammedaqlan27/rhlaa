import 'package:flutter_test/flutter_test.dart';
import 'package:rhlaa/services/commission_service.dart'; // تأكد من صحة المسار

void main() {
  group('CommissionService - calculateSplit (Single Trip)', () {

    test('حساب عمولة السائق الحر (بدون مكتب) - النسبة الافتراضية 4%', () {
      final result = CommissionService.calculateSplit(
        totalAmount: 100.0,
        agencyId: null,
      );

      expect(result.appCommissionRate, 0.04);
      expect(result.appCommissionAmount, 4.0);
      expect(result.agencyCommissionAmount, 0.0);
      expect(result.driverNetAmount, 96.0);
      expect(result.roundingDelta, 0.0);
    });

    test('حساب عمولة سائق تابع لمكتب - النسبة الافتراضية 8% للتطبيق و 8% للمكتب', () {
      final result = CommissionService.calculateSplit(
        totalAmount: 100.0,
        agencyId: 'agency_123',
        agencyRate: 0.08,
      );

      // التطبيق يأخذ 8% لأن السائق تابع لمكتب (حسب المنطق في الكود)
      expect(result.appCommissionAmount, 8.0);
      expect(result.agencyCommissionAmount, 8.0);
      expect(result.driverNetAmount, 84.0);
    });

    test('اختبار خصم رسوم الحكومة (govFee) قبل حساب العمولة', () {
      final result = CommissionService.calculateSplit(
        totalAmount: 100.0,
        govFee: 20.0,
        deductGovFeeBeforeCommission: true,
        appRateIfDriverFree: 0.10, // 10% لسهولة الحساب
      );

      // الحساب: (100 - 20) * 0.10 = 8.0
      expect(result.appCommissionAmount, 8.0);
      expect(result.driverNetAmount, 92.0); // 100 - 8 - 20 (إذا اعتبرنا الـ govFee تخصم من الصافي أيضاً)
      // ملاحظة: الكود الحالي يخصم العمولات فقط من الإجمالي، الـ govFee تظهر كمرجع
    });

    test('اختبار التقريب المالي لمنزلتين عشريتين', () {
      // 33.33 * 0.04 = 1.3332 -> يجب أن تقرب إلى 1.33
      final result = CommissionService.calculateSplit(
        totalAmount: 33.33,
        appRateIfDriverFree: 0.04,
      );

      expect(result.appCommissionAmount, 1.33);
      expect(result.driverNetAmount, 32.0); // 33.33 - 1.33
    });
  });

  group('CommissionService - calculateSplitForSeats (Multiple Seats)', () {

    test('حساب العمولة لعدة مقاعد', () {
      final result = CommissionService.calculateSplitForSeats(
        pricePerSeat: 50.0,
        seatsCount: 3,
        appRateIfDriverFree: 0.10,
      );

      // الإجمالي: 50 * 3 = 150
      // العمولة: 150 * 0.10 = 15
      expect(result.totalAmount, 150.0);
      expect(result.appCommissionAmount, 15.0);
      expect(result.driverNetAmount, 135.0);
    });

    test('التعامل مع عدد مقاعد صفر أو سالب', () {
      final result = CommissionService.calculateSplitForSeats(
        pricePerSeat: 50.0,
        seatsCount: -1,
      );

      expect(result.totalAmount, 0.0);
      expect(result.driverNetAmount, 0.0);
    });
  });

  group('CommissionService - Edge Cases & Normalization', () {

    test('التعامل مع مبالغ سالبة أو غير منطقية', () {
      final result = CommissionService.calculateSplit(totalAmount: -100.0);
      expect(result.totalAmount, 0.0);
    });

    test('تطبيع النسب (Normalization) - نسبة أكبر من 1', () {
      final result = CommissionService.calculateSplit(
        totalAmount: 100.0,
        appRateIfDriverFree: 1.5, // نسبة خاطئة
      );
      // يجب أن تعود للـ fallback (0.04)
      expect(result.appCommissionRate, 0.04);
    });

    test('تطبيع النسب (Normalization) - نسبة سالبة', () {
      final result = CommissionService.calculateSplit(
        totalAmount: 100.0,
        appRateIfDriverFree: -0.5,
      );
      expect(result.appCommissionRate, 0.0);
    });
  });

  group('CommissionService - Helper Methods', () {

    test('buildPaymentSplitMap: التأكد من تحويل النتيجة لخريطة بشكل صحيح', () {
      final result = CommissionService.calculateSplit(totalAmount: 100.0);
      final map = CommissionService.buildPaymentSplitMap(result);

      expect(map, isA<Map<String, dynamic>>());
      expect(map['totalAmount'], 100.0);
      expect(map.containsKey('calculatedAt'), true);
      expect(map['appCommissionAmount'], 4.0);
    });
  });
}