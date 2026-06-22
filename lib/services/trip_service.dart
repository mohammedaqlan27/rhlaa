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

  Future<bool> isDriverVerified(String driverId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(driverId).get();
      if (!doc.exists) return false;
      final user = AppUser.fromDocument(doc);
      final type = (user.userType ?? '').toString().toLowerCase();
      final verified = user.isIdVerified == true;
      return (type == 'driver' || type == 'سائق') && verified;
    } catch (e) {
      return false;
    }
  }

  Future<Vehicle?> getVerifiedVehicle(String? vehicleId) async {
    if (vehicleId == null || vehicleId.isEmpty) return null;
    try {
      final doc = await _firestore.collection(_vehiclesCollection).doc(vehicleId).get();
      if (!doc.exists) return null;
      final vehicle = Vehicle.fromDocument(doc);
      return vehicle.isVerified == true ? vehicle : null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> createTrip(Trip trip) async {
    try {
      final isDriverOk = await isDriverVerified(trip.driverId);
      if (!isDriverOk) return null;

      Vehicle? vehicle;
      if (trip.vehicleId != null && trip.vehicleId!.isNotEmpty) {
        vehicle = await getVerifiedVehicle(trip.vehicleId);
        if (vehicle == null) return null;
      }

      // بما أن id في الموديل الجديد أصبح String دائم غير قابل للـ null
      final String finalId = trip.id.isEmpty ? _uuid.v4() : trip.id;

      final int seats = vehicle?.maxCapacity ?? (trip.totalSeats > 0 ? trip.totalSeats : 0);
      if (seats <= 0) return null;

      final seatStatusList = List<bool>.filled(seats, true);

      final finalTrip = trip.copyWith(
        id: finalId,
        totalSeats: seats,
        availableSeats: seats,
        seatStatus: seatStatusList,
        createdAt: trip.createdAt ?? Timestamp.now(),
      );

      await _firestore.collection(_tripsCollection).doc(finalId).set(finalTrip.toMap());
      return finalId;
    } catch (e, st) {
      debugPrint('TripService.createTrip error: $e\n$st');
      return null;
    }
  }

  Future<bool> updateTrip(String tripId, Trip updatedTrip) async {
    try {
      final data = Map<String, dynamic>.from(updatedTrip.toMap());
      data.remove('createdAt');
      await _firestore.collection(_tripsCollection).doc(tripId).update(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTrip(String tripId) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Trip?> getTripById(String tripId) async {
    try {
      final doc = await _firestore.collection(_tripsCollection).doc(tripId).get();
      return doc.exists ? Trip.fromDocument(doc) : null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Trip>> getAvailableTrips() async {
    try {
      final snapshot = await _firestore
          .collection(_tripsCollection)
          .where('status', whereIn: ['active', 'مفعّلة'])
          .where('availableSeats', isGreaterThan: 0)
          .get();

      // الترتيب محلياً لتجنب مشاكل عدم بناء الفهارس (Indexes) المركبة في Firestore لكل الحقول
      final list = snapshot.docs.map((doc) => Trip.fromDocument(doc)).toList();
      list.sort((a, b) {
        final timeA = a.departureTime ?? DateTime.now();
        final timeB = b.departureTime ?? DateTime.now();
        return timeA.compareTo(timeB);
      });
      return list;
    } catch (e, st) {
      debugPrint('TripService.getAvailableTrips error: $e\n$st');
      return [];
    }
  }

  Future<List<Trip>> getTripsByDriver(String driverId) async {
    try {
      final snapshot = await _firestore
          .collection(_tripsCollection)
          .where('driverId', isEqualTo: driverId)
          .get();

      final list = snapshot.docs.map((doc) => Trip.fromDocument(doc)).toList();
      list.sort((a, b) {
        final timeA = a.departureTime ?? DateTime.now();
        final timeB = b.departureTime ?? DateTime.now();
        return timeA.compareTo(timeB);
      });
      return list;
    } catch (e) {
      return [];
    }
  }

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

  Future<void> updateDriverRating(String driverId) async {
    try {
      final snapshot = await _firestore.collection(_ratingsCollection).get();
      final List<double> values = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final toUser = (data['toUserId'] ?? data['to_user_id'] ?? data['driverId'] ?? data['driver_id'])?.toString();
        if (toUser == driverId) {
          final r = data['rating'] ?? data['score'];
          if (r is num) values.add(r.toDouble());
        }
      }

      final average = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;

      await _firestore.collection(_usersCollection).doc(driverId).update({
        'averageRating': average,
        'ratingCount': values.length,
      });
    } catch (_) {}
  }

  Future<void> changeTripStatus(String tripId, String newStatus) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).update({'status': newStatus});
    } catch (_) {}
  }

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