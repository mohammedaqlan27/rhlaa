// lib/models/booking_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج Booking موحّد وآمن للقراءة والكتابة إلى Firestore.
/// يدعم أسماء الحقول البديلة (camelCase / snake_case) ويتعامل مع أنواع متعددة بأمان.
class Booking {
  final String id;
  final String tripId;
  final String passengerId;
  final String passengerNickname;
  final String driverId;

  final double amountPaid;
  final double totalPrice;
  final int bookedSeatsCount;
  final bool isFamilyBooking;
  final int childrenCount;

  final String bookingStatus; // pending, confirmed, cancelled, completed
  final String paymentStatus; // unpaid, paid, refunded
  final String paymentMethod;
  final String? paymentIntentId;
  final String? transactionId;
  final Timestamp? paidAt;

  final List<int>? seatIndexes; // قائمة مؤشرات المقاعد
  final int? seatNumber; // رقم المقعد المفرد (legacy)
  final Timestamp? reservedUntil; // يمكن أن يكون Timestamp أو String

  final String? notes;
  final Timestamp? canceledAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  // حقول إضافية عامة (قد تكون موجودة في المستند)
  final String? bookingService;
  final String? pdfService;

  Booking({
    required this.id,
    required this.tripId,
    required this.passengerId,
    required this.passengerNickname,
    required this.driverId,
    this.amountPaid = 0.0,
    this.totalPrice = 0.0,
    this.bookedSeatsCount = 1,
    this.isFamilyBooking = false,
    this.childrenCount = 0,
    this.bookingStatus = 'pending',
    this.paymentStatus = 'unpaid',
    this.paymentMethod = '',
    this.paymentIntentId,
    this.transactionId,
    this.paidAt,
    this.seatIndexes,
    this.seatNumber,
    this.reservedUntil,
    this.notes,
    this.canceledAt,
    this.createdAt,
    this.updatedAt,
    this.bookingService,
    this.pdfService,
  });

