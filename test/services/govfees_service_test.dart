import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rhlaa/models/gov_fee_rule.dart' hide GovFeeRule, DistanceTier;
import 'package:rhlaa/services/govfees_service.dart';
import 'package:rhlaa/models/trip.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late GovFeesService govFeesService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    govFeesService = GovFeesService(firestore: fakeFirestore);
  });

  group('GovFeeRule Model - Matching Logic (المطابقة الذكية)', () {
    test('يجب أن يطابق الوايلدكارد (*) أي مدينة', () {
      final rule = GovFeeRule(
        id: 'r1',
        origin: '*',
        destination: '*',
        exact: false,
        distanceBased: false,
        fixedAmount: 500,
        distanceTiers: [],
        priority: 1,
        isActive: true,
        createdAt: Timestamp.now(),
      );

      expect(rule.matches('Sanaa', 'Aden'), true);
      expect(rule.matches('Taiz', 'Ibb'), true);
    });

    test('المطابقة الحرفية (Exact = true) وحساسية الأحرف', () {
      final rule = GovFeeRule(
        id: 'r2',
        origin: 'Sanaa',
        destination: 'Aden',
        exact: true,
        distanceBased: false,
        fixedAmount: 500,
        distanceTiers: [],
        priority: 1,
        isActive: true,
        createdAt: Timestamp.now(),
      );

      expect(rule.matches('sanaa', 'ADEN'), true); // يجب أن يطابق رغم اختلاف حالة الأحرف
      expect(rule.matches('Sanaa City', 'Aden'), false); // دقيق جداً، لا يقبل زيادة
    });

    test('المطابقة الجزئية (Exact = false)', () {
      final rule = GovFeeRule(
        id: 'r3',
        origin: 'Sanaa',
        destination: 'Aden',
        exact: false,
        distanceBased: false,
        fixedAmount: 500,
        distanceTiers: [],
        priority: 1,
        isActive: true,
        createdAt: Timestamp.now(),
      );

      expect(rule.matches('Amanat Al-Sanaa', 'Aden Port'), true); // يحتوي على الكلمات المطلوبة
    });
  });

  group('GovFeeRule Model - Calculation Logic (حساب الرسوم)', () {
    test('يجب حساب الرسوم بناءً على شرائح المسافة بدون فجوات', () {
      final rule = GovFeeRule(
        id: 'r4',
        origin: '*',
        destination: '*',
        exact: false,
        distanceBased: true,
        fixedAmount: 100, // افتراضي إذا فشلت الشرائح
        distanceTiers: [
          DistanceTier(minKm: 0, maxKm: 50, amount: 200),
          DistanceTier(minKm: 50.1, maxKm: 200, amount: 500),
        ],
        priority: 1,
        isActive: true,
        createdAt: Timestamp.now(),
      );

      expect(rule.calculate(30), 200.0);
      expect(rule.calculate(50), 200.0);
      expect(rule.calculate(50.5), 500.0);
      expect(rule.calculate(300), 100.0); // خارج النطاق يعود للـ fixed
    });
  });

  group('GovFeesService - Integration Tests', () {
    test('calculateGovFee: يجب اختيار القاعدة ذات الأولوية الأعلى أولاً', () async {
      // قاعدة عامة أولوية 1
      await govFeesService.createRule(GovFeeRule(
        id: '', origin: '*', destination: '*', exact: false, distanceBased: false,
        fixedAmount: 100, priority: 1, isActive: true, createdAt: Timestamp.now(), distanceTiers: [],
      ));

      // قاعدة محددة أولوية 10
      await govFeesService.createRule(GovFeeRule(
        id: '', origin: 'Sanaa', destination: 'Aden', exact: true, distanceBased: false,
        fixedAmount: 1500, priority: 10, isActive: true, createdAt: Timestamp.now(), distanceTiers: [],
      ));

      final fee = await govFeesService.calculateGovFee(origin: 'Sanaa', destination: 'Aden');
      expect(fee, 1500.0); // اختار الأولوية الأعلى
    });

    test('computeAndSetGovFeeForTrip: تحديث مستند الرحلة بنجاح', () async {
      // 1. إضافة قاعدة
      await govFeesService.createRule(GovFeeRule(
        id: 'rule_1', origin: 'Sanaa', destination: 'Aden', exact: false, distanceBased: false,
        fixedAmount: 850, priority: 1, isActive: true, createdAt: Timestamp.now(), distanceTiers: [],
      ));

      // 2. إضافة رحلة
      final tripId = 'trip_123';
      await fakeFirestore.collection('trips').doc(tripId).set({
        'id': tripId,
        'origin': 'Sanaa',
        'destination': 'Aden',
        'distanceKm': 380.0,
        'govFeeAmount': 0.0,
        'status': 'active',
      });

      // 3. تنفيذ العملية
      final result = await govFeesService.computeAndSetGovFeeForTrip(tripId);

      // 4. التحقق
      expect(result, true);
      final tripDoc = await fakeFirestore.collection('trips').doc(tripId).get();
      expect(tripDoc.data()?['govFeeAmount'], 850.0);
    });

    test('recomputeGovFeesForAllActiveTrips: تحديث جماعي للرحلات', () async {
      // قاعدة جديدة
      await govFeesService.createRule(GovFeeRule(
        id: 'r_new', origin: '*', destination: '*', exact: false, distanceBased: false,
        fixedAmount: 400, priority: 1, isActive: true, createdAt: Timestamp.now(), distanceTiers: [],
      ));

      // رحلتين برسوم قديمة (0)
      await fakeFirestore.collection('trips').add({'status': 'active', 'govFeeAmount': 0.0, 'origin': 'A', 'destination': 'B'});
      await fakeFirestore.collection('trips').add({'status': 'active', 'govFeeAmount': 0.0, 'origin': 'C', 'destination': 'D'});

      final count = await govFeesService.recomputeGovFeesForAllActiveTrips();

      expect(count, 2);
      final snap = await fakeFirestore.collection('trips').get();
      for (var doc in snap.docs) {
        expect(doc.data()['govFeeAmount'], 400.0);
      }
    });
  });
}