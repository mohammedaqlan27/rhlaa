import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String driverId;

  final String makeModelYear;
  final String? vehicleType;
  final String? color;
  final int maxCapacity;

  final String plateNumber;
  final String? licenseNumber;
  final String vehicleOwner;
  final bool isVerified;
  final String? notes;

  final Timestamp? createdAt;

  Vehicle({
    required this.id,
    required this.driverId,
    required this.makeModelYear,
    required this.maxCapacity,
    required this.plateNumber,
    required this.vehicleOwner,
    this.vehicleType,
    this.color,
    this.licenseNumber,
    this.isVerified = false,
    this.notes,
    this.createdAt,
  });

  /// تحويل النموذج إلى خريطة للكتابة إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'makeModelYear': makeModelYear,
      'vehicleType': vehicleType,
      'color': color,
      'maxCapacity': maxCapacity,
      'plateNumber': plateNumber,
      'licenseNumber': licenseNumber,
      'vehicleOwner': vehicleOwner,
      'isVerified': isVerified,
      'notes': notes,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  /// إنشاء نموذج من مستند Firestore يدعم المرونة العالية بين صيغ الحقول
  factory Vehicle.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String _getString(List<String> keys, [String fallback = '']) {
      for (final k in keys) {
        final v = data[k];
        if (v != null) return v.toString();
      }
      return fallback;
    }

    int _getInt(List<String> keys, [int fallback = 0]) {
      for (final k in keys) {
        final v = data[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final parsed = int.tryParse(v.replaceAll(',', ''));
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    bool _getBool(List<String> keys, [bool fallback = false]) {
      for (final k in keys) {
        final v = data[k];
        if (v is bool) return v;
        if (v is int) return v != 0;
        if (v is String) {
          final s = v.toLowerCase();
          if (s == 'true' || s == '1') return true;
          if (s == 'false' || s == '0') return false;
        }
      }
      return fallback;
    }

    Timestamp? _getTimestampNullable(List<String> keys) {
      for (final k in keys) {
        final v = data[k];
        if (v is Timestamp) return v;
        if (v is DateTime) return Timestamp.fromDate(v);
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return Timestamp.fromDate(parsed);
        }
      }
      return null;
    }

    final driverId = _getString(['driverId', 'driver_id'], '');
    final makeModelYear = _getString(['makeModelYear', 'make_model_year'], 'غير محدد');

    final vehicleTypeRaw = _getString(['vehicleType', 'vehicle_type'], '');
    final colorRaw = _getString(['color'], '');
    final licenseNumberRaw = _getString(['licenseNumber', 'license_number'], '');
    final notesRaw = _getString(['notes'], '');

    final vehicleType = vehicleTypeRaw.isNotEmpty ? vehicleTypeRaw : null;
    final color = colorRaw.isNotEmpty ? colorRaw : null;
    final licenseNumber = licenseNumberRaw.isNotEmpty ? licenseNumberRaw : null;
    final notes = notesRaw.isNotEmpty ? notesRaw : null;

    final maxCapacity = _getInt(['maxCapacity', 'max_capacity'], 0);
    final plateNumber = _getString(['plateNumber', 'plate_number'], '');
    final vehicleOwner = _getString(['vehicleOwner', 'vehicle_owner'], 'غير محدد');
    final isVerified = _getBool(['isVerified', 'is_verified'], false);
    final createdAt = _getTimestampNullable(['createdAt', 'created_at']);

    return Vehicle(
      id: doc.id,
      driverId: driverId,
      makeModelYear: makeModelYear,
      vehicleType: vehicleType,
      color: color,
      maxCapacity: maxCapacity,
      plateNumber: plateNumber,
      licenseNumber: licenseNumber,
      vehicleOwner: vehicleOwner,
      isVerified: isVerified,
      notes: notes,
      createdAt: createdAt,
    );
  }

  /// تم إصلاح الـ copyWith لتقبل تحديث الـ معرفات عند الحاجة البرمجية
  Vehicle copyWith({
    String? id,
    String? driverId,
    String? makeModelYear,
    String? vehicleType,
    String? color,
    int? maxCapacity,
    String? plateNumber,
    String? licenseNumber,
    String? vehicleOwner,
    bool? isVerified,
    String? notes,
    Timestamp? createdAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      makeModelYear: makeModelYear ?? this.makeModelYear,
      vehicleType: vehicleType ?? this.vehicleType,
      color: color ?? this.color,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      plateNumber: plateNumber ?? this.plateNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vehicleOwner: vehicleOwner ?? this.vehicleOwner,
      isVerified: isVerified ?? this.isVerified,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Vehicle(ID: $id, Model: $makeModelYear, Plate: $plateNumber, Verified: $isVerified)';
}