// lib/models/payment.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج Payment موحّد وآمن للقراءة والكتابة إلى Firestore.
/// يتعامل مع اختلاف أسماء الحقول وأنواعها (String, num, Timestamp, Map).
class Payment {
  final String id;
  final String? agencyId;
  final double amount;
  final double amountPaid;
  final String currency;
  final String bookingId;
  final String driverId;
  final String passengerId;

  // عمولات وتقسيمات
  final double appCommissionRate;
  final double appCommissionAmount;
  final double agencyCommissionRate;
  final double agencyCommissionAmount;
  final double driverNetAmount;
  final double platformReceives;
  final double govFee;
  final String? govFeePaidBy;
  final double roundingDelta;

  // بوابة الدفع وبيانات مزود الدفع الخام
  final Map<String, dynamic>? gatewayResponse;
  final Map<String, dynamic>? rawProvider;
  final String? rawProviderResponse;

  // تفاصيل التقسيم (split) ونتيجة الحساب (CommissionResult)
  final Map<String, dynamic>? split;
  final Map<String, dynamic>? commissionResult;

  // حالة الدفع والبيانات الزمنية
  final String paymentMethod;
  final String paymentStatus;
  final String? transactionId;
  final Timestamp? createdAt;
  final Timestamp? calculatedAt;
  final Timestamp? refundedAt;
  final Timestamp? updatedAt;

  // ملاحظات وحقل عام
  final String? notes;
  final String? refundReason;
  final String? status;
  final double totalAmount;

  Payment({
    required this.id,
    this.agencyId,
    this.amount = 0.0,
    this.amountPaid = 0.0,
    this.currency = 'YER',
    this.bookingId = '',
    this.driverId = '',
    this.passengerId = '',
    this.appCommissionRate = 0.0,
    this.appCommissionAmount = 0.0,
    this.agencyCommissionRate = 0.0,
    this.agencyCommissionAmount = 0.0,
    this.driverNetAmount = 0.0,
    this.platformReceives = 0.0,
    this.govFee = 0.0,
    this.govFeePaidBy,
    this.roundingDelta = 0.0,
    this.gatewayResponse,
    this.rawProvider,
    this.rawProviderResponse,
    this.split,
    this.commissionResult,
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.transactionId,
    this.createdAt,
    this.calculatedAt,
    this.refundedAt,
    this.updatedAt,
    this.notes,
    this.refundReason,
    this.status,
    this.totalAmount = 0.0,
  });

