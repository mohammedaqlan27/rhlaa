// lib/services/trip_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/trip.dart';
import '../models/app_user.dart';
import '../services/notification_service.dart';
import '../services/govfees_service.dart';

/// TripService محسّن: يدعم CRUD، streams، pagination، transactions، وإعادة حساب رسوم الفرزة.
class TripService {
  final FirebaseFirestore _firestore;
  final GovFeesService _govFeesService;
  final NotificationService _notificationService;
  final Uuid _uuid = const Uuid();

  final String _tripsCollection = 'trips';
  final String _usersCollection = 'users';

  TripService({
    FirebaseFirestore? firestore,
    GovFeesService? govFeesService,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _govFeesService = govFeesService ?? GovFeesService(),
        _notificationService = notificationService ?? NotificationService();

  // -----------------------
  // Helpers
  // -----------------------
  Future<T> _withRetry<T>(Future<T> Function() fn, {int retries = 2, Duration delay = const Duration(milliseconds: 200)}) async {
    var attempt = 0;
    var wait = delay;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        if (attempt > retries) rethrow;
        if (kDebugMode) debugPrint('TripService retry #$attempt after error: $e');
        await Future.delayed(wait);
        wait *= 2;
      }
    }
  }

  // -----------------------
  // Streams / Queries
  // -----------------------

  /// بث الرحلات المتاحة (status == active && availableSeats > 0)
  Stream<List<Trip>> streamAvailableTrips({int limit = 100}) {
    final q = _firestore
        .collection(_tripsCollection)
        .where('status', isEqualTo: 'active')
        .where('availableSeats', isGreaterThan: 0)
        .orderBy('departureTime', descending: false)
        .limit(limit);
    return q.snapshots().map((snap) => snap.docs.map((d) => Trip.fromDocument(d)).toList());
  }

  /// بث رحلات سائق معين
  Stream<List<Trip>> streamDriverTrips(String driverId) {
    if (driverId.trim().isEmpty) return const Stream.empty();
    final q = _firestore.collection(_tripsCollection).where('driverId', isEqualTo: driverId).orderBy('createdAt', descending: true);
    return q.snapshots().map((snap) => snap.docs.map((d) => Trip.fromDocument(d)).toList());
  }

  /// جلب الرحلات المتاحة لمرة واحدة (غير متزامن)
  Future<List<Trip>> getAvailableTrips({int limit = 500}) async {
    return _withRetry(() async {
      final snap = await _firestore
          .collection(_tripsCollection)
          .where('status', isEqualTo: 'active')
          .where('availableSeats', isGreaterThan: 0)
          .orderBy('departureTime', descending: false)
          .limit(limit)
          .get();
      final list = snap.docs.map((d) => Trip.fromDocument(d)).toList();
      list.sort((a, b) {
        if (a.departureTime == null) return 1;
        if (b.departureTime == null) return -1;
        return a.departureTime!.compareTo(b.departureTime!);
      });
      return list;
    });
  }

  /// جلب رحلات سائق
  Future<List<Trip>> getDriverTrips(String driverId, {int limit = 500}) async {
    if (driverId.trim().isEmpty) return [];
    return _withRetry(() async {
      final snap = await _firestore.collection(_tripsCollection).where('driverId', isEqualTo: driverId).orderBy('createdAt', descending: true).limit(limit).get();
      return snap.docs.map((d) => Trip.fromDocument(d)).toList();
    });
  }

  /// جلب رحلة واحدة
  Future<Trip?> getTripById(String tripId) async {
    if (tripId.trim().isEmpty) return null;
    try {
      final doc = await _firestore.collection(_tripsCollection).doc(tripId).get();
      return doc.exists ? Trip.fromDocument(doc) : null;
    } catch (e) {
      if (kDebugMode) debugPrint('TripService.getTripById error: $e');
      return null;
    }
  }

  // -----------------------
  // CRUD
  // -----------------------

