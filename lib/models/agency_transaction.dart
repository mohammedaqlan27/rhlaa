// lib/models/agency_transaction.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج AgencyTransaction موحّد وآمن للقراءة والكتابة إلى Firestore.
class AgencyTransaction {
  final String id;
  final String agencyId;
  final double amount;
  final String type; // 'credit' or 'debit'
  final String? reason;
  final String? performedBy;
  final Timestamp createdAt;

  AgencyTransaction({
    required this.id,
    required this.agencyId,
    required this.amount,
    required this.type,
    this.reason,
    this.performedBy,
    required this.createdAt,
  });

  /// قراءة من DocumentSnapshot مع تحويل آمن للأنواع
  factory AgencyTransaction.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

    double toDoubleSafe(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    String s(List<String> keys, [String fallback = '']) {
      for (var k in keys) {
        final v = data[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    Timestamp parseTs(dynamic v) {
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
      return Timestamp.now();
    }

    return AgencyTransaction(
      id: doc.id,
      agencyId: s(['agencyId', 'agency_id', 'agency']),
      amount: toDoubleSafe(data['amount'] ?? data['value'] ?? 0),
      type: s(['type']),
      reason: (data['reason'] != null && data['reason'].toString().isNotEmpty) ? data['reason'].toString() : null,
      performedBy: (data['performedBy'] != null && data['performedBy'].toString().isNotEmpty) ? data['performedBy'].toString() : null,
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : parseTs(data['createdAt']),
    );
  }

  /// تحويل الكائن إلى Map للحفظ في Firestore
  Map<String, dynamic> toMap() {
    return {
      'agencyId': agencyId,
      'amount': amount,
      'type': type,
      'reason': reason,
      'performedBy': performedBy,
      'createdAt': createdAt,
    }..removeWhere((k, v) => v == null);
  }

  AgencyTransaction copyWith({
    String? id,
    String? agencyId,
    double? amount,
    String? type,
    String? reason,
    String? performedBy,
    Timestamp? createdAt,
  }) {
    return AgencyTransaction(
      id: id ?? this.id,
      agencyId: agencyId ?? this.agencyId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      performedBy: performedBy ?? this.performedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'AgencyTransaction(id: $id, agencyId: $agencyId, amount: $amount, type: $type, performedBy: ${performedBy ?? 'N/A'})';
  }
}
