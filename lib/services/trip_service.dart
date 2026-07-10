// lib/services/trip_service.dart
//
// خدمة إدارة الرحلات (TripService) مع تكامل لحساب رسوم الفرزة الحكومية (govFee).
// - عند إنشاء رحلة جديدة: تحفظ الرحلة ثم تحسب govFee تلقائياً عبر GovFeesService.
// - عند تحديث رحلة: إذا تغيّر origin أو destination أو distanceKm، تعيد حساب govFee.
// - توفر دوال مساعدة لجلب الرحلات، تحديث المقاعد، حذف الرحلات، وإشعارات المستخدمين.
//
// متطلبات:
// - وجود ملف models/trip.dart (محدّث ليحتوي على govFeeAmount و distanceKm).
// - وجود GovFeesService في lib/services/govfees_service.dart
// - وجود NotificationService و BookingService إن لزم (NotificationService مستخدمة هنا).
// - تأكد من قواعد Firestore للسماح بالعمليات المطلوبة.

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/trip.dart';
import '../models/app_user.dart';
import '../services/notification_service.dart';
import '../services/govfees_service.dart';

class TripService {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  final String _tripsCollection = 'trips';
  final String _usersCollection = 'users';
  final String _ratingsCollection = 'ratings';

  final GovFeesService _govFeesService;

  TripService({FirebaseFirestore? firestore, GovFeesService? govFeesService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _govFeesService = govFeesService ?? GovFeesService();

  /// التحقق من أن المستخدم سائق وموثق (Verified)
  Future<bool> isDriverVerified(String driverId) async {
    try {
      if (driverId.isEmpty) return false;
      final doc = await _firestore.collection(_usersCollection).doc(driverId).get();
      if (!doc.exists) return false;
      final user = AppUser.fromDocument(doc);
      return user.isDriver && user.isIdVerified;
    } catch (e, st) {
      debugPrint('TripService.isDriverVerified error: $e\n$st');
      return false;
    }
  }

  /// إنشاء رحلة جديدة
  /// - يتحقق من توثيق السائق.
  /// - يملأ الحقول الافتراضية (availableSeats, seatStatus, driverName).
  /// - يحفظ الرحلة ثم يستدعي GovFeesService.computeAndSetGovFeeForTrip لحساب govFeeAmount.
  Future<String?> createTrip(Trip trip) async {
    try {
      if (trip.driverId.isEmpty) {
        debugPrint('TripService.createTrip error: driverId is empty');
        return null;
      }

      final isDriverOk = await isDriverVerified(trip.driverId);
      if (!isDriverOk) {
        debugPrint('TripService: Driver is not verified or not a driver.');
        return null;
      }

      // جلب اسم السائق من مستند المستخدم إن لم يكن موجوداً في الكائن
      String driverName = trip.driverName;
      try {
        final userDoc = await _firestore.collection(_usersCollection).doc(trip.driverId).get();
        if (userDoc.exists) {
          final user = AppUser.fromDocument(userDoc);
          if (user.nickname.isNotEmpty) driverName = user.nickname;
        }
      } catch (_) {
        // تجاهل خطأ جلب اسم السائق، نستخدم الاسم الموجود في الكائن
      }

      final String finalId = trip.id.isEmpty ? _uuid.v4() : trip.id;
      final int seats = trip.totalSeats > 0 ? trip.totalSeats : 0;
      final List<bool> initialSeatStatus = List<bool>.filled(seats, true);

      final finalTrip = trip.copyWith(
        id: finalId,
        availableSeats: seats,
        seatStatus: initialSeatStatus,
        driverName: driverName,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      await _firestore.collection(_tripsCollection).doc(finalId).set(finalTrip.toMap());

      // حساب رسوم الفرزة الحكومية تلقائياً بعد الإنشاء
      try {
        await _govFeesService.computeAndSetGovFeeForTrip(finalId);
      } catch (e) {
        debugPrint('TripService.createTrip: gov fee compute failed for $finalId: $e');
        // لا نعيد الخطأ لأن الرحلة تم إنشاؤها بنجاح؛ يمكن إعادة المحاولة لاحقاً
      }

      return finalId;
    } catch (e, st) {
      debugPrint('TripService.createTrip error: $e\n$st');
      return null;
    }
  }

  /// تحديث بيانات الرحلة
  /// - يقارن الحقول القديمة بالجديدة (origin, destination, distanceKm) ويعيد حساب govFee إذا لزم.
  Future<bool> updateTrip(String tripId, Trip updatedTrip) async {
    try {
      final tripRef = _firestore.collection(_tripsCollection).doc(tripId);
      final existingSnap = await tripRef.get();
      if (!existingSnap.exists) {
        debugPrint('TripService.updateTrip: trip not found $tripId');
        return false;
      }

      final existingTrip = Trip.fromDocument(existingSnap);

      // نحضر الخريطة للتحديث
      final data = updatedTrip.toMap();
      // لا نسمح بتغيير createdAt عبر التحديث العادي
      data.remove('createdAt');

      await tripRef.update(data);

      // إذا تغيّر origin أو destination أو distanceKm، أعد حساب govFee
      final originChanged = (existingTrip.origin != updatedTrip.origin);
      final destinationChanged = (existingTrip.destination != updatedTrip.destination);
      final distanceChanged = ((existingTrip.distanceKm ?? 0.0) != (updatedTrip.distanceKm ?? 0.0));

      if (originChanged || destinationChanged || distanceChanged) {
        try {
          await _govFeesService.computeAndSetGovFeeForTrip(tripId);
        } catch (e) {
          debugPrint('TripService.updateTrip: gov fee recompute failed for $tripId: $e');
        }
      }

      return true;
    } catch (e, st) {
      debugPrint('TripService.updateTrip error: $e\n$st');
      return false;
    }
  }

  /// حذف الرحلة
  Future<bool> deleteTrip(String tripId) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).delete();
      return true;
    } catch (e, st) {
      debugPrint('TripService.deleteTrip error: $e\n$st');
      return false;
    }
  }

