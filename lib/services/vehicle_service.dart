// lib/services/vehicle_service.dart
import 'dart:async';

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/vehicle.dart';

/// VehicleService
/// خدمة متقدمة للتعامل مع مجموعة "vehicles" في Firestore
/// - دعم: getDriverVehicles, getVehicleById, createVehicle, updateVehicle, deleteVehicle
/// - تحسينات: pagination, caching (TTL), transactions, streams, search, retry
class VehicleService {
  final FirebaseFirestore _firestore;

  /// Simple in-memory cache: id -> (vehicle, expiry)
  final Map<String, _CacheEntry<Vehicle>> _cacheById = {};

  /// TTL for cache entries in seconds
  final int _cacheTtlSeconds;

  VehicleService({FirebaseFirestore? firestore, int cacheTtlSeconds = 60})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _cacheTtlSeconds = cacheTtlSeconds;

  CollectionReference get _vehiclesRef => _firestore.collection('vehicles');
  CollectionReference get _usersRef => _firestore.collection('users');

  // -------------------------
  // Helpers
  // -------------------------
  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String? _timestampToString(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is DateTime) return v.toIso8601String();
    if (v is String) return v;
    return v.toString();
  }

  Vehicle _vehicleFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    // vehicleDocuments expected as List<String>
    final vehicleDocsRaw = data['vehicleDocuments'];
    final List<String> vehicleDocs = [];
    if (vehicleDocsRaw is List) {
      for (final e in vehicleDocsRaw) {
        if (e == null) continue;
        vehicleDocs.add(e.toString());
      }
    }

    return Vehicle(
      id: doc.id,
      plateNumber: (data['plateNumber'] ?? data['plate_number'] ?? '') as String,
      vehicleOwner: (data['vehicleOwner'] ?? data['vehicle_owner'] ?? '') as String,
      ownerId: (data['ownerUserId'] ?? data['ownerId'] ?? data['owner_user_id']) as String?,
      driverId: (data['driverId'] ?? data['driver_id']) as String?,
      driverName: (data['driverName'] ?? data['driver_name'] ?? '') as String?,
      vehicleType: (data['vehicleType'] ?? data['vehicle_type'] ?? '') as String,
      makeModelYear: (data['makeModelYear'] ?? data['make_model_year'] ?? '') as String,
      color: (data['color'] ?? '') as String,
      maxCapacity: _toInt(data['maxCapacity'] ?? data['max_capacity'] ?? 0),
      licenseNumber: (data['licenseNumber'] ?? data['license_number'] ?? '') as String,
      isVerified: (data['isVerified'] ?? data['is_verified'] ?? false) as bool,
      sGovernmentRegistered: (data['sGovernmentRegistered'] ?? data['s_government_registered'] ?? false) as bool,
      notes: data['notes'] as String?,
      extra: data['extra'],
      vehicleDocuments: vehicleDocs,
      insuranceExpiryDate: data['insuranceExpiryDate'] is Timestamp ? data['insuranceExpiryDate'] as Timestamp : null,
      // lastInspectionDate in your schema is a string; convert Timestamp -> ISO string
      lastInspectionDate: _timestampToString(data['lastInspectionDate']),
      carOwnerOfficialName: (data['carOwnerOfficialName'] ?? data['car_owner_official_name'] ?? '') as String?,
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null,
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] as Timestamp : null,
    );
  }

  Map<String, dynamic> _vehicleToMap(Vehicle v, {bool forUpdate = false}) {
    final map = <String, dynamic>{
      'plateNumber': v.plateNumber,
      'vehicleOwner': v.vehicleOwner,
      'ownerUserId': v.ownerId,
      'driverId': v.driverId,
      'driverName': v.driverName,
      'vehicleType': v.vehicleType,
      'makeModelYear': v.makeModelYear,
      'color': v.color,
      'maxCapacity': v.maxCapacity,
      'licenseNumber': v.licenseNumber,
      'isVerified': v.isVerified,
      'sGovernmentRegistered': v.sGovernmentRegistered,
      'notes': v.notes,
      'extra': v.extra,
      'vehicleDocuments': v.vehicleDocuments,
      'insuranceExpiryDate': v.insuranceExpiryDate,
      // lastInspectionDate stored as string in your schema
      'lastInspectionDate': v.lastInspectionDate,
      'carOwnerOfficialName': v.carOwnerOfficialName,
    };

    if (!forUpdate) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    map['updatedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  Future<T> _withRetry<T>(Future<T> Function() fn, {int retries = 2, Duration initialDelay = const Duration(milliseconds: 200)}) async {
    var attempt = 0;
    var delay = initialDelay;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        if (attempt > retries) rethrow;
        if (kDebugMode) debugPrint('Retry attempt $attempt after error: $e');
        await Future.delayed(delay);
        delay *= 2;
      }
    }
  }

  void _cacheSet(String id, Vehicle v) {
    _cacheById[id] = _CacheEntry(v, DateTime.now().add(Duration(seconds: _cacheTtlSeconds)));
  }

  Vehicle? _cacheGet(String id) {
    final entry = _cacheById[id];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiry)) {
      _cacheById.remove(id);
      return null;
    }
    return entry.value;
  }

  // -------------------------
  // CRUD and queries
  // -------------------------

  /// جلب مركبة واحدة مع استخدام الكاش
  Future<Vehicle?> getVehicleById(String id, {bool useCache = true}) async {
    if (id.trim().isEmpty) return null;
    if (useCache) {
      final cached = _cacheGet(id);
      if (cached != null) {
        if (kDebugMode) debugPrint('VehicleService.getVehicleById cache hit $id');
        return cached;
      }
    }

    return _withRetry(() async {
      final doc = await _vehiclesRef.doc(id).get();
      if (!doc.exists) return null;
      final v = _vehicleFromDoc(doc);
      _cacheSet(id, v);
      return v;
    });
  }

  /// دالة مطابقة لنداء Provider القديم
  Future<List<Vehicle>?> getAllVehicles() async {
    try {
      final snap = await _vehiclesRef.get();
      final list = snap.docs.map((d) => _vehicleFromDoc(d)).toList();
      for (final v in list) {
        _cacheSet(v.id, v);
      }
      return list;
    } catch (e, st) {
      if (kDebugMode) debugPrint('VehicleService.getAllVehicles error: $e\n$st');
      rethrow;
    }
  }

  /// جلب مركبات مرتبطة بمعرف معين مع pagination و fallback لعدة حقول
  Future<List<Vehicle>> getDriverVehicles(String driverId, {int limit = 50, DocumentSnapshot? startAfter}) async {
    if (driverId.trim().isEmpty) return [];

    return _withRetry(() async {
      final Set<String> seen = {};
      final List<Vehicle> result = [];

      // Build queries with optional pagination
      final queries = <Query>[
        _vehiclesRef.where('driverId', isEqualTo: driverId).limit(limit),
        _vehiclesRef.where('ownerUserId', isEqualTo: driverId).limit(limit),
        _vehiclesRef.where('vehicleOwner', isEqualTo: driverId).limit(limit),
      ];

      if (startAfter != null) {
        for (var i = 0; i < queries.length; i++) {
          queries[i] = queries[i].startAfterDocument(startAfter);
        }
      }

      final snaps = await Future.wait(queries.map((q) => q.get()));
      for (final snap in snaps) {
        for (final doc in snap.docs) {
          if (!seen.contains(doc.id)) {
            seen.add(doc.id);
            final v = _vehicleFromDoc(doc);
            result.add(v);
            _cacheSet(doc.id, v);
          }
        }
      }

      return result;
    });
  }

  /// Pagination-friendly fetch for all vehicles
  Future<List<Vehicle>> getAllVehiclesPaged({int limit = 100, DocumentSnapshot? startAfter}) async {
    return _withRetry(() async {
      Query q = _vehiclesRef.orderBy('createdAt', descending: true).limit(limit);
      if (startAfter != null) q = q.startAfterDocument(startAfter);
      final snap = await q.get();
      final list = snap.docs.map((d) {
        final v = _vehicleFromDoc(d);
        _cacheSet(d.id, v);
        return v;
      }).toList();
      return list;
    });
  }

  /// بحث سريع حسب رقم اللوحة (يفترض وجود index على plateNumber)
  Future<List<Vehicle>> searchVehiclesByPlate(String plate, {int limit = 20}) async {
    if (plate.trim().isEmpty) return [];
    return _withRetry(() async {
      final snap = await _vehiclesRef.where('plateNumber', isEqualTo: plate.trim()).limit(limit).get();
      final list = snap.docs.map((d) {
        final v = _vehicleFromDoc(d);
        _cacheSet(d.id, v);
        return v;
      }).toList();
      return list;
    });
  }

  /// إنشاء مركبة فقط
  Future<String?> createVehicle(Vehicle vehicle) async {
    return _withRetry(() async {
      final payload = _vehicleToMap(vehicle, forUpdate: false);
      final docRef = await _vehiclesRef.add(payload);
      if (kDebugMode) debugPrint('VehicleService.createVehicle created: ${docRef.id}');
      final v = vehicle.copyWith(id: docRef.id);
      _cacheSet(docRef.id, v);
      return docRef.id;
    });
  }

  /// إنشاء مركبة وربطها بمستند المستخدم ownerId داخل transaction
  Future<String?> createVehicleWithOwnerUpdate(Vehicle vehicle, String ownerId, {String userVehicleField = 'vehicleIds'}) async {
    if (ownerId.trim().isEmpty) {
      throw ArgumentError('ownerId is required for createVehicleWithOwnerUpdate');
    }

    return _withRetry(() async {
      return _firestore.runTransaction<String?>((tx) async {
        final newDocRef = _vehiclesRef.doc();
        final payload = _vehicleToMap(vehicle, forUpdate: false);
        tx.set(newDocRef, payload);

        final userRef = _usersRef.doc(ownerId);
        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) {
          // create minimal user doc if not exists
          tx.set(userRef, {
            userVehicleField: FieldValue.arrayUnion([newDocRef.id]),
            'currentVehicleId': newDocRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          tx.update(userRef, {
            userVehicleField: FieldValue.arrayUnion([newDocRef.id]),
            'currentVehicleId': newDocRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        if (kDebugMode) debugPrint('VehicleService.createVehicleWithOwnerUpdate created: ${newDocRef.id} and updated user $ownerId');
        return newDocRef.id;
      });
    });
  }

  /// تحديث مركبة
  Future<bool> updateVehicle(String id, Vehicle vehicle) async {
    if (id.trim().isEmpty) return false;
    return _withRetry(() async {
      final payload = _vehicleToMap(vehicle, forUpdate: true)..removeWhere((k, v) => v == null);
      await _vehiclesRef.doc(id).set(payload, SetOptions(merge: true));
      if (kDebugMode) debugPrint('VehicleService.updateVehicle updated: $id');
      final updated = vehicle.copyWith(id: id);
      _cacheSet(id, updated);
      return true;
    });
  }

  /// حذف مركبة مع محاولة إزالة المرجع من مستند المستخدم داخل transaction
  Future<bool> deleteVehicle(String id, {String? ownerId, String userVehicleField = 'vehicleIds'}) async {
    if (id.trim().isEmpty) return false;
    return _withRetry(() async {
      if (ownerId == null || ownerId.trim().isEmpty) {
        // simple delete
        await _vehiclesRef.doc(id).delete();
        _cacheById.remove(id);
        if (kDebugMode) debugPrint('VehicleService.deleteVehicle deleted: $id (no owner update)');
        return true;
      }

      // transaction: delete vehicle and remove from user's array
      await _firestore.runTransaction((tx) async {
        final vRef = _vehiclesRef.doc(id);
        tx.delete(vRef);

        final userRef = _usersRef.doc(ownerId);
        final userSnap = await tx.get(userRef);
        if (userSnap.exists) {
          tx.update(userRef, {
            userVehicleField: FieldValue.arrayRemove([id]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _cacheById.remove(id);
      if (kDebugMode) debugPrint('VehicleService.deleteVehicle deleted: $id and removed from user $ownerId');
      return true;
    });
  }

  // -------------------------
  // Streams / Watchers
  // -------------------------

  /// Stream لمستند مركبة واحدة
  Stream<Vehicle?> watchVehicle(String id) {
    if (id.trim().isEmpty) return const Stream.empty();
    return _vehiclesRef.doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      final v = _vehicleFromDoc(snap);
      _cacheSet(id, v);
      return v;
    });
  }

  /// Stream لمركبات سائق/مالك
  Stream<List<Vehicle>> watchVehiclesForDriver(String driverId) {
    if (driverId.trim().isEmpty) return const Stream.empty();
    final s1 = _vehiclesRef.where('driverId', isEqualTo: driverId).snapshots();
    final s2 = _vehiclesRef.where('ownerUserId', isEqualTo: driverId).snapshots();
    final s3 = _vehiclesRef.where('vehicleOwner', isEqualTo: driverId).snapshots();

    return StreamZip([s1, s2, s3]).map((snaps) {
      final seen = <String>{};
      final list = <Vehicle>[];
      for (final snap in snaps) {
        for (final doc in snap.docs) {
          if (!seen.contains(doc.id)) {
            seen.add(doc.id);
            final v = _vehicleFromDoc(doc);
            _cacheSet(doc.id, v);
            list.add(v);
          }
        }
      }
      return list;
    });
  }

  // -------------------------
  // Utility
  // -------------------------

  /// Clear cache (useful in tests or when you want fresh reads)
  void clearCache() {
    _cacheById.clear();
  }
}

/// Simple cache entry
class _CacheEntry<T> {
  final T value;
  final DateTime expiry;
  _CacheEntry(this.value, this.expiry);
}
