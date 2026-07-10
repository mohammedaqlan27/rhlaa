// lib/models/agency.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Agency {
  final String id;
  final String agencyName;
  final String managerName;
  final dynamic location; // GeoPoint أو String
  final String mobileNumber;
  final double walletBalance;
  final bool isActive;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  Agency({
    required this.id,
    required this.agencyName,
    required this.managerName,
    this.location,
    required this.mobileNumber,
    required this.walletBalance,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory Agency.fromMap(String id, Map<String, dynamic> data) {
    return Agency(
      id: id,
      agencyName: (data['agencyName'] ?? '') as String,
      managerName: (data['managerName'] ?? '') as String,
      location: data['location'],
      mobileNumber: (data['mobileNumber'] ?? '') as String,
      walletBalance: _toDoubleSafe(data['walletBalance']),
      isActive: (data['isActive'] ?? true) as bool,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
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
      'walletBalance': walletBalance,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
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

  Agency copyWith({
    String? agencyName,
    String? managerName,
    dynamic location,
    String? mobileNumber,
    double? walletBalance,
    bool? isActive,
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
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
