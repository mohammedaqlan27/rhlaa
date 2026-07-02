import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/trip.dart';
import '../models/app_user.dart';
import '../services/notification_service.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final String _tripsCollection = 'trips';
  final String _usersCollection = 'users';
  final String _ratingsCollection = 'ratings';

  /// التحقق من أن المستخدم سائق وموثق (Verified)
  Future<bool> isDriverVerified(String driverId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(driverId).get();
      if (!doc.exists) return false;

      final user = AppUser.fromDocument(doc);
      return user.isDriver && user.isIdVerified;
    } catch (e) {
      return false;
    }
  }

  /// إنشاء رحلة جديدة
  Future<String?> createTrip(Trip trip) async {
    try {
      final isDriverOk = await isDriverVerified(trip.driverId);
      if (!isDriverOk) {
        debugPrint('TripService: Driver is not verified or not a driver.');
        return null;
      }

      final String finalId = trip.id.isEmpty ? _uuid.v4() : trip.id;
      int seats = trip.totalSeats;
      List<bool> initialSeatStatus = List<bool>.filled(seats, true);

      final finalTrip = trip.copyWith(
        id: finalId,
        availableSeats: seats,
        seatStatus: initialSeatStatus,
        createdAt: Timestamp.now(),
      );

      await _firestore.collection(_tripsCollection).doc(finalId).set(finalTrip.toMap());
      return finalId;
    } catch (e, st) {
      debugPrint('TripService.createTrip error: $e\n$st');
      return null;
    }
  }

  /// تحديث بيانات الرحلة
  Future<bool> updateTrip(String tripId, Trip updatedTrip) async {
    try {
      final data = updatedTrip.toMap();
      data.remove('createdAt');
      await _firestore.collection(_tripsCollection).doc(tripId).update(data);
      return true;
    } catch (e) {
      debugPrint('TripService.updateTrip error: $e');
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

  /// جلب بيانات رحلة واحدة بواسطة المعرف
  Future<Trip?> getTripById(String tripId) async {
    try {
      final doc = await _firestore.collection(_tripsCollection).doc(tripId).get();
      return doc.exists ? Trip.fromDocument(doc) : null;
    } catch (e) {
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

  /// 🆕 الإضافة الجديدة: جلب رحلات سائق معين (المستخدمة في TripProvider)
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
    } catch (e) {
      debugPrint("TripService.getDriverTrips error: $e");
      return [];
    }
  }

  /// جلب رحلات سائق معين (اسم بديل للاحتياط)
  Future<List<Trip>> getTripsByDriver(String driverId) async {
    return getDriverTrips(driverId);
  }

  /// تحديث حالة المقاعد (يُستدعى عند الحجز)
  Future<bool> updateSeatStatus(String tripId, List<bool> seatStatus, int availableSeats) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({
        'seatStatus': seatStatus,
        'availableSeats': availableSeats,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// تغيير حالة الرحلة (active, cancelled, completed)
  Future<void> changeTripStatus(String tripId, String newStatus) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({'status': newStatus});
    } catch (e) {
      debugPrint('Error changing trip status: $e');
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
    } catch (_) {}
  }
}