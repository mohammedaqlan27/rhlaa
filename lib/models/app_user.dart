// lib/models/app_user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  // 1. التعريف الأساسي
  final String id; // معرف المستند في Firestore
  final String uid; // معرف المستخدم (FirebaseAuth UID)
  final String name;
  final String nickname;
  final String email;
  final String userType; // driver أو passenger أو agency أو admin أو security
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
  final String? agencyStatus; // مستقل، تابع لمكتب، إلخ
  final List<String> vehicleIds;

  // 5. بيانات المكتب/الوكالة
  final String? agencyName;
  final bool agencyVerified;
  final List<String> agencyVehicles;
  final String? agencyId; // ربط صريح إلى مستند المكتب (مهم)

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
    this.agencyStatus,
    this.vehicleIds = const [],
    this.agencyName,
    this.agencyVerified = false,
    this.agencyVehicles = const [],
    this.agencyId,
    this.walletBalance = 0.0,
  });

  /// تحويل الكائن إلى Map لتخزينه في Firestore
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
      'agencyStatus': agencyStatus,
      'vehicleIds': vehicleIds,
      'agencyName': agencyName,
      'agencyVerified': agencyVerified,
      'agencyVehicles': agencyVehicles,
      'agencyId': agencyId,
      'walletBalance': walletBalance,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    }..removeWhere((k, v) => v == null);
  }

  /// خريطة خاصة بإنشاء المستخدم لأول مرة
  Map<String, dynamic> toCreateMap() {
    final map = toMap();
    if (map['createdAt'] == null) map['createdAt'] = FieldValue.serverTimestamp();
    if (map['updatedAt'] == null) map['updatedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  /// خريطة خاصة بالتحديث
  Map<String, dynamic> toUpdateMap() {
    final map = toMap();
    map.remove('createdAt');
    map.remove('uid');
    map.remove('walletBalance');
    map['updatedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  /// copyWith لتسهيل التعديلات الجزئية
  AppUser copyWith({
    String? id,
    String? uid,
    String? name,
    String? nickname,
    String? email,
    String? userType,
    String? profilePictureUrl,
    String? mobileNumber,
    double? averageRating,
    int? ratingCount,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    bool? familyStatus,
    int? childrenCount,
    bool? isIdVerified,
    String? idNumber,
    String? identityCardUrl,
    Map<String, dynamic>? documents,
    bool? isDriver,
    bool? isActiveDriver,
    String? drivingLicenseNumber,
    String? driverNotes,
    String? plateNumber,
    String? carOwnerOfficialName,
    String? agencyStatus,
    List<String>? vehicleIds,
    String? agencyName,
    bool? agencyVerified,
    List<String>? agencyVehicles,
    String? agencyId,
    double? walletBalance,
  }) {
    return AppUser(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      familyStatus: familyStatus ?? this.familyStatus,
      childrenCount: childrenCount ?? this.childrenCount,
      isIdVerified: isIdVerified ?? this.isIdVerified,
      idNumber: idNumber ?? this.idNumber,
      identityCardUrl: identityCardUrl ?? this.identityCardUrl,
      documents: documents ?? this.documents,
      isDriver: isDriver ?? this.isDriver,
      isActiveDriver: isActiveDriver ?? this.isActiveDriver,
      drivingLicenseNumber: drivingLicenseNumber ?? this.drivingLicenseNumber,
      driverNotes: driverNotes ?? this.driverNotes,
      plateNumber: plateNumber ?? this.plateNumber,
      carOwnerOfficialName: carOwnerOfficialName ?? this.carOwnerOfficialName,
      agencyStatus: agencyStatus ?? this.agencyStatus,
      vehicleIds: vehicleIds ?? this.vehicleIds,
      agencyName: agencyName ?? this.agencyName,
      agencyVerified: agencyVerified ?? this.agencyVerified,
      agencyVehicles: agencyVehicles ?? this.agencyVehicles,
      agencyId: agencyId ?? this.agencyId,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }

  /// بناء الكائن من مستند Firestore
  factory AppUser.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    Timestamp? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v;
      if (v is DateTime) return Timestamp.fromDate(v);
      if (v is int) return Timestamp.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return Timestamp.fromDate(parsed);
      }
      return null;
    }

    return AppUser(
      id: doc.id,
      uid: (data['uid'] ?? doc.id) as String,
      name: (data['name'] ?? data['displayName'] ?? '') as String,
      nickname: (data['nickname'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      userType: (data['userType'] ?? data['role'] ?? 'passenger').toString().toLowerCase(),
      profilePictureUrl: data['profilePictureUrl'] as String?,
      mobileNumber: data['mobileNumber'] as String?,
      averageRating: (data['averageRating'] is num) ? (data['averageRating'] as num).toDouble() : 0.0,
      ratingCount: (data['ratingCount'] is num) ? (data['ratingCount'] as num).toInt() : 0,
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
      familyStatus: data['familyStatus'] ?? false,
      childrenCount: data['childrenCount'] is int
          ? data['childrenCount']
          : int.tryParse(data['childrenCount']?.toString() ?? '0') ?? 0,
      isIdVerified: data['isIdVerified'] ?? false,
      idNumber: data['idNumber'] as String?,
      identityCardUrl: data['identityCardUrl'] as String?,
      documents: data['documents'] != null ? Map<String, dynamic>.from(data['documents']) : null,
      isDriver: data['isDriver'] ?? false,
      isActiveDriver: data['isActiveDriver'] ?? false,
      drivingLicenseNumber: data['drivingLicenseNumber'] as String?,
      driverNotes: data['driverNotes'] as String?,
      plateNumber: data['plateNumber'] ?? data['carPlateNumber'] as String?,
      carOwnerOfficialName: data['carOwnerOfficialName'] as String?,
      agencyStatus: data['agencyStatus'] as String?,
      vehicleIds: data['vehicleIds'] != null ? List<String>.from(data['vehicleIds']) : [],
      agencyName: data['agencyName'] as String?,
      agencyVerified: data['agencyVerified'] ?? false,
      agencyVehicles: data['agencyVehicles'] != null ? List<String>.from(data['agencyVehicles']) : [],
      agencyId: data['agencyId'] as String?,
      walletBalance: (data['walletBalance'] is num) ? (data['walletBalance'] as num).toDouble() : 0.0,
    );
  }

  // اختصارات مفيدة للأدوار
  bool get isPassenger => userType.contains('passenger');
  bool get isDriverRole => userType.contains('driver') || isDriver;
  bool get isAgency => userType.contains('agency');
  bool get isAdmin => userType.contains('admin');
  bool get isSecurity => userType.contains('security');
}
