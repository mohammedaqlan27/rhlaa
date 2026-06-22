import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../models/trip.dart';
import '../models/app_user.dart';
import 'notification_service.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final String _tripsCollection = 'trips';
  final String _bookingsCollection = 'bookings';
  final String _usersCollection = 'users';

  BookingService();

  Future<String?> createBooking({
    required String tripId,
    required String passengerId,
    required int seatsToBook,
    required double tripPricePerSeat,
    required bool isFamilyBooking,
    required int childrenCount,
    int? seatNumber,
    String? paymentMethod,
  }) async {
    if (seatsToBook <= 0) return 'عدد المقاعد غير صالح.';
    if (tripPricePerSeat < 0) return 'سعر المقعد غير صالح.';

    String? errorMessage;
    String? bookingIdForNotification;
    String? destinationForNotification;
    int seatsForNotification = 0;

    try {
      // 1. التحقق من الراكب خارج المعاملة
      final passengerDoc = await _firestore.collection(_usersCollection).doc(passengerId).get();
      if (!passengerDoc.exists) return 'بيانات الراكب غير موجودة.';
      final appUser = AppUser.fromDocument(passengerDoc);

      // 2. التحقق من وجود حجز مسبق (يجب أن يكون خارج المعاملة لأن الـ Query ممنوع داخلها)
      final existingQuery = await _firestore
          .collection(_bookingsCollection)
          .where('tripId', isEqualTo: tripId)
          .where('passengerId', isEqualTo: passengerId)
          .where('bookingStatus', whereIn: ['مؤكد', 'confirmed'])
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        return 'لديك حجز مؤكد مسبقاً لهذه الرحلة.';
      }

      // 3. بدء المعاملة الآمنة لقراءة وتحديث المقاعد بشكل متزامن
      await _firestore.runTransaction((transaction) async {
        final tripRef = _firestore.collection(_tripsCollection).doc(tripId);
        final tripSnapshot = await transaction.get(tripRef);

        if (!tripSnapshot.exists) {
          errorMessage = 'الرحلة غير موجودة.';
          return;
        }

        final trip = Trip.fromDocument(tripSnapshot);
        final int availableSeats = trip.availableSeats;

        if (availableSeats < seatsToBook) {
          errorMessage = 'لا توجد مقاعد كافية. المتاح: $availableSeats';
          return;
        }

        List<bool> seatStatusList = List<bool>.from(trip.seatStatus);
        if (seatStatusList.isEmpty) {
          final int total = trip.totalSeats > 0 ? trip.totalSeats : availableSeats;
          seatStatusList = List<bool>.filled(total, true);
        }

        final newSeatStatus = _reserveSeats(seatStatusList, seatsToBook);
        if (newSeatStatus == null) {
          errorMessage = 'فشل في ترتيب حجز المقاعد داخل الباص.';
          return;
        }

        final bookingId = _uuid.v4();
        final totalPrice = seatsToBook * tripPricePerSeat;

        final Map<String, dynamic> bookingPayload = {
          'id': bookingId,
          'tripId': tripId,
          'driverId': trip.driverId,
          'passengerId': passengerId,
          'bookedSeatsCount': seatsToBook,
          'totalPrice': totalPrice,
          'passengerNickname': appUser.nickname,
          'isFamilyBooking': isFamilyBooking,
          'childrenCount': childrenCount,
          'bookingStatus': 'confirmed',
          'paymentStatus': 'unpaid',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (seatNumber != null) bookingPayload['seatNumber'] = seatNumber;
        if (paymentMethod != null && paymentMethod.isNotEmpty) {
          bookingPayload['paymentMethod'] = paymentMethod;
        }

        // كتابة البيانات وتحديث الرحلة في نبضة واحدة داخل المعاملة
        transaction.set(_firestore.collection(_bookingsCollection).doc(bookingId), bookingPayload);
        transaction.update(tripRef, {
          'seatStatus': newSeatStatus,
          'availableSeats': FieldValue.increment(-seatsToBook),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        bookingIdForNotification = bookingId;
        destinationForNotification = trip.destination;
        seatsForNotification = seatsToBook;
      });

      // 4. إرسال الإشعار بعد نجاح المعاملة بالكامل
      if (errorMessage == null && bookingIdForNotification != null) {
        try {
          await NotificationService().sendNotification(
            userId: passengerId,
            title: 'تأكيد الحجز',
            body: '✅ تم تأكيد حجزك لـ $seatsForNotification مقاعد في الرحلة إلى ${destinationForNotification ?? ''}.',
            type: 'booking',
          );
        } catch (e) {
          debugPrint('BookingNotification error: $e');
        }
      }

      return errorMessage ?? bookingIdForNotification;
    } catch (e, st) {
      debugPrint('BookingService.createBooking error: $e\n$st');
      return 'فشلت عملية الحجز بسبب خطأ داخلي.';
    }
  }

  Future<String?> cancelBooking({
    required String bookingId,
    required String passengerId,
  }) async {
    String? errorMessage;
    String? destinationForNotification;

    try {
      await _firestore.runTransaction((transaction) async {
        final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);
        final bookingSnapshot = await transaction.get(bookingRef);
        if (!bookingSnapshot.exists) {
          errorMessage = 'الحجز غير موجود.';
          return;
        }

        final booking = Booking.fromDocument(bookingSnapshot);
        if (booking.passengerId != passengerId) {
          errorMessage = 'غير مصرح لك بإلغاء هذا الحجز.';
          return;
        }
        if (booking.bookingStatus == 'ملغى' || booking.bookingStatus == 'cancelled') {
          errorMessage = 'الحجز ملغى مسبقًا.';
          return;
        }

        final tripRef = _firestore.collection(_tripsCollection).doc(booking.tripId);
        final tripSnapshot = await transaction.get(tripRef);
        if (!tripSnapshot.exists) {
          errorMessage = 'الرحلة المرتبطة بالحجز غير موجودة.';
          return;
        }

        final trip = Trip.fromDocument(tripSnapshot);
        List<bool> seatStatusList = List<bool>.from(trip.seatStatus);
        final newSeatStatus = _releaseSeats(seatStatusList, booking.bookedSeatsCount);

        transaction.update(tripRef, {
          'seatStatus': newSeatStatus,
          'availableSeats': FieldValue.increment(booking.bookedSeatsCount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(bookingRef, {
          'bookingStatus': 'cancelled',
          'paymentStatus': booking.paymentStatus == 'paid' ? 'refund_pending' : 'unpaid',
          'canceledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        destinationForNotification = trip.destination;
      });

      if (errorMessage == null) {
        try {
          await NotificationService().sendNotification(
            userId: passengerId,
            title: 'إلغاء الحجز',
            body: '❌ تم إلغاء حجزك للرحلة إلى ${destinationForNotification ?? ''}.',
            type: 'cancel',
          );
        } catch (e) {
          debugPrint('CancelNotification error: $e');
        }
      }

      return errorMessage;
    } catch (e, st) {
      debugPrint('BookingService.cancelBooking error: $e\n$st');
      return 'فشلت عملية الإلغاء.';
    }
  }

  Future<List<Booking>> getBookingsForDriver(String driverId) async {
    try {
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('driverId', isEqualTo: driverId)
          .get();

      final list = snapshot.docs.map((doc) => Booking.fromDocument(doc)).toList();
      list.sort((a, b) {
        final DateTime aDate = (a.createdAt is DateTime)
            ? a.createdAt as DateTime
            : (a.createdAt is Timestamp ? (a.createdAt as Timestamp).toDate() : DateTime.now());

        final DateTime bDate = (b.createdAt is DateTime)
            ? b.createdAt as DateTime
            : (b.createdAt is Timestamp ? (b.createdAt as Timestamp).toDate() : DateTime.now());

        return bDate.compareTo(aDate);
      });
      return list;
    } catch (e, st) {
      debugPrint('BookingService.getBookingsForDriver error: $e\n$st');
      return [];
    }
  }


  Future<List<Booking>> getBookingsForPassenger(String passengerId) async {
    try {
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('passengerId', isEqualTo: passengerId)
          .get();

      final list = snapshot.docs.map((doc) => Booking.fromDocument(doc)).toList();
      list.sort((a, b) {
        final DateTime aDate = (a.createdAt is DateTime)
            ? a.createdAt as DateTime
            : (a.createdAt is Timestamp ? (a.createdAt as Timestamp).toDate() : DateTime.now());

        final DateTime bDate = (b.createdAt is DateTime)
            ? b.createdAt as DateTime
            : (b.createdAt is Timestamp ? (b.createdAt as Timestamp).toDate() : DateTime.now());

        return bDate.compareTo(aDate);
      });
      return list;
    } catch (e, st) {
      debugPrint('BookingService.getBookingsForPassenger error: $e\n$st');
      return [];
    }
  }

  List<bool>? _reserveSeats(List<bool> seatStatus, int count) {
    final updated = List<bool>.from(seatStatus);
    int reserved = 0;
    for (int i = 0; i < updated.length && reserved < count; i++) {
      if (updated[i]) {
        updated[i] = false;
        reserved++;
      }
    }
    if (reserved < count) return null; // لا توجد مقاعد شاغرة متتالية أو متبقية كافية
    return updated;
  }

  List<bool> _releaseSeats(List<bool> seatStatus, int count) {
    final updated = List<bool>.from(seatStatus);
    int released = 0;
    for (int i = 0; i < updated.length && released < count; i++) {
      if (!updated[i]) {
        updated[i] = true;
        released++;
      }
    }
    return updated;
  }
}