  /// تحويل النموذج إلى Map للكتابة إلى Firestore
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'tripId': tripId,
      'passengerId': passengerId,
      'passengerNickname': passengerNickname,
      'driverId': driverId,
      'amountPaid': amountPaid,
      'totalPrice': totalPrice,
      'bookedSeatsCount': bookedSeatsCount,
      'isFamilyBooking': isFamilyBooking,
      'childrenCount': childrenCount,
      'bookingStatus': bookingStatus,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paymentIntentId': paymentIntentId,
      'transactionId': transactionId,
      'paidAt': paidAt,
      'seatIndexes': seatIndexes,
      'seatNumber': seatNumber,
      'reservedUntil': reservedUntil,
      'notes': notes,
      'canceledAt': canceledAt,
      'bookingService': bookingService,
      'pdfService': pdfService,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };

    map.removeWhere((key, value) => value == null);
    return map;
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
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    double d(List<String> keys, [double fallback = 0.0]) {
      for (var k in keys) {
        final v = data[k];
        if (v is num) return v.toDouble();
        if (v is String) {
          final parsed = double.tryParse(v);
          if (parsed != null) return parsed;
        }
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

    Timestamp? ts(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v;
      if (v is DateTime) return Timestamp.fromDate(v);
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return Timestamp.fromDate(parsed);
      }
      if (v is int) {
        try {
          return Timestamp.fromMillisecondsSinceEpoch(v);
        } catch (_) {}
      }
      return null;
    }

    List<int>? parseSeatIndexes(dynamic raw) {
      if (raw == null) return null;
      if (raw is List) {
        try {
          return raw.map<int>((e) {
            if (e is int) return e;
            if (e is double) return e.toInt();
            if (e is String) return int.tryParse(e) ?? -1;
            return -1;
          }).where((v) => v >= 0).toList();
        } catch (_) {
          return null;
        }
      }
      // إذا كان مخزناً كقيمة مفردة (legacy) مثل 0 أو "0"
      if (raw is int) return [raw];
      if (raw is double) return [raw.toInt()];
      if (raw is String) {
        final parsed = int.tryParse(raw);
        if (parsed != null) return [parsed];
      }
      return null;
    }

    // قراءة reservedUntil قد تكون نص أو Timestamp
    final reservedRaw = data['reservedUntil'] ?? data['reserved_until'];
    final reservedTimestamp = ts(reservedRaw);

    return Booking(
      id: doc.id,
      tripId: s(['tripId', 'trip_id']),
      passengerId: s(['passengerId', 'passenger_id']),
      passengerNickname: s(['passengerNickname', 'passenger_nickname', 'passengerName']),
      driverId: s(['driverId', 'driver_id']),
      amountPaid: d(['amountPaid', 'amount_paid', 'paidAmount']),
      totalPrice: d(['totalPrice', 'total_price', 'price']),
      bookedSeatsCount: i(['bookedSeatsCount', 'seatsCount', 'seats_count'], 1),
      isFamilyBooking: b(['isFamilyBooking', 'is_family_booking']),
      childrenCount: i(['childrenCount', 'children_count'], 0),
      bookingStatus: s(['bookingStatus', 'status'], 'pending'),
      paymentStatus: s(['paymentStatus', 'payment_status'], 'unpaid'),
      paymentMethod: s(['paymentMethod', 'payment_method']),
      paymentIntentId: (data['paymentIntentId'] ?? data['payment_intent_id'])?.toString(),
      transactionId: s(['transactionId', 'transaction_id']),
      paidAt: ts(data['paidAt'] ?? data['paid_at']),
      seatIndexes: parseSeatIndexes(data['seatIndexes'] ?? data['seat_indexes']),
      seatNumber: (data['seatNumber'] ?? data['seat_number']) is num
          ? (data['seatNumber'] ?? data['seat_number']).toInt()
          : null,
      reservedUntil: reservedTimestamp,
      notes: data['notes']?.toString(),
      canceledAt: ts(data['canceledAt'] ?? data['canceled_at']),
      createdAt: ts(data['createdAt'] ?? data['created_at']),
      updatedAt: ts(data['updatedAt'] ?? data['updated_at']),
      bookingService: s(['BookingService', 'bookingService']),
      pdfService: s(['PdfService', 'pdfService']),
    );
  }

  Booking copyWith({
    String? id,
    String? tripId,
    String? passengerId,
    String? passengerNickname,
    String? driverId,
    double? amountPaid,
    double? totalPrice,
    int? bookedSeatsCount,
    bool? isFamilyBooking,
    int? childrenCount,
    String? bookingStatus,
    String? paymentStatus,
    String? paymentMethod,
    String? paymentIntentId,
    String? transactionId,
    Timestamp? paidAt,
    List<int>? seatIndexes,
    int? seatNumber,
    Timestamp? reservedUntil,
    String? notes,
    Timestamp? canceledAt,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? bookingService,
    String? pdfService,
  }) {
    return Booking(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      passengerId: passengerId ?? this.passengerId,
      passengerNickname: passengerNickname ?? this.passengerNickname,
      driverId: driverId ?? this.driverId,
      amountPaid: amountPaid ?? this.amountPaid,
      totalPrice: totalPrice ?? this.totalPrice,
      bookedSeatsCount: bookedSeatsCount ?? this.bookedSeatsCount,
      isFamilyBooking: isFamilyBooking ?? this.isFamilyBooking,
      childrenCount: childrenCount ?? this.childrenCount,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      transactionId: transactionId ?? this.transactionId,
      paidAt: paidAt ?? this.paidAt,
      seatIndexes: seatIndexes ?? this.seatIndexes,
      seatNumber: seatNumber ?? this.seatNumber,
      reservedUntil: reservedUntil ?? this.reservedUntil,
      notes: notes ?? this.notes,
      canceledAt: canceledAt ?? this.canceledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bookingService: bookingService ?? this.bookingService,
      pdfService: pdfService ?? this.pdfService,
    );
  }

  @override
  String toString() {
    return 'Booking(id: $id, tripId: $tripId, passengerId: $passengerId, seats: $bookedSeatsCount, total: $totalPrice, status: $bookingStatus)';
  }
}
