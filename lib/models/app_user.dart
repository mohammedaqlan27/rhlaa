import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  // 1. التعريف الأساسي
  final String id;
  final String uid;
  final String name;
  final String nickname;
  final String email;
  final String userType;
  final String? profilePictureUrl;
  final String? mobileNumber;
  final double averageRating;
  final int ratingCount;
  final Timestamp? createdAt;

  // 2. بيانات الراكب / الأسرة
  final bool familyStatus;
  final int childrenCount; // سيتم تحويلها من double إلى int عند القراءة

  // 3. بيانات التحقق والهوية
  final bool isIdVerified;
  final String? fullNameId;
  final String? idNumber;
  final String? idType;
  final String? idIssueLocation;
  final DateTime? idIssueDate;
  final DateTime? idExpiryDate;
  final String? identityCardUrl;
  final Map<String, String>? documents;

  // 4. بيانات السائق والمركبة
  final List<String> vehicleIds;
  final String? drivingLicenseNumber;
  final String? driverNotes;
  final String? plateNumber;
  final String? carOwnerOfficialName;

  AppUser({
    required this.id,
    required this.uid,
    required this.name,
    required this.nickname,
    required this.email,
    required this.userType,
    this.profilePictureUrl,
    this.mobileNumber,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.createdAt,
    this.familyStatus = false,
    this.childrenCount = 0,
    this.isIdVerified = false,
    this.fullNameId,
    this.idNumber,
    this.idType,
    this.idIssueLocation,
    this.idIssueDate,
    this.idExpiryDate,
    this.identityCardUrl,
    this.documents,
    this.vehicleIds = const [],
    this.drivingLicenseNumber,
    this.driverNotes,
    this.plateNumber,
    this.carOwnerOfficialName,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'nickname': nickname,
      'email': email,
      'userType': userType.toLowerCase(),
      'profilePictureUrl': profilePictureUrl,
      'mobileNumber': mobileNumber,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'familyStatus': familyStatus,
      'childrenCount': childrenCount.toDouble(), // نرسلها double كما هي في Firestore
      'isIdVerified': isIdVerified,
      'fullNameId': fullNameId,
      'idNumber': idNumber,
      'idType': idType,
      'idIssueLocation': idIssueLocation,
      'idIssueDate': idIssueDate != null ? Timestamp.fromDate(idIssueDate!) : null,
      'idExpiryDate': idExpiryDate != null ? Timestamp.fromDate(idExpiryDate!) : null,
      'identityCardUrl': identityCardUrl,
      'documents': documents,
      'vehicleIds': vehicleIds,
      'drivingLicenseNumber': drivingLicenseNumber,
      'driverNotes': driverNotes,
      'plateNumber': plateNumber,
      'carOwnerOfficialName': carOwnerOfficialName,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory AppUser.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String? _s(List<String> keys) {
      for (var k in keys) {
        if (data[k] != null && data[k].toString().isNotEmpty) return data[k].toString();
      }
      return null;
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

    DateTime? _dt(List<String> keys) {
      for (var k in keys) {
        var v = data[k];
        if (v is Timestamp) return v.toDate();
        if (v is String) return DateTime.tryParse(v);
      }
      return null;
    }

    return AppUser(
      id: doc.id,
      uid: _s(['uid', 'Id']) ?? doc.id,
      name: _s(['name', 'fullName']) ?? '',
      nickname: _s(['nickname', 'displayName']) ?? '',
      email: _s(['email']) ?? '',
      userType: _s(['userType', 'user_type'])?.toLowerCase() ?? 'passenger',
      profilePictureUrl: _s(['profilePictureUrl']),
      mobileNumber: _s(['mobileNumber']),
      averageRating: _d(['averageRating']),
      ratingCount: _i(['ratingCount']),
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
      familyStatus: _b(['familyStatus']),
      childrenCount: _i(['childrenCount']),
      isIdVerified: _b(['isIdVerified']),
      fullNameId: _s(['fullNameId']),
      idNumber: _s(['idNumber']),
      idType: _s(['idType']),
      idIssueLocation: _s(['idIssueLocation']),
      idIssueDate: _dt(['idIssueDate']),
      idExpiryDate: _dt(['idExpiryDate']),
      identityCardUrl: _s(['identityCardUrl']),
      documents: data['documents'] != null ? Map<String, String>.from(data['documents']) : null,
      vehicleIds: data['vehicleIds'] != null ? List<String>.from(data['vehicleIds']) : [],
      drivingLicenseNumber: _s(['drivingLicenseNumber']),
      driverNotes: _s(['driverNotes']),
      plateNumber: _s(['plateNumber']),
      carOwnerOfficialName: _s(['carOwnerOfficialName']),
    );
  }

  bool get isDriver => userType.toLowerCase() == 'driver';
  bool get isPassenger => userType.toLowerCase() == 'passenger';
}