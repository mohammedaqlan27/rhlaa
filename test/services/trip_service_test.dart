import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// استيراد الملفات الخاصة بمشروعك (تأكد من صحة المسارات)
import 'package:rhlaa/models/trip.dart';
import 'package:rhlaa/models/app_user.dart';
import 'package:rhlaa/services/trip_service.dart';
import 'package:rhlaa/services/govfees_service.dart';
import 'package:rhlaa/services/notification_service.dart';

// إنشاء نسخ وهمية (Mocks) للخدمات الخارجية
@GenerateMocks([GovFeesService, NotificationService])
import 'trip_service_test.mocks.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockGovFeesService mockGovFeesService;
  late MockNotificationService mockNotificationService;
  late TripService tripService;

  const String tDriverId = 'driver_001';
  const String tTripId = 'trip_123';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockGovFeesService = MockGovFeesService();
    mockNotificationService = MockNotificationService();

    tripService = TripService(
      firestore: fakeFirestore,
      govFeesService: mockGovFeesService,
      notificationService: mockNotificationService,
    );
  });

  // دالة مساعدة لإنشاء كائن رحلة تجريبي
  Trip createSampleTrip({String? id, String? driverId, String? status}) {
    return Trip(
      id: id ?? '',
      title: 'رحلة إلى صنعاء',
      driverId: driverId ?? tDriverId,
      origin: 'تعز',
      destination: 'صنعاء',
      totalSeats: 4,
      price: 5000.0,
      status: status ?? 'active',
      departureTime: DateTime.now().add(const Duration(hours: 2)),
    );
  }

  group('Trip Model Tests', () {
    test('يجب تحويل الموديل إلى Map بشكل صحيح (toMap)', () {
      final trip = createSampleTrip(id: 'T1');
      final map = trip.toMap();

      expect(map['origin'], 'تعز');
      expect(map['totalSeats'], 4);
      expect(map['seatStatus'], isA<List<bool>>());
      expect(map['seatStatus'].length, 4);
    });

    test('يجب إنشاء الموديل من DocumentSnapshot بشكل صحيح (fromDocument)', () async {
      final now = Timestamp.now();
      await fakeFirestore.collection('trips').doc(tTripId).set({
        'title': 'رحلة اختبار',
        'totalSeats': 2,
        'availableSeats': 1,
        'price': 3000.0,
        'createdAt': now,
      });

      final doc = await fakeFirestore.collection('trips').doc(tTripId).get();
      final trip = Trip.fromDocument(doc);

      expect(trip.id, tTripId);
      expect(trip.totalSeats, 2);
      expect(trip.price, 3000.0);
      expect(trip.createdAt, now);
    });
  });

  group('TripService - Driver Verification', () {
    test('isDriverVerified: يجب أن يعيد true للسائق الموثق', () async {
      await fakeFirestore.collection('users').doc(tDriverId).set({
        'uid': tDriverId,
        'isDriver': true,
        'isIdVerified': true,
        'role': 'driver',
      });

      final result = await tripService.isDriverVerified(tDriverId);
      expect(result, isTrue);
    });

    test('isDriverVerified: يجب أن يعيد false إذا كان المستخدم ليس سائقاً', () async {
      await fakeFirestore.collection('users').doc('user_1').set({
        'isDriver': false,
        'isIdVerified': true,
      });

      final result = await tripService.isDriverVerified('user_1');
      expect(result, isFalse);
    });
  });

  group('TripService - CRUD Operations', () {
    test('createTrip: يجب إنشاء رحلة وحساب رسوم الفرزة تلقائياً', () async {
      // 1. إعداد سائق موثق
      await fakeFirestore.collection('users').doc(tDriverId).set({
        'isDriver': true,
        'isIdVerified': true,
        'nickname': 'الكابتن علي',
      });

      // 2. إعداد الـ Mock لرسوم الفرزة
      when(mockGovFeesService.computeAndSetGovFeeForTrip(any))
          .thenAnswer((_) async => true);

      final trip = createSampleTrip();
      final tripId = await tripService.createTrip(trip);

      // التحقق
      expect(tripId, isNotNull);
      final doc = await fakeFirestore.collection('trips').doc(tripId).get();
      expect(doc.exists, true);
      expect(doc.data()?['driverName'], 'الكابتن علي');
      expect(doc.data()?['availableSeats'], 4);

      // التأكد من استدعاء خدمة الرسوم
      verify(mockGovFeesService.computeAndSetGovFeeForTrip(tripId)).called(1);
    });

    test('updateTrip: يجب إعادة حساب الرسوم إذا تغير خط السير', () async {
      final trip = createSampleTrip(id: tTripId);
      await fakeFirestore.collection('trips').doc(tTripId).set(trip.toMap());

      when(mockGovFeesService.computeAndSetGovFeeForTrip(tTripId))
          .thenAnswer((_) async => true);

      // تحديث الوجهة
      final updatedTrip = trip.copyWith(destination: 'عدن');
      final success = await tripService.updateTrip(tTripId, updatedTrip);

      expect(success, true);
      // يجب استدعاء حساب الرسوم لأن الوجهة تغيرت
      verify(mockGovFeesService.computeAndSetGovFeeForTrip(tTripId)).called(1);
    });

    test('deleteTrip: يجب حذف الرحلة بنجاح', () async {
      await fakeFirestore.collection('trips').doc(tTripId).set({'title': 'test'});

      final success = await tripService.deleteTrip(tTripId);

      expect(success, true);
      final doc = await fakeFirestore.collection('trips').doc(tTripId).get();
      expect(doc.exists, false);
    });
  });

  group('TripService - Queries & Helpers', () {
    test('getAvailableTrips: يجب جلب الرحلات النشطة التي بها مقاعد فقط', () async {
      // رحلة متاحة
      await fakeFirestore.collection('trips').add({
        'status': 'active',
        'availableSeats': 2,
        'departureTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
      });
      // رحلة مكتملة (لا يجب جلبها)
      await fakeFirestore.collection('trips').add({
        'status': 'completed',
        'availableSeats': 2,
      });
      // رحلة لا يوجد بها مقاعد (لا يجب جلبها)
      await fakeFirestore.collection('trips').add({
        'status': 'active',
        'availableSeats': 0,
      });

      final list = await tripService.getAvailableTrips();
      expect(list.length, 1);
    });

    test('updateSeatStatus: يجب تحديث حالة المقاعد', () async {
      await fakeFirestore.collection('trips').doc(tTripId).set({
        'availableSeats': 4,
        'seatStatus': [true, true, true, true],
      });

      final newStatus = [false, true, true, true];
      final success = await tripService.updateSeatStatus(tTripId, newStatus, 3);

      expect(success, true);
      final doc = await fakeFirestore.collection('trips').doc(tTripId).get();
      expect(doc.data()?['availableSeats'], 3);
      expect(doc.data()?['seatStatus'][0], false);
    });

    test('notifyUserAboutTrip: يجب استدعاء خدمة الإشعارات', () async {
      await tripService.notifyUserAboutTrip('user_1', 'تنبيه', 'تم إلغاء الرحلة', 'cancel');

      verify(mockNotificationService.sendNotification(
        userId: 'user_1',
        title: 'تنبيه',
        body: 'تم إلغاء الرحلة',
        type: 'cancel',
      )).called(1);
    });
  });
}