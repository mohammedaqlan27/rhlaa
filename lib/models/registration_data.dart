// lib/models/registration_data.dart
class RegistrationData {
  final String email;
  final String password;
  final String nickname;
  final String userType; // 'Driver' أو 'Passenger'
  final String? mobileNumber;
  final String? familyStatus;
  final int childrenCount;

  RegistrationData({
    required this.email,
    required this.password,
    required this.nickname,
    required this.userType,
    this.mobileNumber,
    this.familyStatus,
    this.childrenCount = 0,
  });
}
