// lib/models/trip.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج Trip موحّد وآمن للقراءة والكتابة إلى Firestore.
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
  final double? govFeeAmount;
  final double? distanceKm;

  // بيانات كشف الركاب (Manifest)
  final String? manifestUrl;
  final String? manifestStoragePath;
  final Timestamp? manifestGeneratedAt;
  final String? manifestStatus;

  // بيانات إضافية
  final String? cancellationPolicy;
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
    this.manifestUrl,
    this.manifestStoragePath,
    this.manifestGeneratedAt,
    this.manifestStatus,
    this.cancellationPolicy,
    this.createdAt,
    this.updatedAt,
  }) : seatStatus = seatStatus ?? List<bool>.filled(totalSeats > 0 ? totalSeats : 0, true);

  // =========================
  // Factory: from Firestore doc
  // =========================
  factory Trip.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    int _parseInt(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double _parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    DateTime? _parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    List<bool> _parseSeatStatus(dynamic raw, int total) {
      if (raw is List) {
        final parsed = raw.map<bool>((e) {
          if (e is bool) return e;
          if (e is num) return e != 0;
          if (e is String) return e.toLowerCase() == 'true' || e == '1';
          return false;
        }).toList();
        if (total > 0 && parsed.length != total) {
          return List<bool>.filled(total, true);
        }
        return parsed;
      }
      return List<bool>.filled(total, true);
    }

    final totalSeats = _parseInt(data['totalSeats']);
    return Trip(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      agencyId: data['agencyId'],
      tripCategory: data['tripCategory'] ?? '',
      origin: data['origin'] ?? '',
      destination: data['destination'] ?? '',
      vehicleType: data['vehicleType'] ?? '',
      vehicleId: data['vehicleId'],
      totalSeats: totalSeats,
      availableSeats: _parseInt(data['availableSeats']),
      seatStatus: _parseSeatStatus(data['seatStatus'], totalSeats),
      departureTime: _parseDate(data['departureTime']),
      date: _parseDate(data['date']),
      time: data['time'] ?? '',
      flexibleWindow: data['flexibleWindow'] ?? '',
      status: data['status'] ?? 'active',
      price: _parseDouble(data['price']),
      driverRating: _parseDouble(data['driverRating']),
      carPlateNumber: data['carPlateNumber'] ?? data['plateNumber'] ?? '',
      carOwnerOfficialName: data['carOwnerOfficialName'] ?? '',
      govFeeAmount: data['govFeeAmount'] != null ? _parseDouble(data['govFeeAmount']) : null,
      distanceKm: data['distanceKm'] != null ? _parseDouble(data['distanceKm']) : null,
      manifestUrl: data['manifestUrl'],
      manifestStoragePath: data['manifestStoragePath'],
      manifestGeneratedAt: data['manifestGeneratedAt'] is Timestamp ? data['manifestGeneratedAt'] : null,
      manifestStatus: data['manifestStatus'],
      cancellationPolicy: data['cancellationPolicy'],
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] : null,
    );
  }

  // =========================
  // Convert to Map for Firestore
  // =========================
  Map<String, dynamic> toMap() {
    return {
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
      'manifestUrl': manifestUrl,
      'manifestStoragePath': manifestStoragePath,
      'manifestGeneratedAt': manifestGeneratedAt,
      'manifestStatus': manifestStatus,
      'cancellationPolicy': cancellationPolicy,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    }..removeWhere((key, value) => value == null);
  }

  // =========================
  // CopyWith: تم إضافة كافة الحقول الناقصة هنا
  // =========================
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
    String? manifestUrl,
    String? manifestStoragePath,
    Timestamp? manifestGeneratedAt,
    String? manifestStatus,
    String? cancellationPolicy,
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
      seatStatus: seatStatus ?? this.seatStatus,
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
      manifestUrl: manifestUrl ?? this.manifestUrl,
      manifestStoragePath: manifestStoragePath ?? this.manifestStoragePath,
      manifestGeneratedAt: manifestGeneratedAt ?? this.manifestGeneratedAt,
      manifestStatus: manifestStatus ?? this.manifestStatus,
      cancellationPolicy: cancellationPolicy ?? this.cancellationPolicy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Trip(id: $id, from: $origin, to: $destination, seats: $availableSeats/$totalSeats, price: $price)';
  }
}