// test/booking_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:rhlaa/models/booking_model.dart'; // عدّل المسار حسب مشروعك

void main() {
  group('Booking.fromDocument', () {
    test('parses fields from Firestore document (camelCase)', () async {
      final instance = MockFirestoreInstance();

      final data = {
        'tripId': 'trip_123',
        'passengerId': 'user_abc',
        'passengerNickname': 'Mohammed',
        'driverId': 'driver_xyz',
        'bookedSeatsCount': 2,
        'totalPrice': 150.0,
        'isFamilyBooking': true,
        'childrenCount': 1,
        'bookingStatus': 'pending',
        'paymentStatus': 'unpaid',
        'notes': 'Test note',
        'seatIndexes': [0, 1],
        'reservedUntil': Timestamp.fromDate(DateTime.now().add(Duration(minutes: 15))),
        'paymentIntentId': null,
        'canceledAt': null,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      await instance.collection('bookings').doc('b1').set(data);
      final doc = await instance.collection('bookings').doc('b1').get();

      final booking = Booking.fromDocument(doc);

      expect(booking.id, 'b1');
      expect(booking.tripId, 'trip_123');
      expect(booking.passengerId, 'user_abc');
      expect(booking.passengerNickname, 'Mohammed');
      expect(booking.driverId, 'driver_xyz');
      expect(booking.bookedSeatsCount, 2);
      expect(booking.totalPrice, 150.0);
      expect(booking.isFamilyBooking, true);
      expect(booking.childrenCount, 1);
      expect(booking.bookingStatus, 'pending');
      expect(booking.paymentStatus, 'unpaid');
      expect(booking.notes, 'Test note');
      expect(booking.seatIndexes, isNotNull);
      expect(booking.reservedUntil, isNotNull);
      expect(booking.createdAt, isNotNull);
    });

    test('parses snake_case and fallback keys', () async {
      final instance = MockFirestoreInstance();

      final data = {
        'trip_id': 'trip_456',
        'passenger_id': 'user_def',
        'passenger_nickname': 'Ali',
        'driver_id': 'driver_abc',
        'seats_count': '3',
        'total_price': '200.5',
        'is_family_booking': 'true',
        'children_count': 0,
        'status': 'confirmed',
        'payment_status': 'paid',
        'seat_indexes': [2, 3, 4],
        'created_at': Timestamp.now(),
      };

      await instance.collection('bookings').doc('b2').set(data);
      final doc = await instance.collection('bookings').doc('b2').get();

      final booking = Booking.fromDocument(doc);

      expect(booking.id, 'b2');
      expect(booking.tripId, 'trip_456');
      expect(booking.passengerId, 'user_def');
      expect(booking.passengerNickname, 'Ali');
      expect(booking.driverId, 'driver_abc');
      expect(booking.bookedSeatsCount, 3);
      expect(booking.totalPrice, closeTo(200.5, 0.001));
      expect(booking.isFamilyBooking, true);
      expect(booking.bookingStatus, 'confirmed');
      expect(booking.paymentStatus, 'paid');
      expect(booking.seatIndexes, isNotNull);
    });
  });
}
