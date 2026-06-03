// lib/services/trip_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/trip.dart';
import '../models/app_user.dart';
import '../models/vehicle.dart';
import '../services/notification_service.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final String _tripsCollection = 'trips';
  final String _usersCollection = 'users';
  final String _vehiclesCollection = 'vehicles';
  final String _ratingsCollection = 'ratings';

  /// التحقق من صلاحية السائق
  Future<bool> isDriverVerified(String driverId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(driverId).get();
      if (!doc.exists) return false;
      final user = AppUser.fromDocument(doc);
      final type = (user.userType ?? '').toString().toLowerCase();
      final verified = user.isIdVerified == true;
      return (type == 'driver' || type == 'سائق') && verified;
    } catch (e, st) {
      debugPrint('TripService.isDriverVerified error: $e\n$st');
      return false;
    }
  }

  /// التحقق من صلاحية المركبة
  Future<Vehicle?> getVerifiedVehicle(String? vehicleId) async {
    if (vehicleId == null || vehicleId.isEmpty) return null;
    try {
      final doc = await _firestore.collection(_vehiclesCollection).doc(vehicleId).get();
      if (!doc.exists) return null;
      final vehicle = Vehicle.fromDocument(doc);
      return vehicle.isVerified == true ? vehicle : null;
    } catch (e, st) {
      debugPrint('TripService.getVerifiedVehicle error: $e\n$st');
      return null;
    }
  }

  /// إنشاء رحلة جديدة
  /// يعيد معرف الرحلة عند النجاح أو null عند الفشل
  Future<String?> createTrip(Trip trip) async {
    try {
      // تحقق من السائق
      final isDriverOk = await isDriverVerified(trip.driverId);
      if (!isDriverOk) {
        debugPrint('TripService.createTrip: driver not verified ${trip.driverId}');
        return null;
      }

      // تحقق من المركبة (vehicleId قد تكون null) — إذا كانت مطلوبة حسب منطقك، تأكد من ذلك
      Vehicle? vehicle;
      if (trip.vehicleId != null && trip.vehicleId!.isNotEmpty) {
        vehicle = await getVerifiedVehicle(trip.vehicleId);
        if (vehicle == null) {
          debugPrint('TripService.createTrip: vehicle not verified or missing ${trip.vehicleId}');
          return null;
        }
      }

      // تأكد من وجود معرف نهائي للرحلة
      final String finalId = (trip.id ?? '').isEmpty ? _uuid.v4() : trip.id!;

      // حدد سعة المقاعد النهائية: إذا وُجدت مركبة معتمدة استخدم سعتها، وإلا استخدم totalSeats من الكائن trip إن كان > 0
      final int seats = vehicle?.maxCapacity ?? (trip.totalSeats > 0 ? trip.totalSeats : 0);
      if (seats <= 0) {
        debugPrint('TripService.createTrip: invalid seats count (no vehicle and trip.totalSeats not provided) for driver ${trip.driverId}');
        return null;
      }

      // افتراض أن الحالة الافتراضية للمقاعد هي true (متاحة) عند الإنشاء
      final seatStatusList = List<bool>.filled(seats, true);

      final finalTrip = trip.copyWith(
        id: finalId,
        totalSeats: seats,
        availableSeats: seats,
        seatStatus: seatStatusList,
        createdAt: trip.createdAt ?? Timestamp.now(),
      );

      // سجل الرحلة في Firestore
      await _firestore.collection(_tripsCollection).doc(finalId).set(finalTrip.toMap());
      debugPrint('TripService.createTrip: trip created with id $finalId');

      return finalId;
    } catch (e, st) {
      debugPrint('TripService.createTrip error: $e\n$st');
      return null;
    }
  }

  /// تعديل رحلة
  Future<bool> updateTrip(String tripId, Trip updatedTrip) async {
    try {
      final data = Map<String, dynamic>.from(updatedTrip.toMap());
      data.remove('createdAt'); // لا نسمح بتعديل createdAt عبر هذه الدالة
      await _firestore.collection(_tripsCollection).doc(tripId).update(data);
      return true;
    } catch (e, st) {
      debugPrint('TripService.updateTrip error: $e\n$st');
      return false;
    }
  }

  /// حذف رحلة
  Future<bool> deleteTrip(String tripId) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).delete();
      return true;
    } catch (e, st) {
      debugPrint('TripService.deleteTrip error: $e\n$st');
      return false;
    }
  }

  /// جلب رحلة واحدة
  Future<Trip?> getTripById(String tripId) async {
    try {
      final doc = await _firestore.collection(_tripsCollection).doc(tripId).get();
      return doc.exists ? Trip.fromDocument(doc) : null;
    } catch (e, st) {
      debugPrint('TripService.getTripById error: $e\n$st');
      return null;
    }
  }

  /// جلب الرحلات المتاحة
  Future<List<Trip>> getAvailableTrips() async {
    try {
      final snapshot = await _firestore
          .collection(_tripsCollection)
          .where('status', whereIn: ['active', 'مفعّلة'])
          .where('availableSeats', isGreaterThan: 0)
          .orderBy('availableSeats', descending: true)
          .orderBy('departureTime')
          .get();

      return snapshot.docs.map((doc) => Trip.fromDocument(doc)).toList();
    } catch (e, st) {
      debugPrint('TripService.getAvailableTrips error: $e\n$st');
      return [];
    }
  }

  /// جلب رحلات السائق
  Future<List<Trip>> getTripsByDriver(String driverId) async {
    try {
      final snapshot = await _firestore
          .collection(_tripsCollection)
          .where('driverId', isEqualTo: driverId)
          .orderBy('departureTime')
          .get();

      return snapshot.docs.map((doc) => Trip.fromDocument(doc)).toList();
    } catch (e, st) {
      debugPrint('TripService.getTripsByDriver error: $e\n$st');
      return [];
    }
  }

  /// تحديث المقاعد
  Future<bool> updateSeatStatus(String tripId, List<bool> seatStatus, int availableSeats) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({
        'seatStatus': seatStatus,
        'availableSeats': availableSeats,
      });
      return true;
    } catch (e, st) {
      debugPrint('TripService.updateSeatStatus error: $e\n$st');
      return false;
    }
  }

  /// تحديث تقييم السائق
  /// يحسب المتوسط من الحقول الممكنة في مجموعة ratings (rating أو score)
  Future<void> updateDriverRating(String driverId) async {
    try {
      final snapshot = await _firestore.collection(_ratingsCollection).get();

      final List<double> values = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final toUser = (data['toUserId'] ?? data['to_user_id'] ?? data['driverId'] ?? data['driver_id'])?.toString();
        if (toUser == driverId) {
          double? val;
          if (data['rating'] != null) {
            final r = data['rating'];
            if (r is num) val = r.toDouble();
            else if (r is String) val = double.tryParse(r);
          } else if (data['score'] != null) {
            final s = data['score'];
            if (s is num) val = s.toDouble();
            else if (s is String) val = double.tryParse(s);
          }
          if (val != null) values.add(val);
        }
      }

      final average = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
      final ratingCount = values.length;

      await _firestore.collection(_usersCollection).doc(driverId).update({
        'averageRating': average,
        'average_rating': average,
        'ratingCount': ratingCount,
        'rating_count': ratingCount,
      });
    } catch (e, st) {
      debugPrint('TripService.updateDriverRating error: $e\n$st');
    }
  }

  /// تغيير حالة الرحلة
  Future<void> changeTripStatus(String tripId, String newStatus) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({'status': newStatus});
    } catch (e, st) {
      debugPrint('TripService.changeTripStatus error: $e\n$st');
    }
  }

  /// إرسال إشعار (موحّد التوقيع)
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
}
