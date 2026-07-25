// lib/models/agency.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج Agency موحّد وآمن للقراءة والكتابة إلى Firestore.
class Agency {
  final String id;
  final String agencyName;
  final String managerName;
  final dynamic location; // GeoPoint أو Map أو null
  final String mobileNumber;
  final double walletBalance;
  final bool isActive;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  Agency({
    required this.id,
    this.agencyName = '',
    this.managerName = '',
    this.location,
    this.mobileNumber = '',
    this.walletBalance = 0.0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// قراءة من خريطة (مثلاً من DocumentSnapshot.data())
  factory Agency.fromMap(String id, Map<String, dynamic>? data) {
    final d = data ?? <String, dynamic>{};

    dynamic parseLocation(dynamic v) {
      if (v == null) return null;
      if (v is GeoPoint) return v;
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return v;
    }

    Timestamp? parseTs(dynamic v) {
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

    double toDoubleSafe(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return Agency(
      id: id,
      agencyName: (d['agencyName'] ?? '') as String,
      managerName: (d['managerName'] ?? '') as String,
      location: parseLocation(d['location']),
      mobileNumber: (d['mobileNumber'] ?? '') as String,
      walletBalance: toDoubleSafe(d['walletBalance']),
      isActive: d['isActive'] is bool ? d['isActive'] as bool : (d['isActive'] == null ? true : d['isActive'].toString().toLowerCase() == 'true'),
      createdAt: parseTs(d['createdAt']),
      updatedAt: parseTs(d['updatedAt']),
    );
  }

  /// إنشاء من DocumentSnapshot
  factory Agency.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    return Agency.fromMap(doc.id, data);
  }

  /// تحويل إلى Map للحفظ في Firestore
  Map<String, dynamic> toMap() {
    return {
      'agencyName': agencyName,
      'managerName': managerName,
      'location': location,
      'mobileNumber': mobileNumber,
      'walletBalance': walletBalance,
      'isActive': isActive,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    }..removeWhere((k, v) => v == null);
  }

  Agency copyWith({
    String? agencyName,
    String? managerName,
    dynamic location,
    String? mobileNumber,
    double? walletBalance,
    bool? isActive,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return Agency(
      id: id,
      agencyName: agencyName ?? this.agencyName,
      managerName: managerName ?? this.managerName,
      location: location ?? this.location,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      walletBalance: walletBalance ?? this.walletBalance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Agency(id: $id, name: $agencyName, manager: $managerName, active: $isActive, wallet: $walletBalance)';
  }
}
