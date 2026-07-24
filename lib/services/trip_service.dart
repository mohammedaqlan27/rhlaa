// lib/services/trip_service.dart
//
// خدمة إدارة الرحلات (TripService) مع تكامل لحساب رسوم الفرزة الحكومية (govFee).
// - عند إنشاء رحلة جديدة: تحفظ الرحلة ثم تحسب govFee تلقائياً عبر GovFeesService.
// - عند تحديث رحلة: إذا تغيّر origin أو destination أو distanceKm، تعيد حساب govFee.
// - توفر دوال مساعدة لجلب الرحلات، تحديث المقاعد، حذف الرحلات، وإشعارات المستخدمين.

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

  final GovFeesService _govFeesService;
  final NotificationService _notificationService;

  TripService({
    FirebaseFirestore? firestore,
    GovFeesService? govFeesService,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _govFeesService = govFeesService ?? GovFeesService(),
        _notificationService = notificationService ?? NotificationService();

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

  /// إنشاء رحلة جديدة مع حساب الرسوم الحكومية تلقائياً
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

      // جلب اسم السائق من مستند المستخدم لضمان الدقة
      String driverName = trip.driverName;
      try {
        final userDoc = await _firestore.collection(_usersCollection).doc(trip.driverId).get();
        if (userDoc.exists) {
          final user = AppUser.fromDocument(userDoc);
          if (user.nickname.isNotEmpty) driverName = user.nickname;
        }
      } catch (_) {}

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
      await _govFeesService.computeAndSetGovFeeForTrip(finalId);

      return finalId;
    } catch (e, st) {
      debugPrint('TripService.createTrip error: $e\n$st');
      return null;
    }
  }

  /// تحديث بيانات الرحلة وإعادة حساب الرسوم إذا تغير المسار
  Future<bool> updateTrip(String tripId, Trip updatedTrip) async {
    try {
      final tripRef = _firestore.collection(_tripsCollection).doc(tripId);
      final existingSnap = await tripRef.get();
      if (!existingSnap.exists) return false;

      final existingTrip = Trip.fromDocument(existingSnap);
      final data = updatedTrip.toMap();
      data.remove('createdAt'); // منع تغيير تاريخ الإنشاء

      await tripRef.update(data);

      // التحقق من تغير المسار لإعادة حساب الرسوم
      final routeChanged = (existingTrip.origin != updatedTrip.origin) ||
          (existingTrip.destination != updatedTrip.destination) ||
          ((existingTrip.distanceKm ?? 0.0) != (updatedTrip.distanceKm ?? 0.0));

      if (routeChanged) {
        await _govFeesService.computeAndSetGovFeeForTrip(tripId);
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
    } catch (e) {
      return false;
    }
  }

  /// جلب بيانات رحلة واحدة
  Future<Trip?> getTripById(String tripId) async {
    try {
      final doc = await _firestore.collection(_tripsCollection).doc(tripId).get();
      return doc.exists ? Trip.fromDocument(doc) : null;
    } catch (e) {
      return null;
    }
  }

  /// جلب الرحلات المتاحة للركاب
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
    } catch (e) {
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
      list.sort((a, b) => (b.createdAt ?? Timestamp.now()).compareTo(a.createdAt ?? Timestamp.now()));
      return list;
    } catch (e) {
      return [];
    }
  }

  /// تحديث حالة المقاعد عند الحجز
  Future<bool> updateSeatStatus(String tripId, List<bool> seatStatus, int availableSeats) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({
        'seatStatus': seatStatus,
        'availableSeats': availableSeats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// تغيير حالة الرحلة
  Future<void> changeTripStatus(String tripId, String newStatus) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }

  /// إرسال إشعار للمستخدم
  Future<void> notifyUserAboutTrip(String userId, String title, String body, String type) async {
    try {
      await _notificationService.sendNotification(
        userId: userId,
        title: title,
        body: body,
        type: type,
      );
    } catch (e) {}
  }

  // ============================
  // وظائف متعلقة برسوم الفرزة
  // ============================

  /// إعادة حساب وتعيين رسوم الفرزة لرحلة محددة
  Future<bool> recomputeAndSetGovFeeForTrip(String tripId) async {
    return await _govFeesService.computeAndSetGovFeeForTrip(tripId);
  }

  /// إعادة حساب رسوم الفرزة لجميع الرحلات النشطة
  Future<int> recomputeGovFeesForAllActiveTrips({int limit = 500}) async {
    // ملاحظة: تم التأكد من مطابقة اسم الدالة مع GovFeesService المحدثة
    return await _govFeesService.recomputeGovFeesForAllActiveTrips(limit: limit);
  }
}