// lib/services/booking_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import '../models/booking_model.dart';
import '../models/trip.dart';
import '../models/app_user.dart';
import 'notification_service.dart';

/// BookingService محسّن: يدعم عمليات الحجز داخل Transaction، بث مباشر، انتهاء الحجز، قائمة انتظار، وتنبيهات.
class BookingService {
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;
  final Uuid _uuid = const Uuid();

  final String _tripsCollection = 'trips';
  final String _bookingsCollection = 'bookings';
  final String _usersCollection = 'users';

  BookingService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationService = notificationService ?? NotificationService();

  // -------------------------
  // Queries & Streams
  // -------------------------
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      final doc = await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      if (!doc.exists) return null;
      return Booking.fromDocument(doc);
    } catch (e) {
      if (kDebugMode) debugPrint('BookingService.getBookingById error: $e');
      return null;
    }
  }

  Stream<List<Booking>> streamBookingsForPassenger(String passengerId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Booking.fromDocument(d)).toList());
  }

  Stream<List<Booking>> streamConfirmedBookingsForTrip(String tripId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('tripId', isEqualTo: tripId)
        .where('bookingStatus', isEqualTo: 'confirmed')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Booking.fromDocument(d)).toList());
  }

  /// بث حجوزات مرتبطة بسائق (كل الحجوزات التي لها driverId = driverId)
  Stream<List<Booking>> streamBookingsForDriver(String driverId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Booking.fromDocument(d)).toList());
  }

  // -------------------------
  // Core booking flow
  // -------------------------
  Future<String?> createBookingPending({
    required String tripId,
    required String passengerId,
    required int seatsToBook,
    required double tripPricePerSeat,
    bool isFamilyBooking = false,
    int childrenCount = 0,
    String? clientBookingId,
    String? notes,
    Duration reservationDuration = const Duration(minutes: 15),
  }) async {
    if (seatsToBook <= 0) return 'عدد المقاعد غير صالح.';
    try {
      final passengerDoc = await _firestore.collection(_usersCollection).doc(passengerId).get();
      if (!passengerDoc.exists) return 'بيانات الراكب غير موجودة.';
      final appUser = AppUser.fromDocument(passengerDoc);

      final tripRef = _firestore.collection(_tripsCollection).doc(tripId);
      final tripDoc = await tripRef.get();
      if (!tripDoc.exists) return 'الرحلة غير موجودة.';
      final trip = Trip.fromDocument(tripDoc);

      if (trip.status != 'active' && trip.status != 'pending') {
        return 'عذراً، لا يمكن الحجز في هذه الرحلة حالياً (الحالة: ${trip.status}).';
      }

      final existingQuery = await _firestore
          .collection(_bookingsCollection)
          .where('tripId', isEqualTo: tripId)
          .where('passengerId', isEqualTo: passengerId)
          .where('bookingStatus', whereIn: ['pending', 'confirmed'])
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) return 'لديك حجز قائم بالفعل لهذه الرحلة.';

      final bookingId = clientBookingId ?? _uuid.v4();
      final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);

      final existingBooking = await bookingRef.get();
      if (existingBooking.exists) return bookingRef.id;

      String? errorMessage;
      String? bookingIdForReturn;

      await _firestore.runTransaction((tx) async {
        final freshTripSnap = await tx.get(tripRef);
        final freshTrip = Trip.fromDocument(freshTripSnap);

        if (freshTrip.availableSeats < seatsToBook) {
          errorMessage = 'لا توجد مقاعد كافية. المتاح حالياً: ${freshTrip.availableSeats}';
          return;
        }

        final newSeatStatus = _reserveSeats(freshTrip.seatStatus, seatsToBook);
        if (newSeatStatus == null) {
          errorMessage = 'فشل في تخصيص المقاعد.';
          return;
        }

        final seatIndexes = _extractReservedIndexes(freshTrip.seatStatus, newSeatStatus);
        final totalPrice = seatsToBook * tripPricePerSeat;
        final reservedUntil = Timestamp.fromDate(DateTime.now().add(reservationDuration));

        final bookingPayload = {
          'tripId': tripId,
          'passengerId': passengerId,
          'passengerNickname': appUser.nickname,
          'driverId': freshTrip.driverId,
          'bookedSeatsCount': seatsToBook,
          'totalPrice': totalPrice,
          'isFamilyBooking': isFamilyBooking,
          'childrenCount': childrenCount,
          'bookingStatus': 'pending',
          'paymentStatus': 'unpaid',
          'notes': notes ?? '',
          'seatIndexes': seatIndexes,
          'reservedUntil': reservedUntil,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        tx.set(bookingRef, bookingPayload);
        tx.update(tripRef, {
          'seatStatus': newSeatStatus,
          'availableSeats': FieldValue.increment(-seatsToBook),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        bookingIdForReturn = bookingRef.id;
      });

      if (errorMessage == null && bookingIdForReturn != null) {
        _sendSafeNotification(passengerId, 'تم إنشاء الحجز مؤقتاً', 'يرجى إتمام الدفع خلال ${reservationDuration.inMinutes} دقيقة لتأكيد مقعدك.');
      }

      return errorMessage ?? bookingIdForReturn;
    } catch (e, st) {
      if (kDebugMode) debugPrint('BookingService.createBookingPending error: $e\n$st');
      return 'حدث خطأ أثناء إنشاء الحجز.';
    }
  }

  Future<String?> confirmBookingAfterPayment({
    required String bookingId,
    required String paymentIntentId,
    required String payerId,
  }) async {
    try {
      final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) return 'الحجز غير موجود.';
      final booking = Booking.fromDocument(bookingSnap);
      if (booking.passengerId != payerId) return 'غير مصرح لك بتأكيد هذا الحجز.';
      if (booking.bookingStatus.toLowerCase() == 'confirmed') return null;

      if (booking.reservedUntil != null && booking.reservedUntil!.toDate().isBefore(DateTime.now())) {
        await cancelBooking(bookingId: bookingId, passengerId: payerId);
        return 'انتهت مهلة الحجز المؤقت، تم إلغاؤه تلقائياً.';
      }

      await bookingRef.update({
        'bookingStatus': 'confirmed',
        'paymentStatus': 'paid',
        'paymentIntentId': paymentIntentId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _sendSafeNotification(booking.passengerId, 'تم تأكيد الحجز', '✅ تم تأكيد حجزك بنجاح.');
      return null;
    } catch (e, st) {
      if (kDebugMode) debugPrint('BookingService.confirmBookingAfterPayment error: $e\n$st');
      return 'فشل تأكيد الحجز بعد الدفع.';
    }
  }

  Future<String?> cancelBooking({
    required String bookingId,
    required String passengerId,
  }) async {
    String? errorMessage;
    try {
      await _firestore.runTransaction((tx) async {
        final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);
        final bookingSnapshot = await tx.get(bookingRef);

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
        final tripSnapshot = await tx.get(tripRef);

        if (tripSnapshot.exists) {
          final trip = Trip.fromDocument(tripSnapshot);
          final newSeatStatus = _releaseSpecificIndexes(trip.seatStatus, booking.seatIndexes, booking.bookedSeatsCount);

          tx.update(tripRef, {
            'seatStatus': newSeatStatus,
            'availableSeats': FieldValue.increment(booking.bookedSeatsCount),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        tx.update(bookingRef, {
          'bookingStatus': 'cancelled',
          'paymentStatus': booking.paymentStatus == 'paid' ? 'refund_pending' : 'unpaid',
          'canceledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _sendSafeNotification(passengerId, 'تم إلغاء الحجز', 'تم إلغاء حجزك وإعادة المقاعد للرحلة.');
      return errorMessage;
    } catch (e, st) {
      if (kDebugMode) debugPrint('BookingService.cancelBooking error: $e\n$st');
      return 'فشل إلغاء الحجز.';
    }
  }

  // -------------------------
  // Waitlist & cleanup
  // -------------------------
  Future<void> addToWaitlist(String tripId, String userId) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({
        'waitlist': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('BookingService.addToWaitlist error: $e');
    }
  }

  DateTime? _lastExpireCheck;
  Future<void> checkAndExpireBookings({int limit = 20, int minIntervalMinutes = 3}) async {
    final now = DateTime.now();
    if (_lastExpireCheck != null && now.difference(_lastExpireCheck!).inMinutes < minIntervalMinutes) return;
    _lastExpireCheck = now;

    try {
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('bookingStatus', isEqualTo: 'pending')
          .where('reservedUntil', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .limit(limit)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'bookingStatus': 'cancelled',
          'updatedBy': 'system_expire',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('BookingService.checkAndExpireBookings error: $e');
    }
  }

  // -------------------------
  // Private helpers
  // -------------------------
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

  List<bool> _releaseSpecificIndexes(List<bool> seatStatus, List<int>? seatIndexes, int count) {
    final updated = List<bool>.from(seatStatus);
    if (seatIndexes != null && seatIndexes.isNotEmpty) {
      for (final idx in seatIndexes) {
        if (idx >= 0 && idx < updated.length) updated[idx] = true;
      }
    } else {
      int released = 0;
      for (int i = 0; i < updated.length && released < count; i++) {
        if (!updated[i]) {
          updated[i] = true;
          released++;
        }
      }
    }
    return updated;
  }

  List<int> _extractReservedIndexes(List<bool> oldStatus, List<bool> newStatus) {
    final List<int> indexes = [];
    for (int i = 0; i < oldStatus.length && i < newStatus.length; i++) {
      if (oldStatus[i] == true && newStatus[i] == false) indexes.add(i);
    }
    return indexes;
  }

  void _sendSafeNotification(String userId, String title, String body) {
    try {
      _notificationService.sendNotification(userId: userId, title: title, body: body, type: 'booking');
    } catch (e) {
      if (kDebugMode) debugPrint('BookingService.notification error: $e');
    }
  }

  // -------------------------
  // Driver actions (confirm / reject)
  // -------------------------

  /// يؤكد الحجز نيابة عن السائق (يغير الحالة إلى confirmed)
  Future<String?> confirmBookingByDriver(String bookingId) async {
    try {
      final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) return 'الحجز غير موجود.';
      final booking = Booking.fromDocument(bookingSnap);

      if (booking.bookingStatus.toLowerCase() == 'confirmed') return null;

      await bookingRef.update({
        'bookingStatus': 'confirmed',
        'updatedBy': 'driver',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _sendSafeNotification(booking.passengerId, 'تم قبول الحجز', '✅ تم قبول حجزك من قبل السائق.');
      return null;
    } catch (e, st) {
      if (kDebugMode) debugPrint('BookingService.confirmBookingByDriver error: $e\n$st');
      return 'فشل تأكيد الحجز من قبل السائق.';
    }
  }

  /// يرفض الحجز من قبل السائق ويعيد المقاعد إلى الرحلة
  Future<String?> rejectBookingByDriver(String bookingId, {String? reason}) async {
    try {
      final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) return 'الحجز غير موجود.';
      final booking = Booking.fromDocument(bookingSnap);

      final tripRef = _firestore.collection(_tripsCollection).doc(booking.tripId);

      await _firestore.runTransaction((tx) async {
        final tripSnap = await tx.get(tripRef);
        if (tripSnap.exists) {
          final trip = Trip.fromDocument(tripSnap);
          final newSeatStatus = _releaseSpecificIndexes(trip.seatStatus, booking.seatIndexes, booking.bookedSeatsCount);
          tx.update(tripRef, {
            'seatStatus': newSeatStatus,
            'availableSeats': FieldValue.increment(booking.bookedSeatsCount),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        tx.update(bookingRef, {
          'bookingStatus': 'cancelled',
          'paymentStatus': booking.paymentStatus == 'paid' ? 'refund_pending' : 'unpaid',
          'canceledAt': FieldValue.serverTimestamp(),
          'updatedBy': 'driver',
          'cancelReason': reason ?? 'رفض من السائق',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _sendSafeNotification(booking.passengerId, 'تم رفض الحجز', 'تم رفض حجزك من قبل السائق.');
      return null;
    } catch (e, st) {
      if (kDebugMode) debugPrint('BookingService.rejectBookingByDriver error: $e\n$st');
      return 'فشل رفض الحجز من قبل السائق.';
    }
  }

  /// Wrappers that are safe to call from providers (catch exceptions)
  Future<String?> confirmBookingByDriverSafe(String bookingId) async {
    try {
      return await confirmBookingByDriver(bookingId);
    } catch (e, st) {
      if (kDebugMode) debugPrint('confirmBookingByDriverSafe error: $e\n$st');
      return 'فشل داخلي أثناء تأكيد الحجز.';
    }
  }

  Future<String?> rejectBookingByDriverSafe(String bookingId, {String? reason}) async {
    try {
      return await rejectBookingByDriver(bookingId, reason: reason);
    } catch (e, st) {
      if (kDebugMode) debugPrint('rejectBookingByDriverSafe error: $e\n$st');
      return 'فشل داخلي أثناء رفض الحجز.';
    }
  }
}
