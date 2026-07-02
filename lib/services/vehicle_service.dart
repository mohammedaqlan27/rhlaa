// lib/services/vehicle_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle.dart';

class VehicleService {
  final CollectionReference _vehiclesRef = FirebaseFirestore.instance.collection('vehicles');

  Future<List<Vehicle>> getDriverVehicles(String driverId) async {
    try {
      final q1 = await _vehiclesRef.where('ownerUserId', isEqualTo: driverId).get();
      if (q1.docs.isNotEmpty) {
        return q1.docs.map((d) => Vehicle.fromDocument(d)).toList();
      }
      final q2 = await _vehiclesRef.where('driverId', isEqualTo: driverId).get();
      return q2.docs.map((d) => Vehicle.fromDocument(d)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Vehicle?> getVehicleById(String id) async {
    try {
      final doc = await _vehiclesRef.doc(id).get();
      if (!doc.exists) return null;
      return Vehicle.fromDocument(doc);
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> createVehicle(Vehicle vehicle) async {
    try {
      final data = vehicle.toMap();
      final docRef = await _vehiclesRef.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updateVehicle(String id, Vehicle vehicle) async {
    try {
      final data = vehicle.toMap();
      await _vehiclesRef.doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteVehicle(String id) async {
    try {
      await _vehiclesRef.doc(id).delete();
      return true;
    } catch (e) {
      return false;
    }
  }
}
