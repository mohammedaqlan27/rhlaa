// lib/models/booking_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String tripId;
  final String passengerId;
  final String passengerNickname;
  final String driverId;

  final int bookedSeatsCount;
  final double totalPrice;
  final bool isFamilyBooking;
  final int childrenCount;

  final String bookingStatus; // pending, confirmed, cancelled, completed
  final String paymentStatus; // unpaid, paid, refunded

  final String? notes;
  final Timestamp? canceledAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  Booking({
    required this.id,
    required this.tripId,
    required this.passengerId,
    required this.passengerNickname,
    required this.driverId,
    this.bookedSeatsCount = 1,
    this.totalPrice = 0.0,
    this.isFamilyBooking = false,
    this.childrenCount = 0,
    this.bookingStatus = 'pending',
    this.paymentStatus = 'unpaid',
    this.notes,
    this.canceledAt,
    this.createdAt,
    this.updatedAt,
  });

  /// تحويل النموذج إلى Map للكتابة إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'passengerId': passengerId,
      'passengerNickname': passengerNickname,
      'driverId': driverId,
      'bookedSeatsCount': bookedSeatsCount,
      'totalPrice': totalPrice,
      'isFamilyBooking': isFamilyBooking,
      'childrenCount': childrenCount,
      'bookingStatus': bookingStatus,
      'paymentStatus': paymentStatus,
      'notes': notes,
      'canceledAt': canceledAt,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt,
    }..removeWhere((key, value) => value == null);
  }

  /// إنشاء نموذج من مستند Firestore مع معالجة أنواع مختلفة بأمان
  factory Booking.fromDocument(DocumentSnapshot doc) {
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

    double d(List<String> keys, [double fallback = 0.0]) {
      for (var k in keys) {
        final v = data[k];
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    bool b(List<String> keys, [bool fallback = false]) {
      for (var k in keys) {
        final v = data[k];
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) return v.toLowerCase() == 'true';
      }
      return fallback;
    }

    Timestamp? ts(String key) {
      final v = data[key];
      if (v is Timestamp) return v;
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return Timestamp.fromDate(parsed);
      }
      return null;
    }

    return Booking(
      id: doc.id,
      tripId: s(['tripId', 'trip_id']),
      passengerId: s(['passengerId', 'passenger_id']),
      passengerNickname: s(['passengerNickname', 'passenger_nickname', 'passengerName']),
      driverId: s(['driverId', 'driver_id']),
      bookedSeatsCount: i(['bookedSeatsCount', 'seatsCount', 'seats_count'], 1),
      totalPrice: d(['totalPrice', 'total_price', 'price']),
      isFamilyBooking: b(['isFamilyBooking', 'is_family_booking']),
      childrenCount: i(['childrenCount', 'children_count']),
      bookingStatus: s(['bookingStatus', 'status'], 'pending'),
      paymentStatus: s(['paymentStatus', 'payment_status'], 'unpaid'),
      notes: data['notes']?.toString(),
      canceledAt: ts('canceledAt'),
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : ts('createdAt'),
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] as Timestamp : ts('updatedAt'),
    );
  }

  List<int>? get seatIndexes => null;

  Booking copyWith({
    String? id,
    String? tripId,
    String? passengerId,
    String? passengerNickname,
    String? driverId,
    int? bookedSeatsCount,
    double? totalPrice,
    bool? isFamilyBooking,
    int? childrenCount,
    String? bookingStatus,
    String? paymentStatus,
    String? notes,
    Timestamp? canceledAt,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return Booking(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      passengerId: passengerId ?? this.passengerId,
      passengerNickname: passengerNickname ?? this.passengerNickname,
      driverId: driverId ?? this.driverId,
      bookedSeatsCount: bookedSeatsCount ?? this.bookedSeatsCount,
      totalPrice: totalPrice ?? this.totalPrice,
      isFamilyBooking: isFamilyBooking ?? this.isFamilyBooking,
      childrenCount: childrenCount ?? this.childrenCount,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes ?? this.notes,
      canceledAt: canceledAt ?? this.canceledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Booking(id: $id, tripId: $tripId, passengerId: $passengerId, seats: $bookedSeatsCount, total: $totalPrice, status: $bookingStatus)';
  }
}
