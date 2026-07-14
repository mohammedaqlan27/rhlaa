// test/commission_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rhlaa/services/commission_service.dart'; // عدّل المسار حسب مشروعك

void main() {
  group('CommissionService.calculateSplit', () {
    test('driver free scenario (no agency)', () {
      final res = CommissionService.calculateSplit(
        totalAmount: 100.0,
        govFee: 0.0,
        agencyId: null,
        appRateIfDriverFree: 0.04,
        appRateIfAgencyDriver: 0.08,
        agencyRate: null,
        deductGovFeeBeforeCommission: false,
      );

      expect(res.totalAmount, 100.0);
      expect(res.appCommissionAmount, 4.0);
      expect(res.agencyCommissionAmount, 0.0);
      expect(res.driverNetAmount, 96.0);
      expect(res.roundingDelta, closeTo(0.0, 0.01));
    });

    test('agency scenario with agencyRate and govFee deducted before commission', () {
      final res = CommissionService.calculateSplit(
        totalAmount: 200.0,
        govFee: 10.0,
        agencyId: 'agency_1',
        appRateIfDriverFree: 0.04,
        appRateIfAgencyDriver: 0.08,
        agencyRate: 0.1,
        deductGovFeeBeforeCommission: true,
      );

      // baseForCommission = 200 - 10 = 190
      final expectedApp = double.parse((190 * 0.08).toStringAsFixed(2));
      final expectedAgency = double.parse((190 * 0.1).toStringAsFixed(2));
      final expectedDriver = double.parse((200 - expectedApp - expectedAgency).toStringAsFixed(2));

      expect(res.appCommissionAmount, expectedApp);
      expect(res.agencyCommissionAmount, expectedAgency);
      expect(res.driverNetAmount, expectedDriver);
    });
  });
}
