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

  /// إنشاء حجز جديد باستخدام Transaction لضمان سلامة المقاعد
  Future<String?> createBooking({
    required String tripId,
    required String passengerId,
    required int seatsToBook,
    required double tripPricePerSeat,
    required bool isFamilyBooking,
    required int childrenCount,
    int? seatNumber,
    String? paymentMethod,
    String? notes,
    String? paymentService,
    String? schemeHost,
  }) async {
    if (seatsToBook <= 0) return 'عدد المقاعد غير صالح.';

    String? errorMessage;
    String? bookingIdForNotification;
    String? destinationForNotification;

    try {
      // 1. جلب بيانات الراكب
      final passengerDoc = await _firestore.collection(_usersCollection).doc(passengerId).get();
      if (!passengerDoc.exists) return 'بيانات الراكب غير موجودة.';
      final appUser = AppUser.fromDocument(passengerDoc);

      // 2. التحقق من وجود حجز مسبق مؤكد لنفس الرحلة
      final existingQuery = await _firestore
          .collection(_bookingsCollection)
          .where('tripId', isEqualTo: tripId)
          .where('passengerId', isEqualTo: passengerId)
          .where('bookingStatus', isEqualTo: 'confirmed')
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        return 'لديك حجز مؤكد مسبقاً لهذه الرحلة.';
      }

      // 3. بدء المعاملة (Transaction)
      await _firestore.runTransaction((transaction) async {
        final tripRef = _firestore.collection(_tripsCollection).doc(tripId);
        final tripSnapshot = await transaction.get(tripRef);

        if (!tripSnapshot.exists) {
          errorMessage = 'الرحلة غير موجودة.';
          return;
        }

        final trip = Trip.fromDocument(tripSnapshot);

        // التحقق من توفر المقاعد
        if (trip.availableSeats < seatsToBook) {
          errorMessage = 'لا توجد مقاعد كافية. المتاح حالياً: ${trip.availableSeats}';
          return;
        }

        // تحديث مصفوفة المقاعد
        final newSeatStatus = _reserveSeats(trip.seatStatus, seatsToBook);
        if (newSeatStatus == null) {
          errorMessage = 'فشل في تخصيص المقاعد.';
          return;
        }

        final bookingId = _uuid.v4();
        final totalPrice = seatsToBook * tripPricePerSeat;

        // تجهيز بيانات الحجز (مطابق للموديل و Firestore)
        final Map<String, dynamic> bookingPayload = {
          'id': bookingId,
          'tripId': tripId,
          'driverId': trip.driverId,
          'passengerId': passengerId,
          'passengerNickname': appUser.nickname,
          'bookedSeatsCount': seatsToBook,
          'childrenCount': childrenCount,
          'totalPrice': totalPrice,
          'amount': totalPrice.toString(), // الحقل النصي المطلوب
          'isFamilyBooking': isFamilyBooking,
          'bookingStatus': 'confirmed',
          'paymentStatus': 'unpaid',
          'paymentMethod': paymentMethod ?? 'نقداً',
          'paymentService': paymentService ?? '',
          'schemeHost': schemeHost ?? '',
          'notes': notes ?? '',
          'seatNumber': seatNumber,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // تنفيذ العمليات داخل النبضة الواحدة
        transaction.set(_firestore.collection(_bookingsCollection).doc(bookingId), bookingPayload);
        transaction.update(tripRef, {
          'seatStatus': newSeatStatus,
          'availableSeats': FieldValue.increment(-seatsToBook),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        bookingIdForNotification = bookingId;
        destinationForNotification = trip.destination;
      });

      // 4. إرسال إشعار عند النجاح
      if (errorMessage == null && bookingIdForNotification != null) {
        _sendSafeNotification(passengerId, 'تأكيد الحجز', '✅ تم حجز $seatsToBook مقاعد إلى $destinationForNotification');
      }

      return errorMessage ?? bookingIdForNotification;
    } catch (e, st) {
      debugPrint('BookingService.createBooking error: $e\n$st');
      return 'حدث خطأ أثناء الحجز. حاول مرة أخرى.';
    }
  }

  /// إلغاء الحجز وإعادة المقاعد للرحلة
  Future<String?> cancelBooking({required String bookingId, required String passengerId}) async {
    String? errorMessage;
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

        final tripRef = _firestore.collection(_tripsCollection).doc(booking.tripId);
        final tripSnapshot = await transaction.get(tripRef);

        if (tripSnapshot.exists) {
          final trip = Trip.fromDocument(tripSnapshot);
          final newSeatStatus = _releaseSeats(trip.seatStatus, booking.bookedSeatsCount);

          transaction.update(tripRef, {
            'seatStatus': newSeatStatus,
            'availableSeats': FieldValue.increment(booking.bookedSeatsCount),
          });
        }

        transaction.update(bookingRef, {
          'bookingStatus': 'cancelled',
          'canceledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return errorMessage;
    } catch (e) {
      return 'فشل إلغاء الحجز.';
    }
  }

  /// جلب حجوزات الركاب
  Future<List<Booking>> getBookingsForPassenger(String passengerId) async {
    try {
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('passengerId', isEqualTo: passengerId)
          .get();
      return snapshot.docs.map((doc) => Booking.fromDocument(doc)).toList()
        ..sort((a, b) => (b.createdAt ?? Timestamp.now()).compareTo(a.createdAt ?? Timestamp.now()));
    } catch (e) {
      return [];
    }
  }

  // --- دوال مساعدة لإدارة المقاعد ---

  List<bool>? _reserveSeats(List<bool> seatStatus, int count) {
    final updated = List<bool>.from(seatStatus);
    int reserved = 0;
    for (int i = 0; i < updated.length && reserved < count; i++) {
      if (updated[i]) {
        updated[i] = false;
        reserved++;
      }
    }
    return reserved == count ? updated : null;
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

  void _sendSafeNotification(String userId, String title, String body) {
    try {
      NotificationService().sendNotification(userId: userId, title: title, body: body, type: 'booking');
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }
}