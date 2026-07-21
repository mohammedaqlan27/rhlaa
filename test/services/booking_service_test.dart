import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rhlaa/models/booking_model.dart';
import 'package:rhlaa/models/trip.dart';
import 'package:rhlaa/services/booking_service.dart';
import 'package:rhlaa/services/notification_service.dart';

@GenerateMocks([NotificationService])
import 'booking_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late MockNotificationService mockNotificationService;
  late BookingService bookingService;

  const String tPassengerId = 'passenger_123';
  const String tTripId = 'trip_456';
  const String tDriverId = 'driver_789';

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    mockNotificationService = MockNotificationService();

    bookingService = BookingService(
      firestore: fakeFirestore,
      notificationService: mockNotificationService,
    );

    // إعداد رحلة بـ 5 مقاعد
    await fakeFirestore.collection('trips').doc(tTripId).set({
      'id': tTripId,
      'driverId': tDriverId,
      'availableSeats': 5,
      'seatStatus': [true, true, true, true, true],
      'pricePerSeat': 100.0,
    });

    await fakeFirestore.collection('users').doc(tPassengerId).set({
      'id': tPassengerId,
      'nickname': 'Ahmed',
    });
  });

  // ---------------------------------------------------------
  // المجموعة الأولى: حالات النجاح (تم ذكرها سابقاً)
  // ---------------------------------------------------------
  group('BookingService - Success Paths', () {
    test('إنشاء حجز وتأكيده بنجاح', () async {
      final bId = await bookingService.createBookingPending(
        tripId: tTripId, passengerId: tPassengerId, seatsToBook: 1, tripPricePerSeat: 100.0,
      );
      final error = await bookingService.confirmBookingAfterPayment(
        bookingId: bId!, paymentIntentId: 'pay_ok', payerId: tPassengerId,
      );
      expect(error, isNull);
    });
  });

  // ---------------------------------------------------------
  // المجموعة الثانية: حالات الفشل (Edge Cases) - الاختبارات الخارقة
  // ---------------------------------------------------------
  group('BookingService - Edge Cases (حالات الفشل)', () {

    test('فشل تأكيد حجز منتهي الصلاحية: يجب إلغاء الحجز وتحرير المقاعد', () async {
      // 1. إنشاء حجز يدوي منتهي الصلاحية (قبل 30 دقيقة)
      final expiredTime = DateTime.now().subtract(const Duration(minutes: 30));
      final bId = 'expired_booking_123';

      await fakeFirestore.collection('bookings').doc(bId).set({
        'tripId': tTripId,
        'passengerId': tPassengerId,
        'bookingStatus': 'pending',
        'reservedUntil': Timestamp.fromDate(expiredTime),
        'seatIndexes': [0, 1],
        'bookedSeatsCount': 2,
      });

      // تحديث الرحلة لتعكس أن المقاعد محجوزة حالياً
      await fakeFirestore.collection('trips').doc(tTripId).update({
        'availableSeats': 3,
        'seatStatus': [false, false, true, true, true],
      });

      // 2. محاولة تأكيد الحجز المنتهي
      final result = await bookingService.confirmBookingAfterPayment(
        bookingId: bId,
        paymentIntentId: 'pay_late',
        payerId: tPassengerId,
      );

      // 3. التحقق من النتيجة
      expect(result, contains('انتهت مهلة الحجز'));

      // 4. التحقق من أن الحجز تحول لـ cancelled في Firestore
      final bDoc = await fakeFirestore.collection('bookings').doc(bId).get();
      expect(bDoc.data()?['bookingStatus'], 'cancelled');

      // 5. التحقق من عودة المقاعد للرحلة
      final tripDoc = await fakeFirestore.collection('trips').doc(tTripId).get();
      expect(tripDoc.data()?['availableSeats'], 5);
      expect(tripDoc.data()?['seatStatus'][0], true);
    });

    test('فشل التأكيد إذا كان المستخدم (payerId) ليس هو صاحب الحجز', () async {
      final bId = await bookingService.createBookingPending(
        tripId: tTripId,
        passengerId: tPassengerId,
        seatsToBook: 1,
        tripPricePerSeat: 100.0,
      );

      final result = await bookingService.confirmBookingAfterPayment(
        bookingId: bId!,
        paymentIntentId: 'pay_123',
        payerId: 'wrong_user_id', // مستخدم مختلف
      );

      expect(result, contains('غير مصرح لك'));
    });

    test('فشل إنشاء حجز لرحلة غير موجودة', () async {
      final result = await bookingService.createBookingPending(
        tripId: 'non_existent_trip',
        passengerId: tPassengerId,
        seatsToBook: 1,
        tripPricePerSeat: 100.0,
      );

      expect(result, contains('الرحلة غير موجودة'));
    });

    test('فشل إنشاء حجز بعدد مقاعد صفر أو سالب', () async {
      final result = await bookingService.createBookingPending(
        tripId: tTripId,
        passengerId: tPassengerId,
        seatsToBook: 0,
        tripPricePerSeat: 100.0,
      );

      expect(result, contains('غير صالح'));
    });

    test('فشل إلغاء حجز من قبل شخص آخر', () async {
      final bId = await bookingService.createBookingPending(
        tripId: tTripId,
        passengerId: tPassengerId,
        seatsToBook: 1,
        tripPricePerSeat: 100.0,
      );

      final result = await bookingService.cancelBooking(
        bookingId: bId!,
        passengerId: 'hacker_id',
      );

      expect(result, contains('غير مصرح لك'));
    });
  });
}