  // =========================
  // Helpers
  // =========================
  static double _toDoubleSafe(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static Map<String, dynamic>? _toMapSafe(dynamic v) {
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
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Timestamp? _toTimestampSafe(dynamic v) {
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

  // =========================
  // Factory: from Firestore doc
  // =========================
  factory Payment.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String s(List<String> keys, [String fallback = '']) {
      for (final k in keys) {
        final v = data[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    return Payment(
      id: doc.id,
      agencyId: s(['agencyId', 'agency_id', 'agency']).isNotEmpty ? s(['agencyId', 'agency_id', 'agency']) : null,
      amount: _toDoubleSafe(data['amount'] ?? data['totalAmount'] ?? data['total_amount']),
      amountPaid: _toDoubleSafe(data['amountPaid'] ?? data['amount_paid']),
      currency: s(['currency', 'curr']),
      bookingId: s(['bookingId', 'booking_id']),
      driverId: s(['driverId', 'driver_id']),
      passengerId: s(['passengerId', 'passenger_id']),
      appCommissionRate: _toDoubleSafe(data['appCommissionRate'] ?? data['app_commission_rate'] ?? data['appCommission']),
      appCommissionAmount: _toDoubleSafe(data['appCommissionAmount'] ?? data['app_commission_amount'] ?? data['appCommissionAmount']),
      agencyCommissionRate: _toDoubleSafe(data['agencyCommissionRate'] ?? data['agency_commission_rate']),
      agencyCommissionAmount: _toDoubleSafe(data['agencyCommissionAmount'] ?? data['agency_commission_amount']),
      driverNetAmount: _toDoubleSafe(data['driverNetAmount'] ?? data['driver_net_amount'] ?? data['driverNet']),
      platformReceives: _toDoubleSafe(data['platformReceives'] ?? data['platform_receives']),
      govFee: _toDoubleSafe(data['govFee'] ?? data['gov_fee']),
      govFeePaidBy: s(['govFeePaidBy', 'gov_fee_paid_by']),
      roundingDelta: _toDoubleSafe(data['roundingDelta'] ?? data['rounding_delta']),
      gatewayResponse: _toMapSafe(data['gatewayResponse'] ?? data['gateway_response'] ?? data['gateway']),
      rawProvider: _toMapSafe(data['rawProvider'] ?? data['raw_provider']),
      rawProviderResponse: s(['rawProviderResponse', 'raw_provider_response']),
      split: _toMapSafe(data['split']),
      commissionResult: _toMapSafe(data['CommissionResult'] ?? data['commissionResult'] ?? data['commission_result']),
      paymentMethod: s(['paymentMethod', 'payment_method']),
      paymentStatus: s(['paymentStatus', 'payment_status']),
      transactionId: s(['transactionId', 'transaction_id']),
      createdAt: _toTimestampSafe(data['createdAt'] ?? data['created_at']),
      calculatedAt: _toTimestampSafe(data['calculatedAt'] ?? data['calculated_at']),
      refundedAt: _toTimestampSafe(data['refundedAt'] ?? data['refunded_at']),
      updatedAt: _toTimestampSafe(data['updatedAt'] ?? data['updated_at']),
      notes: data['notes']?.toString(),
      refundReason: data['refundReason']?.toString(),
      status: s(['status']),
      totalAmount: _toDoubleSafe(data['totalAmount'] ?? data['total_amount']),
    );
  }

  // =========================
  // Convert to Map for Firestore
  // =========================
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'agencyId': agencyId,
      'amount': amount,
      'amountPaid': amountPaid,
      'currency': currency,
      'bookingId': bookingId,
      'driverId': driverId,
      'passengerId': passengerId,
      'appCommissionRate': appCommissionRate,
      'appCommissionAmount': appCommissionAmount,
      'agencyCommissionRate': agencyCommissionRate,
      'agencyCommissionAmount': agencyCommissionAmount,
      'driverNetAmount': driverNetAmount,
      'platformReceives': platformReceives,
      'govFee': govFee,
      'govFeePaidBy': govFeePaidBy,
      'roundingDelta': roundingDelta,
      'gatewayResponse': gatewayResponse,
      'rawProvider': rawProvider,
      'rawProviderResponse': rawProviderResponse,
      'split': split,
      'CommissionResult': commissionResult,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'transactionId': transactionId,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'calculatedAt': calculatedAt,
      'refundedAt': refundedAt,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'notes': notes,
      'refundReason': refundReason,
      'status': status,
      'totalAmount': totalAmount,
    };

    map.removeWhere((k, v) => v == null);
    return map;
  }

  // =========================
  // copyWith
  // =========================
  Payment copyWith({
    String? id,
    String? agencyId,
    double? amount,
    double? amountPaid,
    String? currency,
    String? bookingId,
    String? driverId,
    String? passengerId,
    double? appCommissionRate,
    double? appCommissionAmount,
    double? agencyCommissionRate,
    double? agencyCommissionAmount,
    double? driverNetAmount,
    double? platformReceives,
    double? govFee,
    String? govFeePaidBy,
    double? roundingDelta,
    Map<String, dynamic>? gatewayResponse,
    Map<String, dynamic>? rawProvider,
    String? rawProviderResponse,
    Map<String, dynamic>? split,
    Map<String, dynamic>? commissionResult,
    String? paymentMethod,
    String? paymentStatus,
    String? transactionId,
    Timestamp? createdAt,
    Timestamp? calculatedAt,
    Timestamp? refundedAt,
    Timestamp? updatedAt,
    String? notes,
    String? refundReason,
    String? status,
    double? totalAmount,
  }) {
    return Payment(
      id: id ?? this.id,
      agencyId: agencyId ?? this.agencyId,
      amount: amount ?? this.amount,
      amountPaid: amountPaid ?? this.amountPaid,
      currency: currency ?? this.currency,
      bookingId: bookingId ?? this.bookingId,
      driverId: driverId ?? this.driverId,
      passengerId: passengerId ?? this.passengerId,
      appCommissionRate: appCommissionRate ?? this.appCommissionRate,
      appCommissionAmount: appCommissionAmount ?? this.appCommissionAmount,
      agencyCommissionRate: agencyCommissionRate ?? this.agencyCommissionRate,
      agencyCommissionAmount: agencyCommissionAmount ?? this.agencyCommissionAmount,
      driverNetAmount: driverNetAmount ?? this.driverNetAmount,
      platformReceives: platformReceives ?? this.platformReceives,
      govFee: govFee ?? this.govFee,
      govFeePaidBy: govFeePaidBy ?? this.govFeePaidBy,
      roundingDelta: roundingDelta ?? this.roundingDelta,
      gatewayResponse: gatewayResponse ?? this.gatewayResponse,
      rawProvider: rawProvider ?? this.rawProvider,
      rawProviderResponse: rawProviderResponse ?? this.rawProviderResponse,
      split: split ?? this.split,
      commissionResult: commissionResult ?? this.commissionResult,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      refundedAt: refundedAt ?? this.refundedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      refundReason: refundReason ?? this.refundReason,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

  @override
  String toString() {
    return 'Payment(id: $id, bookingId: $bookingId, amount: $amount $currency, status: $paymentStatus, tx: ${transactionId ?? 'N/A'})';
  }
}
