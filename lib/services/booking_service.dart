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

  // =================== Helpers ===================

  /// يحول قيمة ديناميكية إلى bool بأمان
  /// يقبل bool, num, String ('true','1'), وإلا يرجع القيمة الافتراضية (defaultValue)
  bool _toBool(dynamic v, {bool defaultValue = true}) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'y';
    }
    return defaultValue;
  }

  /// يحول قيمة ديناميكية إلى int بأمان
  int _toInt(dynamic v, {int defaultValue = 0}) {
    if (v == null) return defaultValue;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? defaultValue;
    return defaultValue;
  }

  /// يحول قيمة ديناميكية إلى List<dynamic> إن أمكن، وإلا يعيد قائمة فارغة
  List<dynamic> _toList(dynamic v) {
    if (v == null) return <dynamic>[];
    if (v is List) return v;
    // إذا كان مخزناً كسلسلة JSON
    if (v is String) {
      try {
        final parsed = v.trim();
        if (parsed.startsWith('[') && parsed.endsWith(']')) {
          // محاولة بسيطة لتحويل JSON array
          return List<dynamic>.from(List<dynamic>.from([]));
        }
      } catch (_) {}
    }
    return <dynamic>[];
  }

  // =================== End Helpers ===================

  /// إنشاء حجز جديد
  /// يعيد معرف الحجز عند النجاح، أو رسالة خطأ نصية عند الفشل
  /// يكتب الحقول بصيغة camelCase فقط
  Future<String?> createBooking({
    required String tripId,
    required String passengerId,
    required int seatsToBook,
    required double tripPricePerSeat,
    required bool isFamilyBooking,
    required int childrenCount,
    int? seatNumber, // اختياري
    String? paymentMethod, // اختياري
  }) async {
    if (seatsToBook <= 0) return 'عدد المقاعد غير صالح.';
    if (tripPricePerSeat < 0) return 'سعر المقعد غير صالح.';

    String? errorMessage;
    String? bookingIdForNotification;
    String? passengerForNotification;
    String? destinationForNotification;
    int seatsForNotification = 0;

    try {
      final passengerDoc = await _firestore.collection(_usersCollection).doc(passengerId).get();
      if (!passengerDoc.exists) return 'بيانات الراكب غير موجودة.';
      final appUser = AppUser.fromDocument(passengerDoc);

      await _firestore.runTransaction((transaction) async {
        final tripRef = _firestore.collection(_tripsCollection).doc(tripId);
        final tripSnapshot = await transaction.get(tripRef);
        if (!tripSnapshot.exists) {
          errorMessage = 'الرحلة غير موجودة.';
          return;
        }

        final trip = Trip.fromDocument(tripSnapshot);

        // availableSeats يجب أن يكون عدد صحيح صالح
        final int availableSeats = _toInt(trip.availableSeats, defaultValue: 0);

        if (availableSeats < seatsToBook) {
          errorMessage = 'لا توجد مقاعد كافية. المتاح: $availableSeats';
          return;
        }

        // seatStatus: نتوقع قائمة من bool حيث true = متاح، false = محجوز
        List<bool> seatStatusList;
        try {
          final raw = trip.seatStatus;
          final listRaw = _toList(raw);
          if (listRaw.isNotEmpty) {
            seatStatusList = listRaw.map<bool>((e) => _toBool(e, defaultValue: true)).toList();
          } else {
            final int total = trip.totalSeats > 0 ? trip.totalSeats : availableSeats;
            seatStatusList = List<bool>.filled(total, true); // افتراض جميع المقاعد متاحة
          }
        } catch (_) {
          final int total = trip.totalSeats > 0 ? trip.totalSeats : availableSeats;
          seatStatusList = List<bool>.filled(total, true); // افتراض جميع المقاعد متاحة
        }

        // تحقق من وجود حجز مؤكد سابق لنفس الراكب على نفس الرحلة (camelCase queries only)
        final existingQuery = await _firestore
            .collection(_bookingsCollection)
            .where('tripId', isEqualTo: tripId)
            .where('passengerId', isEqualTo: passengerId)
            .where('bookingStatus', whereIn: ['مؤكد', 'confirmed'])
            .get();

        if (existingQuery.docs.isNotEmpty) {
          errorMessage = 'لديك حجز مؤكد مسبقاً لهذه الرحلة.';
          return;
        }

        // احجز المقاعد محليًا (نحدّث حالة المقاعد)
        final newSeatStatus = _reserveSeats(seatStatusList, seatsToBook);

        final bookingId = _uuid.v4();
        final totalPrice = seatsToBook * tripPricePerSeat;

        // بناء خريطة الحجز بصيغة camelCase فقط
        final Map<String, dynamic> bookingPayload = {
          'tripId': tripId,
          'driverId': trip.driverId,
          'passengerId': passengerId,
          'bookedSeatsCount': seatsToBook,
          'totalPrice': totalPrice,
          'passengerNickname': appUser.nickname ?? '',
          'isFamilyBooking': isFamilyBooking,
          'childrenCount': childrenCount,
          'bookingStatus': 'مؤكد',
          'paymentStatus': 'unpaid',
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (seatNumber != null) {
          bookingPayload['seatNumber'] = seatNumber;
        }
        if (paymentMethod != null && paymentMethod.isNotEmpty) {
          bookingPayload['paymentMethod'] = paymentMethod;
        }

        // اكتب الحجز وحدّث حالة الرحلة داخل المعاملة
        transaction.set(_firestore.collection(_bookingsCollection).doc(bookingId), bookingPayload);
        transaction.update(tripRef, {
          'seatStatus': newSeatStatus,
          'availableSeats': FieldValue.increment(-seatsToBook),
        });

        // حفظ بيانات للإشعار وبعد انتهاء المعاملة لإرجاع المعرف
        bookingIdForNotification = bookingId;
        passengerForNotification = passengerId;
        destinationForNotification = trip.destination;
        seatsForNotification = seatsToBook;
      });

      // بعد انتهاء المعاملة بنجاح، أرسل إشعار الحجز (خارج المعاملة)
      if (errorMessage == null && passengerForNotification != null) {
        await NotificationService().sendNotification(
          userId: passengerForNotification!,
          title: 'تأكيد الحجز',
          body: '✅ تم تأكيد حجزك لـ $seatsForNotification مقاعد في الرحلة إلى ${destinationForNotification ?? ''}.',
          type: 'booking',
        );
      }

      // إذا لم يكن هناك خطأ، أعد معرف الحجز الذي تم إنشاؤه
      if (errorMessage == null) {
        return bookingIdForNotification;
      }

      return errorMessage;
    } catch (e, st) {
      debugPrint('BookingService.createBooking error: $e\n$st');
      return 'فشلت عملية الحجز.';
    }
  }

  /// إلغاء حجز
  /// يحدّث الحقول بصيغة camelCase فقط
  Future<String?> cancelBooking({
    required String bookingId,
    required String passengerId,
  }) async {
    String? errorMessage;
    String? passengerForNotification;
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
        if (booking.bookingStatus == 'ملغى' || booking.bookingStatus == 'cancelled' || booking.bookingStatus == 'canceled') {
          errorMessage = 'الحجز ملغى مسبقًا.';
          return;
        }

        final tripRef = _firestore.collection(_tripsCollection).doc(booking.tripId);
        final tripSnapshot = await transaction.get(tripRef);
        if (!tripSnapshot.exists) {
          errorMessage = 'الرحلة غير موجودة.';
          return;
        }

        final trip = Trip.fromDocument(tripSnapshot);

        // تأكد من seatStatus صالح (true = متاح)
        List<bool> seatStatusList;
        try {
          final raw = trip.seatStatus;
          final listRaw = _toList(raw);
          if (listRaw.isNotEmpty) {
            seatStatusList = listRaw.map<bool>((e) => _toBool(e, defaultValue: true)).toList();
          } else {
            final int total = trip.totalSeats > 0 ? trip.totalSeats : 0;
            seatStatusList = List<bool>.filled(total, true);
          }
        } catch (_) {
          final int total = trip.totalSeats > 0 ? trip.totalSeats : 0;
          seatStatusList = List<bool>.filled(total, true);
        }

        final newSeatStatus = _releaseSeats(seatStatusList, booking.bookedSeatsCount);

        transaction.update(tripRef, {
          'seatStatus': newSeatStatus,
          'availableSeats': FieldValue.increment(booking.bookedSeatsCount),
        });

        // تحديث الحجز بصيغة camelCase فقط
        transaction.update(bookingRef, {
          'bookingStatus': 'ملغى',
          'paymentStatus': 'refund_pending',
          'canceledAt': FieldValue.serverTimestamp(),
        });

        passengerForNotification = booking.passengerId;
        destinationForNotification = trip.destination;
      });

      // إرسال إشعار الإلغاء بعد انتهاء المعاملة
      if (errorMessage == null && passengerForNotification != null) {
        await NotificationService().sendNotification(
          userId: passengerForNotification!,
          title: 'إلغاء الحجز',
          body: '❌ تم إلغاء حجزك للرحلة إلى ${destinationForNotification ?? ''}.',
          type: 'cancel',
        );
      }

      return errorMessage;
    } catch (e, st) {
      debugPrint('BookingService.cancelBooking error: $e\n$st');
      return 'فشلت عملية الإلغاء.';
    }
  }

  /// جلب حجوزات السائق (camelCase queries)
  Future<List<Booking>> getBookingsForDriver(String driverId) async {
    try {
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('driverId', isEqualTo: driverId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Booking.fromDocument(doc)).toList();
    } catch (e, st) {
      debugPrint('BookingService.getBookingsForDriver error: $e\n$st');
      return [];
    }
  }

  /// جلب حجوزات الراكب (camelCase queries)
  Future<List<Booking>> getBookingsForPassenger(String passengerId) async {
    try {
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('passengerId', isEqualTo: passengerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Booking.fromDocument(doc)).toList();
    } catch (e, st) {
      debugPrint('BookingService.getBookingsForPassenger error: $e\n$st');
      return [];
    }
  }

  /// حجز المقاعد: يعيد قائمة جديدة من حالات المقاعد (true = متاح, false = محجوز)
  List<bool> _reserveSeats(List<bool> seatStatus, int count) {
    final updated = List<bool>.from(seatStatus);
    int reserved = 0;
    for (int i = 0; i < updated.length && reserved < count; i++) {
      if (updated[i]) {
        // إذا المقعد متاح (true) نضعه محجوز (false)
        updated[i] = false;
        reserved++;
      }
    }
    // إذا لم تكن هناك مقاعد كافية في القائمة، نضيف مقاعد محجوزة (false) في نهاية القائمة
    while (reserved < count) {
      updated.add(false);
      reserved++;
    }
    return updated;
  }

  /// تحرير المقاعد: يعيد قائمة جديدة بعد تحرير عدد المقاعد المحدد
  /// (يضع true للمقاعد التي تم تحريرها)
  List<bool> _releaseSeats(List<bool> seatStatus, int count) {
    final updated = List<bool>.from(seatStatus);
    int released = 0;
    for (int i = 0; i < updated.length && released < count; i++) {
      if (!updated[i]) {
        // إذا المقعد محجوز (false) نحرره (true)
        updated[i] = true;
        released++;
      }
    }
    // إذا لم نحرر العدد المطلوب، نضيف مقاعد متاحة في نهاية القائمة
    while (released < count) {
      updated.add(true);
      released++;
    }
    return updated;
  }
}
