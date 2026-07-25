// lib/models/vehicle.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج Vehicle موحّد وآمن للقراءة والكتابة إلى Firestore.
/// يدعم أسماء الحقول البديلة (camelCase / snake_case) ويتعامل مع أنواع متعددة بأمان.
class Vehicle {
  final String id;
  final String plateNumber;
  final String vehicleOwner; // userId الموحد الحالي
  final String? ownerId;     // حقل احتياطي في المستندات القديمة
  final String? driverId;    // مرجع اختياري للسائق المرتبط بالمركبة
  final String? driverName;
  final String vehicleType;  // مثال: 'sedan', 'van', 'motorbike'
  final String makeModelYear;
  final String color;
  final int maxCapacity;     // أقصى عدد ركاب
  final String licenseNumber;
  final bool isVerified;
  final bool sGovernmentRegistered;
  final String? notes;
  final Map<String, dynamic>? extra;
  final List<String> vehicleDocuments;
  final Timestamp? insuranceExpiryDate;
  final String? lastInspectionDate;
  final String? carOwnerOfficialName;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  Vehicle({
    required this.id,
    this.plateNumber = '',
    this.vehicleOwner = '',
    this.ownerId,
    this.driverId,
    this.driverName,
    this.vehicleType = '',
    this.makeModelYear = '',
    this.color = '',
    this.maxCapacity = 0,
    this.licenseNumber = '',
    this.isVerified = false,
    this.sGovernmentRegistered = false,
    this.notes,
    this.extra,
    this.vehicleDocuments = const [],
    this.insuranceExpiryDate,
    this.lastInspectionDate,
    this.carOwnerOfficialName,
    this.createdAt,
    this.updatedAt,
  });

  /// تحويل الكائن إلى Map للحفظ في Firestore
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'plateNumber': plateNumber,
      'vehicleOwner': vehicleOwner,
      'ownerId': ownerId,
      'driverId': driverId,
      'driverName': driverName,
      'vehicleType': vehicleType,
      'makeModelYear': makeModelYear,
      'color': color,
      'maxCapacity': maxCapacity,
      'licenseNumber': licenseNumber,
      'isVerified': isVerified,
      'sGovernmentRegistered': sGovernmentRegistered,
      'notes': notes,
      'extra': extra,
      'vehicleDocuments': vehicleDocuments,
      'insuranceExpiryDate': insuranceExpiryDate,
      'lastInspectionDate': lastInspectionDate,
      'carOwnerOfficialName': carOwnerOfficialName,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
    map.removeWhere((k, v) => v == null);
    return map;
  }

  /// مساعدة لتحويل قيمة قد تكون JSON نصي إلى Map
  static Map<String, dynamic>? _tryParseExtra(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      try {
        final decoded = json.decode(s);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  /// إنشاء نموذج من مستند Firestore مع دعم camelCase و snake_case وأنواع متعددة
  factory Vehicle.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String s(List<String> keys, [String fallback = '']) {
      for (var k in keys) {
        final v = data[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    int i(List<String> keys, [int fallback = 0]) {
      for (var k in keys) {
        final v = data[k];
        if (v is int) return v;
        if (v is double) return v.toInt();
        if (v is String) return int.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    bool b(List<String> keys, [bool fallback = false]) {
      for (var k in keys) {
        final v = data[k];
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) {
          final low = v.toLowerCase();
          if (low == 'true' || low == '1') return true;
          if (low == 'false' || low == '0') return false;
        }
      }
      return fallback;
    }

    Timestamp? ts(List<String> keys) {
      for (var k in keys) {
        final v = data[k];
        if (v is Timestamp) return v;
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return Timestamp.fromDate(parsed);
        }
        if (v is int) {
          try {
            return Timestamp.fromMillisecondsSinceEpoch(v);
          } catch (_) {}
        }
      }
      return null;
    }

    List<String> list(List<String> keys) {
      for (var k in keys) {
        final v = data[k];
        if (v is List) {
          return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
        }
      }
      return [];
    }

    Map<String, dynamic>? map(List<String> keys) {
      for (var k in keys) {
        final v = data[k];
        final parsed = _tryParseExtra(v);
        if (parsed != null) return parsed;
      }
      return null;
    }

    return Vehicle(
      id: doc.id,
      plateNumber: s(['plateNumber', 'plate_number', 'plate']),
      vehicleOwner: s(['vehicleOwner', 'vehicle_owner', 'ownerUserId', 'owner']),
      ownerId: s(['ownerId', 'owner']),
      driverId: s(['driverId', 'driver_id']),
      driverName: s(['driverName']),
      vehicleType: s(['vehicleType', 'vehicle_type', 'type']),
      makeModelYear: s(['makeModelYear', 'make_model_year', 'makeModel', 'modelYear']),
      color: s(['color']),
      maxCapacity: i(['maxCapacity', 'max_capacity', 'capacity']),
      licenseNumber: s(['licenseNumber', 'license_number', 'registrationNumber']),
      isVerified: b(['isVerified', 'is_verified', 'verified']),
      sGovernmentRegistered: b(['sGovernmentRegistered', 'governmentRegistered']),
      notes: s(['notes', 'note', 'description']).isNotEmpty ? s(['notes', 'note', 'description']) : null,
      extra: map(['extra', 'meta', 'metadata']),
      vehicleDocuments: list(['vehicleDocuments']),
      insuranceExpiryDate: ts(['insuranceExpiryDate']),
      lastInspectionDate: s(['lastInspectionDate']),
      carOwnerOfficialName: s(['carOwnerOfficialName']),
      createdAt: ts(['createdAt', 'created_at', 'created']),
      updatedAt: ts(['updatedAt', 'updated_at']),
    );
  }

  Vehicle copyWith({
    String? id,
    String? plateNumber,
    String? vehicleOwner,
    String? ownerId,
    String? driverId,
    String? driverName,
    String? vehicleType,
    String? makeModelYear,
    String? color,
    int? maxCapacity,
    String? licenseNumber,
    bool? isVerified,
    bool? sGovernmentRegistered,
    String? notes,
    Map<String, dynamic>? extra,
    List<String>? vehicleDocuments,
    Timestamp? insuranceExpiryDate,
    String? lastInspectionDate,
    String? carOwnerOfficialName,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      vehicleOwner: vehicleOwner ?? this.vehicleOwner,
      ownerId: ownerId ?? this.ownerId,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      vehicleType: vehicleType ?? this.vehicleType,
      makeModelYear: makeModelYear ?? this.makeModelYear,
      color: color ?? this.color,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      isVerified: isVerified ?? this.isVerified,
      sGovernmentRegistered: sGovernmentRegistered ?? this.sGovernmentRegistered,
      notes: notes ?? this.notes,
      extra: extra ?? this.extra,
      vehicleDocuments: vehicleDocuments ?? this.vehicleDocuments,
      insuranceExpiryDate: insuranceExpiryDate ?? this.insuranceExpiryDate,
      lastInspectionDate: lastInspectionDate ?? this.lastInspectionDate,
      carOwnerOfficialName: carOwnerOfficialName ?? this.carOwnerOfficialName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, plate: $plateNumber, owner: $vehicleOwner, type: $vehicleType, capacity: $maxCapacity)';
  }
}
