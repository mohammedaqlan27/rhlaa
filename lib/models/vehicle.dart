// lib/models/vehicle.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String plateNumber;
  final String vehicleOwner; // userId أو اسم المالك
  final String vehicleType; // مثال: 'sedan', 'van', 'motorbike'
  final String makeModelYear; // مثال: 'Toyota Corolla 2018'
  final String color;
  final int maxCapacity; // أقصى عدد ركاب
  final String licenseNumber; // رقم رخصة المركبة أو رقم التسجيل
  final bool isVerified; // هل تم التحقق من المركبة
  final String? notes;
  final Timestamp? createdAt;

  Vehicle({
    required this.id,
    this.plateNumber = '',
    this.vehicleOwner = '',
    this.vehicleType = '',
    this.makeModelYear = '',
    this.color = '',
    this.maxCapacity = 0,
    this.licenseNumber = '',
    this.isVerified = false,
    this.notes,
    this.createdAt,
  });

  /// تحويل الكائن إلى Map لحفظه في Firestore
  Map<String, dynamic> toMap() {
    return {
      'plateNumber': plateNumber,
      'vehicleOwner': vehicleOwner,
      'vehicleType': vehicleType,
      'makeModelYear': makeModelYear,
      'color': color,
      'maxCapacity': maxCapacity,
      'licenseNumber': licenseNumber,
      'isVerified': isVerified,
      'notes': notes,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    }..removeWhere((key, value) => value == null);
  }

  /// إنشاء نموذج من مستند Firestore مع دعم camelCase و snake_case
  factory Vehicle.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String _s(List<String> keys, [String fallback = '']) {
      for (var k in keys) {
        final v = data[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    int _i(List<String> keys, [int fallback = 0]) {
      for (var k in keys) {
        final v = data[k];
        if (v is int) return v;
        if (v is double) return v.toInt();
        if (v is String) return int.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    bool _b(List<String> keys, [bool fallback = false]) {
      for (var k in keys) {
        final v = data[k];
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) return v.toLowerCase() == 'true';
      }
      return fallback;
    }

    Timestamp? _ts(List<String> keys) {
      for (var k in keys) {
        final v = data[k];
        if (v is Timestamp) return v;
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return Timestamp.fromDate(parsed);
        }
      }
      return null;
    }

    return Vehicle(
      id: doc.id,
      plateNumber: _s(['plateNumber', 'plate_number', 'plate']),
      vehicleOwner: _s(['vehicleOwner', 'vehicle_owner', 'ownerId', 'owner']),
      vehicleType: _s(['vehicleType', 'vehicle_type', 'type']),
      makeModelYear: _s(['makeModelYear', 'make_model_year', 'makeModel', 'modelYear']),
      color: _s(['color']),
      maxCapacity: _i(['maxCapacity', 'max_capacity', 'capacity']),
      licenseNumber: _s(['licenseNumber', 'license_number', 'registrationNumber']),
      isVerified: _b(['isVerified', 'is_verified', 'verified']),
      notes: _s(['notes', 'note', 'description']),
      createdAt: _ts(['createdAt', 'created_at', 'created']),
    );
  }

  Vehicle copyWith({
    String? id,
    String? plateNumber,
    String? vehicleOwner,
    String? vehicleType,
    String? makeModelYear,
    String? color,
    int? maxCapacity,
    String? licenseNumber,
    bool? isVerified,
    String? notes,
    Timestamp? createdAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      vehicleOwner: vehicleOwner ?? this.vehicleOwner,
      vehicleType: vehicleType ?? this.vehicleType,
      makeModelYear: makeModelYear ?? this.makeModelYear,
      color: color ?? this.color,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      isVerified: isVerified ?? this.isVerified,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, plate: $plateNumber, owner: $vehicleOwner, type: $vehicleType, capacity: $maxCapacity)';
  }
}
