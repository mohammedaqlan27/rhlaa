import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id; // معرف الحجز
  final String tripId;
  final String passengerId;
  final String driverId;
  final String passengerNickname;

  final int bookedSeatsCount;
  final int childrenCount;
  final int? seatNumber;

  final double totalPrice;
  final String amount; // الحقل الجديد (نصي حسب طلبك)

  final bool isFamilyBooking;
  final String bookingStatus;
  final String paymentStatus;
  final String? paymentMethod;
  final String? paymentService; // الحقل الجديد
  final String? schemeHost;     // الحقل الجديد
  final String? notes;          // الحقل الجديد

  final Timestamp? createdAt;
  final Timestamp? canceledAt;
  final Timestamp? updatedAt;

  Booking({
    required this.id,
    required this.tripId,
    required this.passengerId,
    required this.driverId,
    required this.passengerNickname,
    required this.bookedSeatsCount,
    required this.childrenCount,
    this.seatNumber,
    required this.totalPrice,
    this.amount = "",
    required this.isFamilyBooking,
    required this.bookingStatus,
    required this.paymentStatus,
    this.paymentMethod,
    this.paymentService,
    this.schemeHost,
    this.notes,
    this.createdAt,
    this.canceledAt,
    this.updatedAt,
  });

  /// تحويل النموذج إلى Map للكتابة إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'driverId': driverId,
      'passengerId': passengerId,
      'passengerNickname': passengerNickname,
      'bookedSeatsCount': bookedSeatsCount,
      'childrenCount': childrenCount,
      'seatNumber': seatNumber,
      'totalPrice': totalPrice,
      'amount': amount,
      'isFamilyBooking': isFamilyBooking,
      'bookingStatus': bookingStatus,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paymentService': paymentService,
      'schemeHost': schemeHost,
      'notes': notes,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'canceledAt': canceledAt,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    }..removeWhere((key, value) => value == null);
  }

  /// إنشاء نموذج من مستند Firestore مع معالجة ذكية
  factory Booking.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // دوال مساعدة لمنع الـ Crash
    String _s(List<String> keys, [String fallback = '']) {
      for (var k in keys) {
        if (data[k] != null) return data[k].toString();
      }
      return fallback;
    }

    int _i(List<String> keys, [int fallback = 0]) {
      for (var k in keys) {
        var v = data[k];
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    double _d(List<String> keys, [double fallback = 0.0]) {
      for (var k in keys) {
        var v = data[k];
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    bool _b(List<String> keys, [bool fallback = false]) {
      for (var k in keys) {
        var v = data[k];
        if (v is bool) return v;
        if (v is String) return v.toLowerCase() == 'true';
        if (v is num) return v == 1;
      }
      return fallback;
    }

    Timestamp? _t(List<String> keys) {
      for (var k in keys) {
        var v = data[k];
        if (v is Timestamp) return v;
        if (v is DateTime) return Timestamp.fromDate(v);
      }
      return null;
    }

    return Booking(
      id: _s(['id', 'bookingId']) ?? doc.id,
      tripId: _s(['tripId', 'trip_id']),
      passengerId: _s(['passengerId', 'passenger_id']),
      driverId: _s(['driverId', 'driver_id']),
      passengerNickname: _s(['passengerNickname', 'passenger_nickname'], 'راكب'),
      bookedSeatsCount: _i(['bookedSeatsCount', 'booked_seats_count']),
      childrenCount: _i(['childrenCount', 'children_count']),
      seatNumber: data['seatNumber'] != null ? _i(['seatNumber']) : null,
      totalPrice: _d(['totalPrice', 'total_price']),
      amount: _s(['amount']),
      isFamilyBooking: _b(['isFamilyBooking', 'is_family_booking']),
      bookingStatus: _s(['bookingStatus', 'booking_status'], 'pending'),
      paymentStatus: _s(['paymentStatus', 'payment_status'], 'unpaid'),
      paymentMethod: _s(['paymentMethod', 'payment_method']),
      paymentService: _s(['paymentService']),
      schemeHost: _s(['schemeHost']),
      notes: _s(['notes']),
      createdAt: _t(['createdAt', 'created_at']),
      canceledAt: _t(['canceledAt', 'canceled_at']),
      updatedAt: _t(['updatedAt', 'updated_at']),
    );
  }

  get bookingId => null;

  Booking copyWith({
    String? bookingStatus,
    String? paymentStatus,
    String? notes,
    int? seatNumber,
    Timestamp? updatedAt,
    Timestamp? canceledAt,
  }) {
    return Booking(
      id: id,
      tripId: tripId,
      passengerId: passengerId,
      driverId: driverId,
      passengerNickname: passengerNickname,
      bookedSeatsCount: bookedSeatsCount,
      childrenCount: childrenCount,
      seatNumber: seatNumber ?? this.seatNumber,
      totalPrice: totalPrice,
      amount: amount,
      isFamilyBooking: isFamilyBooking,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod,
      paymentService: paymentService,
      schemeHost: schemeHost,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      canceledAt: canceledAt ?? this.canceledAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Booking(ID: $id, Status: $bookingStatus, Price: $totalPrice)';
}