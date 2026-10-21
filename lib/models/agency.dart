// lib/models/agency.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Agency {
  final String id;
  final String agencyName;
  final String managerName;
  final dynamic location;
  final String mobileNumber;
  final String? email;
  final String? authUid; // الربط مع Firebase Auth
  final double walletBalance;
  final bool isActive;
  final String? searchKey;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  Agency({
    required this.id,
    this.agencyName = '',
    this.managerName = '',
    this.location,
    this.mobileNumber = '',
    this.email,
    this.authUid,
    this.walletBalance = 0.0,
    this.isActive = true,
    this.searchKey,
    this.createdAt,
    this.updatedAt,
  });

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
      email: d['email'] as String?,
      authUid: d['authUid'] as String?,
      walletBalance: toDoubleSafe(d['walletBalance']),
      isActive: d['isActive'] is bool ? d['isActive'] as bool : (d['isActive'] == null ? true : d['isActive'].toString().toLowerCase() == 'true'),
      searchKey: d['searchKey'] as String?,
      createdAt: parseTs(d['createdAt']),
      updatedAt: parseTs(d['updatedAt']),
    );
  }

  factory Agency.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    return Agency.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'agencyName': agencyName,
      'managerName': managerName,
      'location': location,
      'mobileNumber': mobileNumber,
      'email': email ?? '',
      'authUid': authUid ?? '',
      'walletBalance': walletBalance,
      'isActive': isActive,
      'searchKey': searchKey ?? agencyName.toLowerCase(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    }..removeWhere((k, v) => v == null || (v is String && v.isEmpty && (k == 'email' || k == 'authUid')));
  }

  Agency copyWith({
    String? agencyName,
    String? managerName,
    dynamic location,
    String? mobileNumber,
    String? email,
    String? authUid,
    double? walletBalance,
    bool? isActive,
    String? searchKey,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return Agency(
      id: id,
      agencyName: agencyName ?? this.agencyName,
      managerName: managerName ?? this.managerName,
      location: location ?? this.location,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      authUid: authUid ?? this.authUid,
      walletBalance: walletBalance ?? this.walletBalance,
      isActive: isActive ?? this.isActive,
      searchKey: searchKey ?? this.searchKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Agency(id: $id, name: $agencyName, manager: $managerName, active: $isActive, wallet: $walletBalance)';
  }
}
