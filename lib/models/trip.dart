// lib/models/trip.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String? id;
  final String title;
  final String description;
  final String driverId;
  final String driverName;
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

  final String status;
  final double price;
  final double driverRating;

  final String carPlateNumber;
  final String carOwnerOfficialName;

  final Timestamp? createdAt;

  Trip({
    this.id,
    this.title = '',
    this.description = '',
    this.driverId = '',
    this.driverName = '',
    this.tripCategory = 'داخلية',
    this.origin = '',
    this.destination = '',
    this.vehicleType = '',
    this.vehicleId,
    this.totalSeats = 0,
    this.availableSeats = 0,
    List<bool>? seatStatus,
    this.departureTime,
    this.date,
    this.time = 'صباحًا',
    this.flexibleWindow = '',
    this.status = 'active',
    this.price = 0.0,
    this.driverRating = 0.0,
    this.carPlateNumber = 'غير متوفر',
    this.carOwnerOfficialName = 'غير متوفر',
    this.createdAt,
  }) : seatStatus = seatStatus ?? List<bool>.filled(totalSeats > 0 ? totalSeats : 0, true);

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = <String, dynamic>{};

    if (title.isNotEmpty) map['title'] = title;
    if (description.isNotEmpty) map['description'] = description;
    if (driverId.isNotEmpty) map['driverId'] = driverId;
    if (driverName.isNotEmpty) map['driverName'] = driverName;
    map['tripCategory'] = tripCategory;
    if (origin.isNotEmpty) map['origin'] = origin;
    if (destination.isNotEmpty) map['destination'] = destination;
    if (vehicleType.isNotEmpty) map['vehicleType'] = vehicleType;
    if (vehicleId != null && vehicleId!.isNotEmpty) map['vehicleId'] = vehicleId;
    map['totalSeats'] = totalSeats;
    map['availableSeats'] = availableSeats;
    map['seatStatus'] = seatStatus;
    if (departureTime != null) map['departureTime'] = Timestamp.fromDate(departureTime!);
    if (date != null) map['date'] = Timestamp.fromDate(date!);
    map['time'] = time;
    map['flexibleWindow'] = flexibleWindow;
    map['status'] = status;
    map['price'] = price;
    map['driverRating'] = driverRating;
    map['carPlateNumber'] = carPlateNumber;
    map['carOwnerOfficialName'] = carOwnerOfficialName;

    // createdAt: if provided use it, otherwise server timestamp
    map['createdAt'] = createdAt ?? FieldValue.serverTimestamp();

    // snake_case duplicates for backward compatibility
    map['car_plate_number'] = carPlateNumber;
    map['car_owner_official_name'] = carOwnerOfficialName;
    map['created_at'] = createdAt ?? FieldValue.serverTimestamp();

    return map;
  }

  factory Trip.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

    String? getString(List<String> keys, [String? fallback]) {
      for (final k in keys) {
        final v = data[k];
        if (v != null) return v.toString();
      }
      return fallback;
    }

    int getInt(List<String> keys, [int fallback = 0]) {
      for (final k in keys) {
        final v = data[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    double getDouble(List<String> keys, [double fallback = 0.0]) {
      for (final k in keys) {
        final v = data[k];
        if (v is double) return v;
        if (v is num) return (v as num).toDouble();
        if (v is String) {
          final parsed = double.tryParse(v.replaceAll(',', ''));
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    Timestamp? getTimestamp(List<String> keys) {
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

    List<bool> getSeatStatus(List<String> keys, int seatsFallback) {
      for (final k in keys) {
        final v = data[k];
        if (v is List) {
          try {
            final list = v.map<bool>((e) {
              if (e is bool) return e;
              if (e is num) return e != 0;
              if (e is String) {
                final s = e.toLowerCase();
                return s == 'true' || s == '1';
              }
              return false;
            }).toList();
            if (list.isNotEmpty) return list;
          } catch (_) {}
        }
      }
      return List<bool>.filled(seatsFallback > 0 ? seatsFallback : 0, true);
    }

    final title = getString(['title']) ?? '';
    final description = getString(['description']) ?? '';
    final driverId = getString(['driverId', 'driver_id']) ?? '';
    final driverName = getString(['driverName', 'driver_name']) ?? '';
    final tripCategory = getString(['tripCategory', 'trip_category']) ?? 'داخلية';
    final origin = getString(['origin']) ?? '';
    final destination = getString(['destination']) ?? '';
    final vehicleType = getString(['vehicleType', 'vehicle_type']) ?? '';
    final vehicleId = getString(['vehicleId', 'vehicle_id']);
    final totalSeats = getInt(['totalSeats', 'total_seats'], 0);
    final availableSeats = getInt(['availableSeats', 'available_seats'], totalSeats);
    final seatStatus = getSeatStatus(['seatStatus', 'seat_status'], totalSeats);

    final departureTs = getTimestamp(['departureTime', 'departure_time']);
    final dateTs = getTimestamp(['date', 'trip_date', 'travel_date']);

    final time = getString(['time']) ?? 'صباحًا';
    final flexibleWindow = getString(['flexibleWindow', 'flexible_window']) ?? '';
    final status = getString(['status']) ?? 'active';
    final price = getDouble(['price']) ?? 0.0;
    final driverRating = getDouble(['driverRating', 'driver_rating']) ?? 0.0;

    final carPlateNumber = getString(['carPlateNumber', 'car_plate_number', 'plateNumber', 'plate_number']) ?? 'غير متوفر';
    final carOwnerOfficialName = getString(['carOwnerOfficialName', 'car_owner_official_name', 'vehicleOwner', 'vehicle_owner']) ?? 'غير متوفر';

    final createdAt = getTimestamp(['createdAt', 'created_at']);

    final normalizedSeatStatus = List<bool>.from(seatStatus);
    if (normalizedSeatStatus.isEmpty && totalSeats > 0) {
      for (int i = 0; i < totalSeats; i++) normalizedSeatStatus.add(true);
    } else if (normalizedSeatStatus.length < totalSeats) {
      final diff = totalSeats - normalizedSeatStatus.length;
      for (int i = 0; i < diff; i++) normalizedSeatStatus.add(true);
    } else if (normalizedSeatStatus.length > totalSeats && totalSeats > 0) {
      normalizedSeatStatus.removeRange(totalSeats, normalizedSeatStatus.length);
    }

    return Trip(
      id: doc.id,
      title: title,
      description: description,
      driverId: driverId,
      driverName: driverName,
      tripCategory: tripCategory,
      origin: origin,
      destination: destination,
      vehicleType: vehicleType,
      vehicleId: vehicleId,
      totalSeats: totalSeats,
      availableSeats: availableSeats,
      seatStatus: normalizedSeatStatus,
      departureTime: departureTs?.toDate(),
      date: dateTs?.toDate(),
      time: time,
      flexibleWindow: flexibleWindow,
      status: status,
      price: price,
      driverRating: driverRating,
      carPlateNumber: carPlateNumber,
      carOwnerOfficialName: carOwnerOfficialName,
      createdAt: createdAt,
    );
  }

  Trip copyWith({
    String? id,
    String? title,
    String? description,
    String? driverId,
    String? driverName,
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
    Timestamp? createdAt,
  }) {
    return Trip(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
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
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Trip(id: ${id ?? '—'}, title: $title, driver: $driverName, origin: $origin → $destination, price: $price)';
  }
}