  /// إنشاء رحلة مع تهيئة المقاعد وحساب govFee لاحقاً
  Future<String?> createTrip(Trip trip) async {
    return _withRetry(() async {
      if (trip.driverId.trim().isEmpty) {
        if (kDebugMode) debugPrint('TripService.createTrip: driverId empty');
        return null;
      }

      // تحقق من توثيق السائق
      final isDriverOk = await isDriverVerified(trip.driverId);
      if (!isDriverOk) {
        if (kDebugMode) debugPrint('TripService.createTrip: driver not verified');
        return null;
      }

      final id = trip.id.isEmpty ? _uuid.v4() : trip.id;
      final seats = trip.totalSeats > 0 ? trip.totalSeats : 0;
      final seatStatus = List<bool>.filled(seats, true);

      final finalTrip = trip.copyWith(
        id: id,
        availableSeats: seats,
        seatStatus: seatStatus,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      await _firestore.collection(_tripsCollection).doc(id).set(finalTrip.toMap());

      // حساب رسوم الفرزة في الخلفية (لا نمنع الإرجاع)
      unawaited(_govFeesService.computeAndSetGovFeeForTrip(id));

      return id;
    });
  }

  /// تحديث رحلة (يعيد true عند النجاح)
  Future<bool> updateTrip(String tripId, Trip updatedTrip) async {
    if (tripId.trim().isEmpty) return false;
    return _withRetry(() async {
      final ref = _firestore.collection(_tripsCollection).doc(tripId);
      final snap = await ref.get();
      if (!snap.exists) return false;
      final existing = Trip.fromDocument(snap);

      final data = updatedTrip.toMap();
      data.remove('createdAt');

      await ref.update(data);

      final routeChanged = (existing.origin != updatedTrip.origin) ||
          (existing.destination != updatedTrip.destination) ||
          ((existing.distanceKm ?? 0.0) != (updatedTrip.distanceKm ?? 0.0));

      if (routeChanged) {
        unawaited(_govFeesService.computeAndSetGovFeeForTrip(tripId));
      }
      return true;
    });
  }

  /// حذف رحلة
  Future<bool> deleteTrip(String tripId) async {
    if (tripId.trim().isEmpty) return false;
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).delete();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('TripService.deleteTrip error: $e');
      return false;
    }
  }

  // -----------------------
  // Seats / status
  // -----------------------

  Future<bool> updateSeatStatus(String tripId, List<bool> seatStatus, int availableSeats) async {
    if (tripId.trim().isEmpty) return false;
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({
        'seatStatus': seatStatus,
        'availableSeats': availableSeats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('TripService.updateSeatStatus error: $e');
      return false;
    }
  }

  Future<void> changeTripStatus(String tripId, String newStatus) async {
    if (tripId.trim().isEmpty) return;
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('TripService.changeTripStatus error: $e');
    }
  }

  // -----------------------
  // Gov fees helpers
  // -----------------------

  Future<bool> recomputeAndSetGovFeeForTrip(String tripId) async {
    return _govFeesService.computeAndSetGovFeeForTrip(tripId);
  }

  Future<int> recomputeGovFeesForAllActiveTrips({int limit = 500}) async {
    return _govFeesService.recomputeGovFeesForAllActiveTrips(limit: limit);
  }

  // -----------------------
  // Utilities
  // -----------------------

  Future<bool> isDriverVerified(String driverId) async {
    try {
      if (driverId.trim().isEmpty) return false;
      final doc = await _firestore.collection(_usersCollection).doc(driverId).get();
      if (!doc.exists) return false;
      final user = AppUser.fromDocument(doc);
      return user.isDriver && user.isIdVerified;
    } catch (e) {
      if (kDebugMode) debugPrint('TripService.isDriverVerified error: $e');
      return false;
    }
  }

  Future<void> notifyUserAboutTrip(String userId, String title, String body, String type) async {
    try {
      await _notificationService.sendNotification(userId: userId, title: title, body: body, type: type);
    } catch (e) {
      if (kDebugMode) debugPrint('TripService.notifyUserAboutTrip error: $e');
    }
  }
}
