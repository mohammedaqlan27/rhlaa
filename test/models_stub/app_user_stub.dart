// test/models_stub/app_user_stub.dart
class AppUserStub {
  final String id;
  final String email;
  final String name;

  AppUserStub({required this.id, required this.email, required this.name});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': id,
      'email': email,
      'name': name,
      'createdAt': null,
    };
  }
}
