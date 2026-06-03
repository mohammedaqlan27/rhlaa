// lib/models/booking_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String bookingId;
  final String tripId;
  final String passengerId;
  final String driverId;

  final int bookedSeatsCount;
  final double totalPrice;
  final String passengerNickname;

  final bool isFamilyBooking;
  final int childrenCount;

  // الحقول الاختيارية (camelCase only)
  final int? seatNumber;
  final String? paymentMethod;

  final String bookingStatus;
  final String paymentStatus;

  final Timestamp? createdAt;
  final Timestamp? canceledAt;
  final Timestamp? updatedAt;

  Booking({
    required this.bookingId,
    required this.tripId,
    required this.passengerId,
    required this.driverId,
    required this.bookedSeatsCount,
    required this.totalPrice,
    required this.passengerNickname,
    required this.isFamilyBooking,
    required this.childrenCount,
    this.seatNumber,
    this.paymentMethod,
    required this.bookingStatus,
    required this.paymentStatus,
    this.createdAt,
    this.canceledAt,
    this.updatedAt,
  });

  /// تحويل النموذج إلى خريطة للكتابة إلى Firestore
  /// يكتب الحقول بصيغة camelCase فقط
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'tripId': tripId,
      'driverId': driverId,
      'passengerId': passengerId,
      'bookedSeatsCount': bookedSeatsCount,
      'totalPrice': totalPrice,
      'passengerNickname': passengerNickname,
      'isFamilyBooking': isFamilyBooking,
      'childrenCount': childrenCount,
      'bookingStatus': bookingStatus,
      'paymentStatus': paymentStatus,
      // createdAt: if provided use it, otherwise server timestamp
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };

    if (canceledAt != null) map['canceledAt'] = canceledAt;
    if (updatedAt != null) map['updatedAt'] = updatedAt;

    // الحقول الاختيارية بصيغة camelCase فقط
    if (seatNumber != null) map['seatNumber'] = seatNumber;
    if (paymentMethod != null) map['paymentMethod'] = paymentMethod;

    return map;
  }

  /// إنشاء نموذج من مستند Firestore
  /// يقرأ الحقول بصيغة camelCase مع دعم آمن لبعض legacy snake_case كاحتياط
  factory Booking.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String getString(List<String> keys, [String fallback = '']) {
      for (final k in keys) {
        final v = data[k];
        if (v != null) return v.toString();
      }
      return fallback;
    }

    int getInt(List<String> keys, [int fallback = 0]) {
      for (final k in keys) {
        final v = data[k];
        if (v == null) continue;
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
        if (v == null) continue;
        if (v is double) return v;
        if (v is num) return (v as num).toDouble();
        if (v is String) {
          final parsed = double.tryParse(v.replaceAll(',', ''));
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    bool getBool(List<String> keys, [bool fallback = false]) {
      for (final k in keys) {
        final v = data[k];
        if (v == null) continue;
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

    Timestamp? getTimestampNullable(List<String> keys) {
      for (final k in keys) {
        final v = data[k];
        if (v == null) continue;
        if (v is Timestamp) return v;
        if (v is DateTime) return Timestamp.fromDate(v);
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return Timestamp.fromDate(parsed);
        }
      }
      return null;
    }

    // قراءة الحقول بصيغة camelCase أولاً، ثم بعض البدائل snake_case كاحتياط
    final tripId = getString(['tripId', 'trip_id']);
    final passengerId = getString(['passengerId', 'passenger_id']);
    final driverId = getString(['driverId', 'driver_id']);
    final bookedSeatsCount = getInt(['bookedSeatsCount', 'booked_seats_count'], 1);
    final totalPrice = getDouble(['totalPrice', 'total_price'], 0.0);
    final passengerNickname = getString(['passengerNickname', 'passenger_nickname'], 'راكب');
    final isFamilyBooking = getBool(['isFamilyBooking', 'is_family_booking'], false);
    final childrenCount = getInt(['childrenCount', 'children_count'], 0);
    final bookingStatus = getString(['bookingStatus', 'booking_status'], 'pending');
    final paymentStatus = getString(['paymentStatus', 'payment_status'], 'unpaid');

    final createdAt = getTimestampNullable(['createdAt', 'created_at']);
    final canceledAt = getTimestampNullable(['canceledAt', 'canceled_at']);
    final updatedAt = getTimestampNullable(['updatedAt', 'updated_at']);

    // الحقول الاختيارية (camelCase) مع دعم بدائل
    int? seatNumber;
    final seatVal = data['seatNumber'] ?? data['seat_number'];
    if (seatVal != null) {
      if (seatVal is int) seatNumber = seatVal;
      else if (seatVal is num) seatNumber = seatVal.toInt();
      else if (seatVal is String) seatNumber = int.tryParse(seatVal);
    }

    String? paymentMethod;
    final pm = data['paymentMethod'] ?? data['payment_method'];
    if (pm != null) {
      paymentMethod = pm.toString();
      if (paymentMethod.isEmpty) paymentMethod = null;
    }

    return Booking(
      bookingId: doc.id,
      tripId: tripId,
      passengerId: passengerId,
      driverId: driverId,
      bookedSeatsCount: bookedSeatsCount,
      totalPrice: totalPrice,
      passengerNickname: passengerNickname,
      isFamilyBooking: isFamilyBooking,
      childrenCount: childrenCount,
      seatNumber: seatNumber,
      paymentMethod: paymentMethod,
      bookingStatus: bookingStatus,
      paymentStatus: paymentStatus,
      createdAt: createdAt,
      canceledAt: canceledAt,
      updatedAt: updatedAt,
    );
  }

  Booking copyWith({
    int? bookedSeatsCount,
    double? totalPrice,
    String? passengerNickname,
    String? bookingStatus,
    String? paymentStatus,
    int? childrenCount,
    bool? isFamilyBooking,
    int? seatNumber,
    String? paymentMethod,
    Timestamp? createdAt,
    Timestamp? canceledAt,
    Timestamp? updatedAt,
  }) {
    return Booking(
      bookingId: bookingId,
      tripId: tripId,
      passengerId: passengerId,
      driverId: driverId,
      bookedSeatsCount: bookedSeatsCount ?? this.bookedSeatsCount,
      totalPrice: totalPrice ?? this.totalPrice,
      passengerNickname: passengerNickname ?? this.passengerNickname,
      isFamilyBooking: isFamilyBooking ?? this.isFamilyBooking,
      childrenCount: childrenCount ?? this.childrenCount,
      seatNumber: seatNumber ?? this.seatNumber,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      canceledAt: canceledAt ?? this.canceledAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Booking(ID: $bookingId, Trip: $tripId, Seats: $bookedSeatsCount, Seat#: ${seatNumber ?? '-'}, Payment: ${paymentMethod ?? '-'}, Status: $bookingStatus)';
}
