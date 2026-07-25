import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  // 1. التعريف الأساسي
  final String id; // معرف المستند في Firestore
  final String uid; // معرف المستخدم (FirebaseAuth UID)
  final String name;
  final String nickname;
  final String email;
  final String userType; // driver أو passenger أو agency
  final String? profilePictureUrl;
  final String? mobileNumber;
  final double averageRating;
  final int ratingCount;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  // 2. بيانات الأسرة / الراكب
  final bool familyStatus;
  final int childrenCount;

  // 3. بيانات التحقق والهوية
  final bool isIdVerified;
  final String? idNumber;
  final String? identityCardUrl;
  final Map<String, dynamic>? documents;

  // 4. بيانات السائق والمركبة
  final bool isDriver;
  final bool isActiveDriver;
  final String? drivingLicenseNumber;
  final String? driverNotes;
  final String? plateNumber;
  final String? carOwnerOfficialName;
  final List<String> vehicleIds;

  // 5. بيانات المكتب/الوكالة
  final String? agencyName;
  final bool agencyVerified;
  final List<String> agencyVehicles;

  // 6. بيانات إضافية
  final double walletBalance;

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
    this.updatedAt,
    this.familyStatus = false,
    this.childrenCount = 0,
    this.isIdVerified = false,
    this.idNumber,
    this.identityCardUrl,
    this.documents,
    this.isDriver = false,
    this.isActiveDriver = false,
    this.drivingLicenseNumber,
    this.driverNotes,
    this.plateNumber,
    this.carOwnerOfficialName,
    this.vehicleIds = const [],
    this.agencyName,
    this.agencyVerified = false,
    this.agencyVehicles = const [],
    this.walletBalance = 0.0,
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
      'childrenCount': childrenCount,
      'isIdVerified': isIdVerified,
      'idNumber': idNumber,
      'identityCardUrl': identityCardUrl,
      'documents': documents,
      'isDriver': isDriver,
      'isActiveDriver': isActiveDriver,
      'drivingLicenseNumber': drivingLicenseNumber,
      'driverNotes': driverNotes,
      'plateNumber': plateNumber,
      'carOwnerOfficialName': carOwnerOfficialName,
      'vehicleIds': vehicleIds,
      'agencyName': agencyName,
      'agencyVerified': agencyVerified,
      'agencyVehicles': agencyVehicles,
      'walletBalance': walletBalance,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory AppUser.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return AppUser(
      id: doc.id,
      uid: data['uid'] ?? doc.id,
      name: data['name'] ?? '',
      nickname: data['nickname'] ?? '',
      email: data['email'] ?? '',
      userType: (data['userType'] ?? 'passenger').toString().toLowerCase(),
      profilePictureUrl: data['profilePictureUrl'],
      mobileNumber: data['mobileNumber'],
      averageRating: (data['averageRating'] is num) ? (data['averageRating'] as num).toDouble() : 0.0,
      ratingCount: (data['ratingCount'] is num) ? (data['ratingCount'] as num).toInt() : 0,
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] : null,
      familyStatus: data['familyStatus'] ?? false,
      childrenCount: (data['childrenCount'] is num)
          ? (data['childrenCount'] as num).toInt()
          : int.tryParse(data['childrenCount']?.toString() ?? '0') ?? 0,
      isIdVerified: data['isIdVerified'] ?? false,
      idNumber: data['idNumber'],
      identityCardUrl: data['identityCardUrl'],
      documents: data['documents'],
      isDriver: data['isDriver'] ?? false,
      isActiveDriver: data['isActiveDriver'] ?? false,
      drivingLicenseNumber: data['drivingLicenseNumber'],
      driverNotes: data['driverNotes'],
      plateNumber: data['plateNumber'] ?? data['carPlateNumber'],
      carOwnerOfficialName: data['carOwnerOfficialName'],
      vehicleIds: data['vehicleIds'] != null ? List<String>.from(data['vehicleIds']) : [],
      agencyName: data['agencyName'],
      agencyVerified: data['agencyVerified'] ?? false,
      agencyVehicles: data['agencyVehicles'] != null ? List<String>.from(data['agencyVehicles']) : [],
      walletBalance: (data['walletBalance'] is num) ? (data['walletBalance'] as num).toDouble() : 0.0,
    );
  }

  bool get isPassenger => userType == 'passenger';
  bool get isAgency => userType == 'agency';
}
