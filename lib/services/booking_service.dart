// lib/services/booking_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../models/trip.dart';
import '../models/app_user.dart';
import 'notification_service.dart';

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

  // ---------------------------------------------------------
  // 1. خدمات جلب البيانات (Queries & Streams)
  // ---------------------------------------------------------

  /// جلب حجز واحد بواسطة المعرف (مفيد لتفاصيل الحجز عند النقر على إشعار)
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      final doc = await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      if (!doc.exists) return null;
      return Booking.fromDocument(doc);
    } catch (e) {
      debugPrint('BookingService.getBookingById error: $e');
      return null;
    }
  }

  /// بث مباشر لحجوزات الراكب (لتحديث الواجهة فوراً عند تغير الحالة)
  Stream<List<Booking>> streamBookingsForPassenger(String passengerId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Booking.fromDocument(doc)).toList());
  }

  /// جلب ركاب رحلة معينة (عرض السائق - الحجوزات المؤكدة فقط)
  Stream<List<Booking>> streamConfirmedBookingsForTrip(String tripId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('tripId', isEqualTo: tripId)
        .where('bookingStatus', isEqualTo: 'confirmed')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Booking.fromDocument(doc)).toList());
  }

  // ---------------------------------------------------------
  // 2. العمليات الأساسية (Core Logic)
  // ---------------------------------------------------------

  /// إنشاء حجز مؤقت مع التحقق من حالة الرحلة وتعارض المواعيد
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
      // أ. جلب بيانات الراكب والرحلة للتحقق الأولي
      final passengerDoc = await _firestore.collection(_usersCollection).doc(passengerId).get();
      if (!passengerDoc.exists) return 'بيانات الراكب غير موجودة.';
      final appUser = AppUser.fromDocument(passengerDoc);

      final tripDoc = await _firestore.collection(_tripsCollection).doc(tripId).get();
      if (!tripDoc.exists) return 'الرحلة غير موجودة.';
      final trip = Trip.fromDocument(tripDoc);

      // ب. التحقق من حالة الرحلة (منع الحجز إذا بدأت أو انتهت)
      if (trip.status != 'active' && trip.status != 'pending') {
        return 'عذراً، لا يمكن الحجز في هذه الرحلة حالياً (الحالة: ${trip.status}).';
      }

      // ج. التحقق من تعارض الحجوزات (منع حجز رحلتين في نفس الوقت)
      // ملاحظة: يتطلب هذا مقارنة تواريخ الرحلات، سنفترض وجود حجز قائم لنفس الرحلة حالياً
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

      // د. Idempotency check
      final existingBooking = await bookingRef.get();
      if (existingBooking.exists) return bookingRef.id;

      String? errorMessage;
      String? bookingIdForReturn;

      // هـ. تنفيذ الترانزاكشن لضمان دقة المقاعد
      await _firestore.runTransaction((transaction) async {
        final freshTripSnap = await transaction.get(tripDoc.reference);
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

        transaction.set(bookingRef, bookingPayload);
        transaction.update(tripDoc.reference, {
          'seatStatus': newSeatStatus,
          'availableSeats': FieldValue.increment(-seatsToBook),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        bookingIdForReturn = bookingRef.id;
      });

      if (errorMessage == null && bookingIdForReturn != null) {
        _sendSafeNotification(passengerId, 'تم إنشاء الحجز مؤقتاً', 'يرجى إتمام الدفع خلال 15 دقيقة لتأكيد مقعدك.');
      }

      return errorMessage ?? bookingIdForReturn;
    } catch (e) {
      debugPrint('BookingService.createBookingPending error: $e');
      return 'حدث خطأ أثناء إنشاء الحجز.';
    }
  }

  /// تأكيد الحجز بعد نجاح الدفع
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

      // التحقق من انتهاء الصلاحية قبل التأكيد
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

      _sendSafeNotification(booking.passengerId, 'تم تأكيد الحجز', '✅ تم تأكيد حجزك بنجاح. نتمنى لك رحلة سعيدة.');
      return null;
    } catch (e) {
      return 'فشل تأكيد الحجز بعد الدفع.';
    }
  }

  /// إلغاء الحجز مع منطق الاسترداد (Refund Logic)
  Future<String?> cancelBooking({
    required String bookingId,
    required String passengerId,
  }) async {
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

        // منطق الاسترداد: إذا كان مدفوعاً، نغير حالة الدفع لطلب استرداد
        final bool needsRefund = booking.paymentStatus == 'paid';

        final tripRef = _firestore.collection(_tripsCollection).doc(booking.tripId);
        final tripSnapshot = await transaction.get(tripRef);

        if (tripSnapshot.exists) {
          final trip = Trip.fromDocument(tripSnapshot);
          final newSeatStatus = _releaseSpecificIndexes(trip.seatStatus, booking.seatIndexes, booking.bookedSeatsCount);

          transaction.update(tripRef, {
            'seatStatus': newSeatStatus,
            'availableSeats': FieldValue.increment(booking.bookedSeatsCount),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(bookingRef, {
          'bookingStatus': 'cancelled',
          'paymentStatus': needsRefund ? 'refund_pending' : 'unpaid',
          'canceledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _sendSafeNotification(passengerId, 'تم إلغاء الحجز', 'تم إلغاء حجزك بنجاح وإعادة المقاعد للرحلة.');
      return errorMessage;
    } catch (e) {
      return 'فشل إلغاء الحجز.';
    }
  }

  // ---------------------------------------------------------
  // 3. خدمات إضافية (Waitlist & Cleanup)
  // ---------------------------------------------------------

  /// إضافة مستخدم لقائمة الانتظار عند اكتمال الرحلة
  Future<void> addToWaitlist(String tripId, String userId) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({
        'waitlist': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding to waitlist: $e');
    }
  }

  /// تنظيف الحجوزات المنتهية (Batch)
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
        // ملاحظة: تحرير المقاعد يفضل أن يتم عبر Cloud Function لضمان الدقة في العمليات الجماعية
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error in checkAndExpireBookings: $e');
    }
  }

  /// إلغاء حجز واحد منتهي
  Future<void> expirePendingBooking(String bookingId) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking != null && booking.bookingStatus == 'pending') {
        if (booking.reservedUntil != null && booking.reservedUntil!.toDate().isBefore(DateTime.now())) {
          await cancelBooking(bookingId: bookingId, passengerId: booking.passengerId);
        }
      }
    } catch (e) {}
  }

  // ---------------------------------------------------------
  // 4. دوال مساعدة (Private Helpers)
  // ---------------------------------------------------------

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
      _notificationService.sendNotification(
        userId: userId,
        title: title,
        body: body,
        type: 'booking',
      );
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }
}