  /// جلب بيانات رحلة واحدة بواسطة المعرف
  Future<Trip?> getTripById(String tripId) async {
    try {
      final doc = await _firestore.collection(_tripsCollection).doc(tripId).get();
      return doc.exists ? Trip.fromDocument(doc) : null;
    } catch (e, st) {
      debugPrint('TripService.getTripById error: $e\n$st');
      return null;
    }
  }

  /// جلب الرحلات المتاحة للركاب (نشطة + مقاعد شاغرة)
  Future<List<Trip>> getAvailableTrips() async {
    try {
      final snapshot = await _firestore
          .collection(_tripsCollection)
          .where('status', isEqualTo: 'active')
          .where('availableSeats', isGreaterThan: 0)
          .get();

      final list = snapshot.docs.map((doc) => Trip.fromDocument(doc)).toList();

      list.sort((a, b) {
        if (a.departureTime == null) return 1;
        if (b.departureTime == null) return -1;
        return a.departureTime!.compareTo(b.departureTime!);
      });

      return list;
    } catch (e, st) {
      debugPrint('TripService.getAvailableTrips error: $e\n$st');
      return [];
    }
  }

  /// جلب رحلات سائق معين
  Future<List<Trip>> getDriverTrips(String driverId) async {
    try {
      final snapshot = await _firestore
          .collection(_tripsCollection)
          .where('driverId', isEqualTo: driverId)
          .get();

      final list = snapshot.docs.map((doc) => Trip.fromDocument(doc)).toList();

      // ترتيب من الأحدث إلى الأقدم بناءً على تاريخ الإنشاء
      list.sort((a, b) {
        final dateA = a.createdAt?.toDate() ?? DateTime.now();
        final dateB = b.createdAt?.toDate() ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      debugPrint("TripService: Fetched ${list.length} trips for driver $driverId");
      return list;
    } catch (e, st) {
      debugPrint("TripService.getDriverTrips error: $e\n$st");
      return [];
    }
  }

  /// تحديث حالة المقاعد (يُستدعى عند الحجز)
  Future<bool> updateSeatStatus(String tripId, List<bool> seatStatus, int availableSeats) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({
        'seatStatus': seatStatus,
        'availableSeats': availableSeats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e, st) {
      debugPrint('TripService.updateSeatStatus error: $e\n$st');
      return false;
    }
  }

  /// تغيير حالة الرحلة (active, cancelled, completed)
  Future<void> changeTripStatus(String tripId, String newStatus) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('TripService.changeTripStatus error: $e\n$st');
    }
  }

  /// إرسال إشعار للمستخدم بخصوص الرحلة
  Future<void> notifyUserAboutTrip(String userId, String title, String body, String type) async {
    try {
      await NotificationService().sendNotification(
        userId: userId,
        title: title,
        body: body,
        type: type,
      );
    } catch (e, st) {
      debugPrint('TripService.notifyUserAboutTrip error: $e\n$st');
    }
  }

  // ============================
  // وظائف مساعدة متعلقة برسوم الفرزة
  // ============================

  /// احسب قيمة govFee لرحلة محددة وأعدها (لا يحدث تحديث في Firestore)
  Future<double> calculateGovFeeForTrip(String tripId) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) return 0.0;
      final origin = trip.origin;
      final destination = trip.destination;
      final distanceKm = trip.distanceKm;
      final fee = await _govFeesService.calculateGovFee(origin: origin, destination: destination, distanceKm: distanceKm);
      return fee;
    } catch (e) {
      debugPrint('TripService.calculateGovFeeForTrip error: $e');
      return 0.0;
    }
  }

  /// إعادة حساب وتعيين govFeeAmount لرحلة (يدعو GovFeesService.computeAndSetGovFeeForTrip)
  Future<bool> recomputeAndSetGovFeeForTrip(String tripId) async {
    try {
      return await _govFeesService.computeAndSetGovFeeForTrip(tripId);
    } catch (e) {
      debugPrint('TripService.recomputeAndSetGovFeeForTrip error: $e');
      return false;
    }
  }

  /// إعادة حساب رسوم الفرزة لجميع الرحلات النشطة (مرّر limit إن رغبت)
  Future<int> recomputeGovFeesForAllActiveTrips({int limit = 500}) async {
    try {
      return await _govFeesService.recomputeGovFeesForAllTrips(limit: limit);
    } catch (e) {
      debugPrint('TripService.recomputeGovFeesForAllActiveTrips error: $e');
      return 0;
    }
  }
}
