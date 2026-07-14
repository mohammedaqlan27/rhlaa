// lib/services/booking_service.dart
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

  // ---------- Throttle state for client-side expire checks ----------
  DateTime? _lastExpireCheck;

  /// يفحص ويُلغي الحجوزات المعلقة التي انتهت صلاحيتها من جهة العميل.
  /// لا يستدعى أكثر من مرة خلال `minIntervalMinutes` على الجهاز الواحد.
  /// يستخدم batch لتقليل عدد عمليات الكتابة.
  Future<void> checkAndExpireBookings({int limit = 20, int minIntervalMinutes = 3}) async {
    final now = DateTime.now();
    if (_lastExpireCheck != null) {
      final diff = now.difference(_lastExpireCheck!);
      if (diff.inMinutes < minIntervalMinutes) {
        debugPrint('checkAndExpireBookings: throttled (last run ${diff.inMinutes} minutes ago)');
        return;
      }
    }
    _lastExpireCheck = now;

    final Timestamp nowTs = Timestamp.fromDate(now);

    try {
      final bookingSnapshot = await _firestore
          .collection(_bookingsCollection)
          .where('bookingStatus', isEqualTo: 'pending')
          .where('reservedUntil', isLessThanOrEqualTo: nowTs)
          .limit(limit)
          .get();

      if (bookingSnapshot.docs.isEmpty) {
        debugPrint('No expired pending bookings found (client check).');
        return;
      }

      debugPrint('Found ${bookingSnapshot.docs.length} expired bookings (client). Processing...');

      final WriteBatch batch = _firestore.batch();
      final Map<String, Map<String, dynamic>> tripsToUpdate = {};

      for (final doc in bookingSnapshot.docs) {
        final bookingData = doc.data();
        final String bookingId = doc.id;
        final String? tripId = bookingData['tripId'] as String?;
        final List<dynamic> seatIndexes = bookingData['seatIndexes'] ?? [];
        final int bookedSeatsCount = (bookingData['bookedSeatsCount'] ?? 0) as int;

        // تحديث حالة الحجز إلى ملغى
        batch.update(doc.reference, {
          'bookingStatus': 'cancelled',
          'canceledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': 'client_expire',
        });

        if (tripId != null && tripId.isNotEmpty) {
          if (!tripsToUpdate.containsKey(tripId)) {
            tripsToUpdate[tripId] = {
              'seatIndexesList': <List<dynamic>>[],
              'totalSeatsToReturn': 0,
            };
          }
          (tripsToUpdate[tripId]!['seatIndexesList'] as List).add(seatIndexes);
          tripsToUpdate[tripId]!['totalSeatsToReturn'] =
              (tripsToUpdate[tripId]!['totalSeatsToReturn'] as int) + bookedSeatsCount;
        }
      }

      // قراءة كل الرحلات المطلوبة وتحديثها في الـ batch
      for (final tripId in tripsToUpdate.keys) {
        final tripRef = _firestore.collection(_tripsCollection).doc(tripId);
        final tripSnap = await tripRef.get();
        if (!tripSnap.exists) {
          debugPrint('Trip $tripId not found while expiring bookings (client).');
          continue;
        }

        final tripData = tripSnap.data() as Map<String, dynamic>;
        List<dynamic> seatStatus = List<dynamic>.from(tripData['seatStatus'] ?? []);
        final int totalSeats = (tripData['totalSeats'] ?? seatStatus.length) as int;

        if (seatStatus.isEmpty) {
          seatStatus = List.generate(totalSeats, (_) => true);
        }

        final List<List<dynamic>> seatIndexesList =
        List<List<dynamic>>.from(tripsToUpdate[tripId]!['seatIndexesList'] as List);
        int totalToReturn = tripsToUpdate[tripId]!['totalSeatsToReturn'] as int;

        bool usedIndexes = false;
        for (final idxList in seatIndexesList) {
          if (idxList.isNotEmpty) {
            usedIndexes = true;
            for (final idx in idxList) {
              if (idx is int && idx >= 0 && idx < seatStatus.length) {
                seatStatus[idx] = true;
              }
            }
          }
        }

        if (!usedIndexes && totalToReturn > 0) {
          int released = 0;
          for (int i = 0; i < seatStatus.length && released < totalToReturn; i++) {
            if (seatStatus[i] == false) {
              seatStatus[i] = true;
              released++;
            }
          }
        }

        batch.update(tripRef, {
          'seatStatus': seatStatus,
          'availableSeats': FieldValue.increment(totalToReturn),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('Expired bookings processed and trips updated successfully (client).');
    } catch (e, st) {
      debugPrint('Error in checkAndExpireBookings: $e\n$st');
    }
  }

  // ---------- Existing methods (kept and unchanged except minor integration) ----------

  /// إنشاء حجز مؤقت (pending) مع دعم idempotency عبر clientBookingId
  /// يعيد bookingId عند النجاح أو رسالة خطأ (String) عند الفشل
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

    String? errorMessage;
    String? bookingIdForReturn;

    try {
      // جلب بيانات الراكب (لملء passengerNickname)
      final passengerDoc = await _firestore.collection(_usersCollection).doc(passengerId).get();
      if (!passengerDoc.exists) return 'بيانات الراكب غير موجودة.';
      final appUser = AppUser.fromDocument(passengerDoc);

      // نستخدم clientBookingId إن وُجد لتفادي التكرار
      final bookingId = clientBookingId ?? _uuid.v4();
      final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);

      // تحقق مبكر من وجود مستند بنفس المعرف (idempotency)
      final existingBooking = await bookingRef.get();
      if (existingBooking.exists) {
        // إذا وُجد مستند بنفس id نعيده كنجاح idempotent
        return bookingRef.id;
      }

      // تحقق سريع من وجود حجز قائم لنفس الراكب والرحلة (confirmed أو pending)
      final existingQuery = await _firestore
          .collection(_bookingsCollection)
          .where('tripId', isEqualTo: tripId)
          .where('passengerId', isEqualTo: passengerId)
          .where('bookingStatus', whereIn: ['pending', 'confirmed'])
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        return 'لديك حجز قائم لهذه الرحلة.';
      }

      // ابدأ الترانزاكشن لحجز المقاعد وكتابة الحجز في نفس العملية
      await _firestore.runTransaction((transaction) async {
        final tripRef = _firestore.collection(_tripsCollection).doc(tripId);
        final tripSnapshot = await transaction.get(tripRef);

        if (!tripSnapshot.exists) {
          errorMessage = 'الرحلة غير موجودة.';
          return;
        }

        final trip = Trip.fromDocument(tripSnapshot);

        if (trip.availableSeats < seatsToBook) {
          errorMessage = 'لا توجد مقاعد كافية. المتاح حالياً: ${trip.availableSeats}';
          return;
        }

        // حجز المقاعد: نحجز أول N مقاعد متاحة ونحصل على seatIndexes
        final newSeatStatus = _reserveSeats(trip.seatStatus, seatsToBook);
        if (newSeatStatus == null) {
          errorMessage = 'فشل في تخصيص المقاعد.';
          return;
        }

        final seatIndexes = _extractReservedIndexes(trip.seatStatus, newSeatStatus);
        final totalPrice = seatsToBook * tripPricePerSeat;
        final reservedUntil = Timestamp.fromDate(DateTime.now().add(reservationDuration));

        final bookingPayload = {
          'tripId': tripId,
          'passengerId': passengerId,
          'passengerNickname': appUser.nickname ?? '',
          'driverId': trip.driverId,
          'bookedSeatsCount': seatsToBook,
          'totalPrice': totalPrice,
          'isFamilyBooking': isFamilyBooking,
          'childrenCount': childrenCount,
          'bookingStatus': 'pending',
          'paymentStatus': 'unpaid',
          'notes': notes ?? '',
          'seatIndexes': seatIndexes,
          'reservedUntil': reservedUntil,
          'paymentIntentId': null,
          'canceledAt': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        transaction.set(bookingRef, bookingPayload);

        transaction.update(tripRef, {
          'seatStatus': newSeatStatus,
          'availableSeats': FieldValue.increment(-seatsToBook),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        bookingIdForReturn = bookingRef.id;
      });

      if (errorMessage == null && bookingIdForReturn != null) {
        _sendSafeNotification(passengerId, 'تم إنشاء الحجز مؤقتاً', 'تم حجز المقاعد مؤقتاً، يرجى إتمام الدفع خلال المهلة المحددة.');
      }

      return errorMessage ?? bookingIdForReturn;
    } catch (e, st) {
      debugPrint('BookingService.createBookingPending error: $e\n$st');
      return 'حدث خطأ أثناء إنشاء الحجز.';
    }
  }

  /// تأكيد الحجز بعد نجاح الدفع: يحدث bookingStatus -> confirmed و paymentStatus -> paid
  /// يتحقق من أن الحجز ما زال pending ولم تنتهِ reservedUntil
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

      final raw = bookingSnap.data() ?? {};
      final reservedUntilRaw = raw['reservedUntil'];
      Timestamp? reservedUntil;
      if (reservedUntilRaw is Timestamp) reservedUntil = reservedUntilRaw;
      else if (reservedUntilRaw is String) {
        final dt = DateTime.tryParse(reservedUntilRaw);
        if (dt != null) reservedUntil = Timestamp.fromDate(dt);
      }

      if (booking.bookingStatus.toLowerCase() == 'confirmed') return null;

      if (reservedUntil != null && reservedUntil.toDate().isBefore(DateTime.now())) {
        // الحجز انتهت مهلة الحجز المؤقت
        // نلغي الحجز بدلاً من تأكيده
        await cancelBooking(bookingId: bookingId, passengerId: payerId);
        return 'انتهت مهلة الحجز المؤقت، تم إلغاؤه.';
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
      debugPrint('BookingService.confirmBookingAfterPayment error: $e\n$st');
      return 'فشل تأكيد الحجز بعد الدفع.';
    }
  }

  /// إلغاء الحجز (pending أو confirmed) وإرجاع المقاعد
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

        final tripRef = _firestore.collection(_tripsCollection).doc(booking.tripId);
        final tripSnapshot = await transaction.get(tripRef);

        if (tripSnapshot.exists) {
          final trip = Trip.fromDocument(tripSnapshot);
          final newSeatStatus = _releaseSpecificIndexes(trip.seatStatus, booking.seatIndexes ?? [], booking.bookedSeatsCount);

          transaction.update(tripRef, {
            'seatStatus': newSeatStatus,
            'availableSeats': FieldValue.increment(booking.bookedSeatsCount),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(bookingRef, {
          'bookingStatus': 'cancelled',
          'paymentStatus': booking.paymentStatus == 'paid' ? booking.paymentStatus : 'unpaid',
          'canceledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _sendSafeNotification(passengerId, 'تم إلغاء الحجز', 'تم إلغاء حجزك وإرجاع المقاعد.');
      return null;
    } catch (e, st) {
      debugPrint('BookingService.cancelBooking error: $e\n$st');
      return 'فشل إلغاء الحجز.';
    }
  }

  /// دالة تُستدعى من Cloud Function أو مجدول لإلغاء الحجوزات المؤقتة المنتهية
  Future<void> expirePendingBooking(String bookingId) async {
    try {
      final bookingRef = _firestore.collection(_bookingsCollection).doc(bookingId);
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) return;

      final booking = Booking.fromDocument(bookingSnap);
      if (booking.bookingStatus.toLowerCase() != 'pending') return;

      final raw = bookingSnap.data() ?? {};
      final reservedUntilRaw = raw['reservedUntil'];
      Timestamp? reservedUntil;
      if (reservedUntilRaw is Timestamp) reservedUntil = reservedUntilRaw;
      else if (reservedUntilRaw is String) {
        final dt = DateTime.tryParse(reservedUntilRaw);
        if (dt != null) reservedUntil = Timestamp.fromDate(dt);
      }

      if (reservedUntil == null) return;
      if (reservedUntil.toDate().isBefore(DateTime.now())) {
        await cancelBooking(bookingId: bookingId, passengerId: booking.passengerId);
      }
    } catch (e, st) {
      debugPrint('BookingService.expirePendingBooking error: $e\n$st');
    }
  }

  /// جلب حجوزات الراكب
  Future<List<Booking>> getBookingsForPassenger(String passengerId) async {
    try {
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('passengerId', isEqualTo: passengerId)
          .get();

      final list = snapshot.docs.map((doc) => Booking.fromDocument(doc)).toList();
      list.sort((a, b) {
        final aTs = a.createdAt ?? Timestamp.now();
        final bTs = b.createdAt ?? Timestamp.now();
        return bTs.compareTo(aTs);
      });
      return list;
    } catch (e, st) {
      debugPrint('BookingService.getBookingsForPassenger error: $e\n$st');
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

  List<bool> _releaseSpecificIndexes(List<bool> seatStatus, List<int>? seatIndexes, int count) {
    final updated = List<bool>.from(seatStatus);
    if (seatIndexes != null && seatIndexes.isNotEmpty) {
      for (final idx in seatIndexes) {
        if (idx >= 0 && idx < updated.length) updated[idx] = true;
      }
      return updated;
    }

    int released = 0;
    for (int i = 0; i < updated.length && released < count; i++) {
      if (!updated[i]) {
        updated[i] = true;
        released++;
      }
    }
    return updated;
  }

  List<int> _extractReservedIndexes(List<bool> oldStatus, List<bool> newStatus) {
    final List<int> indexes = [];
    for (int i = 0; i < oldStatus.length && i < newStatus.length; i++) {
      if (oldStatus[i] == true && newStatus[i] == false) {
        indexes.add(i);
      }
    }
    return indexes;
  }

  void _sendSafeNotification(String userId, String title, String body) {
    try {
      NotificationService().sendNotification(userId: userId, title: title, body: body, type: 'booking');
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }
}
