// lib/models/trip.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String title;
  final String description;
  final String driverId;
  final String driverName;
  final String? agencyId; // معرف المكتب إن وُجد
  final String tripCategory;
  final String origin;
  final String destination;
  final String vehicleType;
  final String? vehicleId;

  final int totalSeats;
  final int availableSeats;
  final List<bool> seatStatus;

  final DateTime? departureTime;
  final DateTime? date;
  final String time;
  final String flexibleWindow;

  final String status; // active, cancelled, completed
  final double price;
  final double driverRating;

  final String carPlateNumber;
  final String carOwnerOfficialName;

  // إضافات متعلقة بالرسوم والمسافة
  final double? govFeeAmount; // رسوم الفرزة الحكومية المحسوبة للرحلة
  final double? distanceKm; // المسافة بالكيلومترات (إن كانت متوفرة)

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  Trip({
    required this.id,
    this.title = '',
    this.description = '',
    this.driverId = '',
    this.driverName = '',
    this.agencyId,
    this.tripCategory = '',
    this.origin = '',
    this.destination = '',
    this.vehicleType = '',
    this.vehicleId,
    this.totalSeats = 0,
    this.availableSeats = 0,
    List<bool>? seatStatus,
    this.departureTime,
    this.date,
    this.time = '',
    this.flexibleWindow = '',
    this.status = 'active',
    this.price = 0.0,
    this.driverRating = 0.0,
    this.carPlateNumber = '',
    this.carOwnerOfficialName = '',
    this.govFeeAmount,
    this.distanceKm,
    this.createdAt,
    this.updatedAt,
  }) : seatStatus = seatStatus ?? List<bool>.filled(totalSeats > 0 ? totalSeats : 0, true);

  /// تحويل مستند Firestore إلى نموذج Trip (آمن ومرن مع أسماء حقول متعددة)
  factory Trip.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String _s(List<String> keys, [String fallback = '']) {
      for (var k in keys) {
        if (data[k] != null && data[k].toString().isNotEmpty) return data[k].toString();
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

    double _d(List<String> keys, [double fallback = 0.0]) {
      for (var k in keys) {
        final v = data[k];
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    DateTime? _dt(List<String> keys) {
      for (var k in keys) {
        final v = data[k];
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    List<bool> _seatList(dynamic raw, int total) {
      if (raw is List) {
        try {
          return raw.map<bool>((e) {
            if (e is bool) return e;
            if (e is num) return e != 0;
            if (e is String) return e.toLowerCase() == 'true';
            return false;
          }).toList();
        } catch (_) {}
      }
      // fallback: all available
      return List<bool>.filled(total > 0 ? total : 0, true);
    }

    final totalSeats = _i(['totalSeats', 'total_seats', 'total_seat', 'seats', 'total']);
    final availableSeats = _i(['availableSeats', 'available_seats', 'available', 'available_seat']);

    final seatStatusRaw = data['seatStatus'] ?? data['seat_status'] ?? data['seat_statuses'];
    final seatStatus = _seatList(seatStatusRaw, totalSeats);

    final departure = _dt(['departureTime', 'departure_time', 'departure']);
    final tripDate = _dt(['date', 'trip_date', 'departureDate']);

    // حقول جديدة: govFeeAmount, distanceKm, agencyId
    double? govFee;
    if (data.containsKey('govFeeAmount')) {
      final v = data['govFeeAmount'];
      if (v is num) govFee = v.toDouble();
      else if (v is String) govFee = double.tryParse(v);
    } else if (data.containsKey('gov_fee') || data.containsKey('gov_fee_amount')) {
      final v = data['gov_fee'] ?? data['gov_fee_amount'];
      if (v is num) govFee = v.toDouble();
      else if (v is String) govFee = double.tryParse(v);
    }

    double? distance;
    if (data.containsKey('distanceKm')) {
      final v = data['distanceKm'];
      if (v is num) distance = v.toDouble();
      else if (v is String) distance = double.tryParse(v);
    } else if (data.containsKey('distance_km') || data.containsKey('distance')) {
      final v = data['distanceKm'] ?? data['distance_km'] ?? data['distance'];
      if (v is num) distance = v.toDouble();
      else if (v is String) distance = double.tryParse(v);
    }

    final agencyId = _s(['agencyId', 'agency_id'], null);

    return Trip(
      id: doc.id,
      title: _s(['title', 'tripTitle']),
      description: _s(['description']),
      driverId: _s(['driverId', 'driver_id']),
      driverName: _s(['driverName', 'driver_name']),
      agencyId: agencyId.isNotEmpty ? agencyId : null,
      tripCategory: _s(['tripCategory', 'category']),
      origin: _s(['origin']),
      destination: _s(['destination']),
      vehicleType: _s(['vehicleType', 'vehicle_type']),
      vehicleId: _s(['vehicleId', 'vehicle_id'], null),
      totalSeats: totalSeats,
      availableSeats: availableSeats,
      seatStatus: seatStatus,
      departureTime: departure,
      date: tripDate,
      time: _s(['time']),
      flexibleWindow: _s(['flexibleWindow', 'flexible_window']),
      status: _s(['status'], 'active'),
      price: _d(['price']),
      driverRating: _d(['driverRating', 'driver_rating']),
      carPlateNumber: _s(['carPlateNumber', 'plateNumber', 'car_plate_number']),
      carOwnerOfficialName: _s(['carOwnerOfficialName', 'car_owner_official_name']),
      govFeeAmount: govFee,
      distanceKm: distance,
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null,
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] as Timestamp : null,
    );
  }

  /// تحويل النموذج إلى Map للكتابة إلى Firestore
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'driverId': driverId,
      'driverName': driverName,
      'agencyId': agencyId,
      'tripCategory': tripCategory,
      'origin': origin,
      'destination': destination,
      'vehicleType': vehicleType,
      'vehicleId': vehicleId,
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'seatStatus': seatStatus,
      'departureTime': departureTime != null ? Timestamp.fromDate(departureTime!) : null,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'time': time,
      'flexibleWindow': flexibleWindow,
      'status': status,
      'price': price,
      'driverRating': driverRating,
      'carPlateNumber': carPlateNumber,
      'carOwnerOfficialName': carOwnerOfficialName,
      'govFeeAmount': govFeeAmount,
      'distanceKm': distanceKm,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };

    map.removeWhere((key, value) => value == null);
    return map;
  }

  Trip copyWith({
    String? id,
    String? title,
    String? description,
    String? driverId,
    String? driverName,
    String? agencyId,
    String? tripCategory,
    String? origin,
    String? destination,
    String? vehicleType,
    String? vehicleId,
    int? totalSeats,
    int? availableSeats,
    List<bool>? seatStatus,
    DateTime? departureTime,
    DateTime? date,
    String? time,
    String? flexibleWindow,
    String? status,
    double? price,
    double? driverRating,
    String? carPlateNumber,
    String? carOwnerOfficialName,
    double? govFeeAmount,
    double? distanceKm,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      agencyId: agencyId ?? this.agencyId,
      tripCategory: tripCategory ?? this.tripCategory,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleId: vehicleId ?? this.vehicleId,
      totalSeats: totalSeats ?? this.totalSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      seatStatus: seatStatus ?? List<bool>.from(this.seatStatus),
      departureTime: departureTime ?? this.departureTime,
      date: date ?? this.date,
      time: time ?? this.time,
      flexibleWindow: flexibleWindow ?? this.flexibleWindow,
      status: status ?? this.status,
      price: price ?? this.price,
      driverRating: driverRating ?? this.driverRating,
      carPlateNumber: carPlateNumber ?? this.carPlateNumber,
      carOwnerOfficialName: carOwnerOfficialName ?? this.carOwnerOfficialName,
      govFeeAmount: govFeeAmount ?? this.govFeeAmount,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Trip(id: $id, title: $title, from: $origin, to: $destination, price: $price, govFee: ${govFeeAmount ?? 0.0})';
  }
}
