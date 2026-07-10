import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  // 1. التعريف الأساسي
  final String id; // معرف المستند في Firestore
  final String uid; // معرف المستخدم (FirebaseAuth UID)
  final String nickname;
  final String email;
  final String userType; // driver أو passenger
  final String? profilePictureUrl;
  final String? mobileNumber;
  final double averageRating;
  final int ratingCount;
  final Timestamp? createdAt;

  // 2. بيانات الأسرة / الراكب
  final bool familyStatus;
  final int childrenCount;

  // 3. بيانات التحقق والهوية
  final bool isIdVerified;
  final String? fullNameId;
  final String? idNumber;
  final String? idType;
  final String? idIssueLocation;
  final DateTime? idIssueDate;
  final DateTime? idExpiryDate;
  final Map<String, String>? documents;

  // 4. بيانات السائق والمركبة
  final List<String> vehicleIds;
  final String? drivingLicenseNumber;
  final String? driverNotes;
  final String? carPlateNumber;
  final String? carOwnerOfficialName;

  AppUser({
    required this.id,
    required this.uid,
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
    this.documents,
    this.vehicleIds = const [],
    this.drivingLicenseNumber,
    this.driverNotes,
    this.carPlateNumber,
    this.carOwnerOfficialName,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nickname': nickname,
      'email': email,
      'userType': userType.toLowerCase(),
      'profilePictureUrl': profilePictureUrl,
      'mobileNumber': mobileNumber,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'familyStatus': familyStatus,
      'childrenCount': childrenCount,
      'isIdVerified': isIdVerified,
      'fullNameId': fullNameId,
      'idNumber': idNumber,
      'idType': idType,
      'idIssueLocation': idIssueLocation,
      'idIssueDate': idIssueDate != null ? Timestamp.fromDate(idIssueDate!) : null,
      'idExpiryDate': idExpiryDate != null ? Timestamp.fromDate(idExpiryDate!) : null,
      'documents': documents,
      'vehicleIds': vehicleIds,
      'drivingLicenseNumber': drivingLicenseNumber,
      'driverNotes': driverNotes,
      'carPlateNumber': carPlateNumber,
      'carOwnerOfficialName': carOwnerOfficialName,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory AppUser.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return AppUser(
      id: doc.id,
      uid: data['uid'] ?? doc.id,
      nickname: data['nickname'] ?? '',
      email: data['email'] ?? '',
      userType: (data['userType'] ?? 'passenger').toString().toLowerCase(),
      profilePictureUrl: data['profilePictureUrl'],
      mobileNumber: data['mobileNumber'],
      averageRating: (data['averageRating'] is num) ? (data['averageRating'] as num).toDouble() : 0.0,
      ratingCount: (data['ratingCount'] is num) ? (data['ratingCount'] as num).toInt() : 0,
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
      familyStatus: data['familyStatus'] ?? false,
      childrenCount: (data['childrenCount'] is num) ? (data['childrenCount'] as num).toInt() : 0,
      isIdVerified: data['isIdVerified'] ?? false,
      fullNameId: data['fullNameId'],
      idNumber: data['idNumber'],
      idType: data['idType'],
      idIssueLocation: data['idIssueLocation'],
      idIssueDate: data['idIssueDate'] is Timestamp ? (data['idIssueDate'] as Timestamp).toDate() : null,
      idExpiryDate: data['idExpiryDate'] is Timestamp ? (data['idExpiryDate'] as Timestamp).toDate() : null,
      documents: data['documents'] != null ? Map<String, String>.from(data['documents']) : null,
      vehicleIds: data['vehicleIds'] != null ? List<String>.from(data['vehicleIds']) : [],
      drivingLicenseNumber: data['drivingLicenseNumber'],
      driverNotes: data['driverNotes'],
      carPlateNumber: data['carPlateNumber'],
      carOwnerOfficialName: data['carOwnerOfficialName'],
    );
  }

  bool get isDriver => userType == 'driver';
  bool get isPassenger => userType == 'passenger';
}
