import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  // 1. التعريف الأساسي
  final String id;
  final String nickname;
  final String email;
  final String userType; // 'Driver' أو 'Passenger'
  final String? profilePictureUrl;
  final String? mobileNumber;
  final double averageRating;

  // 2. بيانات الأسرة
  final String? familyStatus;
  final int childrenCount;

  // 3. بيانات التحقق
  final bool isIdVerified;
  final String? fullNameId;
  final String? idNumber;
  final String? idType;
  final String? idIssueLocation;
  final DateTime? idIssueDate;
  final DateTime? idExpiryDate;
  final Map<String, String>? documents;

  // 4. بيانات السائق
  final List<String> vehicleIds;
  final String? drivingLicenseNumber;
  final String? driverNotes;

  // 5. بيانات المركبة (مضافة لتوافق CreateTripScreen)
  final String? carPlateNumber;
  final String? carOwnerOfficialName;

  // 6. النظام
  final Timestamp? createdAt;

  AppUser({
    required this.id,
    required this.nickname,
    required this.email,
    required this.userType,
    this.profilePictureUrl,
    this.mobileNumber,
    this.averageRating = 0.0,
    this.familyStatus,
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
    this.createdAt,
  });

  // بديل ذكي لإرجاع رقم الهاتف إذا تم طلبه بهذه التسمية في الواجهات القديمة
  String? get phoneNumber => mobileNumber;

  /// تحويل النموذج إلى خريطة للكتابة إلى Firestore
  Map<String, dynamic> toMap() {
    dynamic idIssueTs;
    if (idIssueDate is DateTime) idIssueTs = Timestamp.fromDate(idIssueDate!);
    else if (idIssueDate is Timestamp) idIssueTs = idIssueDate;
    else idIssueTs = null;

    dynamic idExpiryTs;
    if (idExpiryDate is DateTime) idExpiryTs = Timestamp.fromDate(idExpiryDate!);
    else if (idExpiryDate is Timestamp) idExpiryTs = idExpiryDate;
    else idExpiryTs = null;

    final map = <String, dynamic>{
      'nickname': nickname,
      'email': email,
      'userType': userType,
      'profilePictureUrl': profilePictureUrl,
      'mobileNumber': mobileNumber,
      'averageRating': averageRating,
      'familyStatus': familyStatus,
      'childrenCount': childrenCount,
      'isIdVerified': isIdVerified,
      'fullNameId': fullNameId,
      'idNumber': idNumber,
      'idType': idType,
      'idIssueLocation': idIssueLocation,
      if (idIssueTs != null) 'idIssueDate': idIssueTs,
      if (idExpiryTs != null) 'idExpiryDate': idExpiryTs,
      'documents': documents,
      'vehicleIds': vehicleIds,
      'drivingLicenseNumber': drivingLicenseNumber,
      'driverNotes': driverNotes,
      'carPlateNumber': carPlateNumber,
      'carOwnerOfficialName': carOwnerOfficialName,
      'createdAt': createdAt ?? Timestamp.now(),
    };

    // إزالة القيم الفارغة لتجنّب الكتابة بقيم غير مرغوبة
    map.removeWhere((k, v) => v == null);
    return map;
  }

  /// إنشاء نموذج من مستند Firestore
  factory AppUser.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String? _getString(List<String> keys) {
      for (final k in keys) {
        final v = data[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    int _getInt(List<String> keys, [int fallback = 0]) {
      for (final k in keys) {
        final v = data[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    double _getDouble(List<String> keys, [double fallback = 0.0]) {
      for (final k in keys) {
        final v = data[k];
        if (v is double) return v;
        if (v is num) return (v as num).toDouble();
        if (v is String) {
          final parsed = double.tryParse(v.replaceAll(',', ''));
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    bool _getBool(List<String> keys, [bool fallback = false]) {
      for (final k in keys) {
        final v = data[k];
        if (v is bool) return v;
        if (v is int) return v != 0;
        if (v is String) return v.toLowerCase() == 'true';
      }
      return fallback;
    }

    Timestamp? _getTimestamp(List<String> keys) {
      for (final k in keys) {
        final v = data[k];
        if (v is Timestamp) return v;
        if (v is DateTime) return Timestamp.fromDate(v);
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return Timestamp.fromDate(parsed);
        }
      }
      return null;
    }

    final nickname = _getString(['nickname', 'name', 'displayName']) ?? '';
    final email = _getString(['email']) ?? '';
    final userType = _getString(['userType', 'user_type']) ?? 'Passenger';
    final profilePictureUrl = _getString(['profilePictureUrl', 'profile_picture_url']);
    final mobileNumber = _getString(['mobileNumber', 'mobile_number', 'phone']);
    final averageRating = _getDouble(['averageRating', 'average_rating'], 0.0);
    final familyStatus = _getString(['familyStatus', 'family_status']);
    final childrenCount = _getInt(['childrenCount', 'children_count'], 0);
    final isIdVerified = _getBool(['isIdVerified', 'is_id_verified'], false);
    final fullNameId = _getString(['fullNameId', 'full_name_id']);
    final idNumber = _getString(['idNumber', 'id_number']);
    final idType = _getString(['idType', 'id_type']);
    final idIssueLocation = _getString(['idIssueLocation', 'id_issue_location']);
    final idIssueTs = _getTimestamp(['idIssueDate', 'id_issue_date']);
    final idExpiryTs = _getTimestamp(['idExpiryDate', 'id_expiry_date']);
    final documents = (data['documents'] is Map) ? Map<String, String>.from(data['documents'] as Map) : null;
    final vehicleIds = (data['vehicleIds'] is List)
        ? List<String>.from(data['vehicleIds'] as List)
        : (data['vehicle_ids'] is List ? List<String>.from(data['vehicle_ids'] as List) : <String>[]);
    final drivingLicenseNumber = _getString(['drivingLicenseNumber', 'driving_license_number']);
    final driverNotes = _getString(['driverNotes', 'driver_notes']);
    final carPlateNumber = _getString(['carPlateNumber', 'car_plate_number', 'plateNumber', 'plate_number']);
    final carOwnerOfficialName = _getString(['carOwnerOfficialName', 'car_owner_official_name', 'vehicleOwner', 'vehicle_owner']);
    final createdAt = _getTimestamp(['createdAt', 'created_at']);

    return AppUser(
      id: doc.id,
      nickname: nickname,
      email: email,
      userType: userType,
      profilePictureUrl: profilePictureUrl,
      mobileNumber: mobileNumber,
      averageRating: averageRating,
      familyStatus: familyStatus,
      childrenCount: childrenCount,
      isIdVerified: isIdVerified,
      fullNameId: fullNameId,
      idNumber: idNumber,
      idType: idType,
      idIssueLocation: idIssueLocation,
      idIssueDate: idIssueTs?.toDate(),
      idExpiryDate: idExpiryTs?.toDate(),
      documents: documents,
      vehicleIds: vehicleIds,
      drivingLicenseNumber: drivingLicenseNumber,
      driverNotes: driverNotes,
      carPlateNumber: carPlateNumber,
      carOwnerOfficialName: carOwnerOfficialName,
      createdAt: createdAt,
    );
  }

  AppUser copyWith({
    String? id,
    String? nickname,
    String? email,
    String? userType,
    String? profilePictureUrl,
    String? mobileNumber,
    double? averageRating,
    String? familyStatus,
    int? childrenCount,
    bool? isIdVerified,
    String? fullNameId,
    String? idNumber,
    String? idType,
    String? idIssueLocation,
    DateTime? idIssueDate,
    DateTime? idExpiryDate,
    Map<String, String>? documents,
    List<String>? vehicleIds,
    String? drivingLicenseNumber,
    String? driverNotes,
    String? carPlateNumber,
    String? carOwnerOfficialName,
    Timestamp? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      averageRating: averageRating ?? this.averageRating,
      familyStatus: familyStatus ?? this.familyStatus,
      childrenCount: childrenCount ?? this.childrenCount,
      isIdVerified: isIdVerified ?? this.isIdVerified,
      fullNameId: fullNameId ?? this.fullNameId,
      idNumber: idNumber ?? this.idNumber,
      idType: idType ?? this.idType,
      idIssueLocation: idIssueLocation ?? this.idIssueLocation,
      idIssueDate: idIssueDate ?? this.idIssueDate,
      idExpiryDate: idExpiryDate ?? this.idExpiryDate,
      documents: documents ?? this.documents,
      vehicleIds: vehicleIds ?? this.vehicleIds,
      drivingLicenseNumber: drivingLicenseNumber ?? this.drivingLicenseNumber,
      driverNotes: driverNotes ?? this.driverNotes,
      carPlateNumber: carPlateNumber ?? this.carPlateNumber,
      carOwnerOfficialName: carOwnerOfficialName ?? this.carOwnerOfficialName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'AppUser(ID: $id, Type: $userType, Verified: $isIdVerified, Rating: $averageRating)';
}