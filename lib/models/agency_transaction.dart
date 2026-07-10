// lib/models/agency_transaction.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory AgencyTransaction.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    return AgencyTransaction(
      id: doc.id,
      agencyId: (data['agencyId'] ?? '') as String,
      amount: _toDoubleSafe(data['amount']),
      type: (data['type'] ?? '') as String,
      reason: data['reason'] as String?,
      performedBy: data['performedBy'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'agencyId': agencyId,
      'amount': amount,
      'type': type,
      'reason': reason,
      'performedBy': performedBy,
      'createdAt': createdAt,
    };
  }

  static double _toDoubleSafe(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
