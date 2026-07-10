// lib/services/vehicle_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../models/vehicle.dart';

class VehicleService {
  final CollectionReference _vehiclesRef = FirebaseFirestore.instance.collection('vehicles');

  VehicleService();

  /// جلب مركبات السائق/المالك بناءً على الحقول الجديدة:
  /// يبحث أولاً في حقل vehicleOwner ثم في حقل ownerId كاحتياط
  Future<List<Vehicle>> getDriverVehicles(String driverId) async {
    try {
      // محاولة البحث باستخدام الحقل الموحد vehicleOwner
      final q1 = await _vehiclesRef.where('vehicleOwner', isEqualTo: driverId).get();
      if (q1.docs.isNotEmpty) {
        return q1.docs.map((d) => Vehicle.fromDocument(d)).toList();
      }

      // احتياطي: بعض المستندات القديمة قد تستخدم ownerId أو owner
      final q2 = await _vehiclesRef.where('ownerId', isEqualTo: driverId).get();
      if (q2.docs.isNotEmpty) {
        return q2.docs.map((d) => Vehicle.fromDocument(d)).toList();
      }

      // احتياطي آخر: قد يكون هناك حقل driverId مرتبط بالمركبة
      final q3 = await _vehiclesRef.where('driverId', isEqualTo: driverId).get();
      return q3.docs.map((d) => Vehicle.fromDocument(d)).toList();
    } catch (e) {
      debugPrint('VehicleService.getDriverVehicles error: $e');
      rethrow;
    }
  }

  /// جلب مركبة بواسطة المعرف
  Future<Vehicle?> getVehicleById(String id) async {
    try {
      final doc = await _vehiclesRef.doc(id).get();
      if (!doc.exists) return null;
      return Vehicle.fromDocument(doc);
    } catch (e) {
      debugPrint('VehicleService.getVehicleById error: $e');
      rethrow;
    }
  }

  /// إنشاء مركبة جديدة. يعيد معرف المستند عند النجاح.
  Future<String?> createVehicle(Vehicle vehicle) async {
    try {
      final data = vehicle.toMap();
      // تأكد من استخدام الحقول الموحدة في المستند
      final payload = {
        ...data,
        'plateNumber': data['plateNumber'] ?? '',
        'vehicleOwner': data['vehicleOwner'] ?? '',
        'vehicleType': data['vehicleType'] ?? '',
        'makeModelYear': data['makeModelYear'] ?? '',
        'color': data['color'] ?? '',
        'maxCapacity': data['maxCapacity'] ?? 0,
        'licenseNumber': data['licenseNumber'] ?? '',
        'isVerified': data['isVerified'] ?? false,
        'notes': data['notes'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _vehiclesRef.add(payload);
      return docRef.id;
    } catch (e) {
      debugPrint('VehicleService.createVehicle error: $e');
      rethrow;
    }
  }

  /// تحديث بيانات مركبة موجودة
  Future<bool> updateVehicle(String id, Vehicle vehicle) async {
    try {
      final data = vehicle.toMap();
      final payload = {
        ...data,
        // لا نغيّر createdAt عند التحديث، نضيف updatedAt فقط
        'updatedAt': FieldValue.serverTimestamp(),
      }..removeWhere((k, v) => v == null);

      await _vehiclesRef.doc(id).update(payload);
      return true;
    } catch (e) {
      debugPrint('VehicleService.updateVehicle error: $e');
      return false;
    }
  }

  /// حذف مركبة
  Future<bool> deleteVehicle(String id) async {
    try {
      await _vehiclesRef.doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('VehicleService.deleteVehicle error: $e');
      return false;
    }
  }
}
