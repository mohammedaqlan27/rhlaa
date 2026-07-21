import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/annotations.dart';
import 'package:rhlaa/models/agency.dart';
import 'package:rhlaa/models/agency_transaction.dart';
import 'package:rhlaa/services/agencies_service.dart';

// توليد النسخة الوهمية (Mock) لخدمة المكاتب لاستخدامها في اختبارات أخرى
@GenerateMocks([AgenciesService])
import 'agencies_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late AgenciesService agenciesService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    // نستخدم النسخة الحقيقية من الخدمة مع قاعدة بيانات وهمية لاختبار المنطق الداخلي
    agenciesService = AgenciesService(firestore: fakeFirestore);
  });

  group('AgenciesService - CRUD & Validation (الإدارة والتحقق)', () {
    test('createAgency: يجب إنشاء مكتب جديد ومنع تكرار رقم الهاتف', () async {
      const mobile = '777111222';

      final id = await agenciesService.createAgency(
        agencyName: 'مكتب النور',
        managerName: 'أحمد علي',
        location: const GeoPoint(15.3694, 44.1910),
        mobileNumber: mobile,
        initialBalance: 500.0,
      );

      expect(id, isNotEmpty);

      // محاولة إنشاء مكتب آخر بنفس الرقم (يجب أن يفشل)
      expect(
            () => agenciesService.createAgency(
          agencyName: 'مكتب آخر',
          managerName: 'صالح',
          location: 'صنعاء',
          mobileNumber: mobile,
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('مسجل لمكتب آخر'))),
      );
    });

    test('searchAgencies: يجب أن يجد المكتب بالاسم (بحث جزئي) وبالهاتف', () async {
      await agenciesService.createAgency(
        agencyName: 'مكتب الثقة العالمي',
        managerName: 'صالح محمد',
        location: 'صنعاء',
        mobileNumber: '770000000',
      );

      // 1. البحث بالهاتف
      final phoneResults = await agenciesService.searchAgencies('770000000');
      expect(phoneResults.length, 1);
      expect(phoneResults.first.agencyName, 'مكتب الثقة العالمي');

      // 2. البحث بالاسم (جزئي)
      final nameResults = await agenciesService.searchAgencies('الثقة');
      expect(nameResults.isNotEmpty, true);
      expect(nameResults.first.agencyName, contains('الثقة'));
    });

    test('getAgencyStream: يجب أن يعكس تحديثات الرصيد لحظياً', () async {
      final id = await agenciesService.createAgency(
        agencyName: 'مكتب البث',
        managerName: 'مدير',
        location: null,
        mobileNumber: '111',
        initialBalance: 100.0,
      );

      final stream = agenciesService.getAgencyStream(id);
      await agenciesService.creditWallet(id, 50.0);

      final updatedAgency = await stream.first;
      expect(updatedAgency!.walletBalance, 150.0);
    });
  });

  group('AgenciesService - Wallet & Audit (المحفظة والتدقيق المالي)', () {
    test('creditWallet: يجب تسجيل الرصيد القديم والجديد للتدقيق', () async {
      final id = await agenciesService.createAgency(
        agencyName: 'مكتب المحفظة',
        managerName: 'مدير',
        location: null,
        mobileNumber: '123',
        initialBalance: 100.0,
      );

      await agenciesService.creditWallet(id, 50.0, reason: 'شحن رصيد', performedBy: 'admin_1');

      final transactions = await agenciesService.fetchTransactions(id);
      final tx = transactions.first;

      expect(tx.amount, 50.0);

      // التحقق من بيانات التدقيق في Firestore مباشرة
      final txDoc = await fakeFirestore.collection('agency_transactions').doc(tx.id).get();
      expect(txDoc.data()?['oldBalance'], 100.0);
      expect(txDoc.data()?['newBalance'], 150.0);
      expect(txDoc.data()?['performedBy'], 'admin_1');
    });

    test('debitWallet: يجب أن يرمي استثناء عند نقص الرصيد', () async {
      final id = await agenciesService.createAgency(
        agencyName: 'مكتب رصيد منخفض',
        managerName: 'مدير',
        location: null,
        mobileNumber: '444',
        initialBalance: 10.0,
      );

      expect(
            () => agenciesService.debitWallet(id, 50.0),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('غير كاف'))),
      );
    });
  });

  group('AgenciesService - Global Reports (التقارير العامة)', () {
    test('getTotalAgenciesBalance: يجب حساب إجمالي السيولة في كل المكاتب', () async {
      await agenciesService.createAgency(
          agencyName: 'مكتب A', managerName: 'M', location: null, mobileNumber: 'A1', initialBalance: 200.0);
      await agenciesService.createAgency(
          agencyName: 'مكتب B', managerName: 'M', location: null, mobileNumber: 'B2', initialBalance: 300.0);

      final total = await agenciesService.getTotalAgenciesBalance();
      expect(total, 500.0);
    });
  });

  group('Models - Data Integrity', () {
    test('Agency.fromDoc: يجب أن يتعامل مع القيم المفقودة بأمان', () {
      final agency = Agency.fromMap('test_id', {
        'agencyName': null,
        'walletBalance': '150.5',
      });

      expect(agency.agencyName, '');
      expect(agency.walletBalance, 150.5);
    });
  });
}