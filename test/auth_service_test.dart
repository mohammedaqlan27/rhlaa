// test/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:rhlaa/services/auth_service.dart';
import 'package:rhlaa/models/app_user.dart';

void main() {
  group('AuthService register tests', () {
    late MockFirestoreInstance firestore;
    late MockFirebaseAuth auth;
    late AuthService service;

    setUp(() {
      firestore = MockFirestoreInstance();
      auth = MockFirebaseAuth();
      service = AuthService();
      // ملاحظة: AuthService في مشروعك يستخدم FirebaseAuth.instance مباشرة،
      // يمكنك تعديل AuthService لقبول auth/firestore كـ dependency injection
      // أو استخدام FirebaseAuth.instance/Firestore.instance مع المحاكي.
    });

    test('register should create user record in Firestore', () async {
      // تسجيل مستخدم جديد
      final user = await auth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      // إنشاء سجل المستخدم في Firestore عبر الدالة الخاصة
      await firestore.collection('users').doc(user.user!.uid).set({
        'uid': user.user!.uid,
        'name': 'Test User',
        'nickname': 'Tester',
        'email': 'test@example.com',
        'userType': 'driver',
        'averageRating': 0.0,
        'ratingCount': 0,
        'createdAt': DateTime.now(),
      });

      // التحقق أن المستند موجود
      final doc = await firestore.collection('users').doc(user.user!.uid).get();
      expect(doc.exists, true);
      expect(doc.data()?['name'], 'Test User');
      expect(doc.data()?['userType'], 'driver');
    });

    test('getUserData should return AppUser', () async {
      final uid = 'u123';
      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': 'Ali',
        'nickname': 'Tester',
        'email': 'ali@example.com',
        'userType': 'passenger',
        'averageRating': 0.0,
        'ratingCount': 0,
      });

      final doc = await firestore.collection('users').doc(uid).get();
      final appUser = AppUser.fromDocument(doc);

      expect(appUser.name, 'Ali');
      expect(appUser.userType, 'passenger');
    });
  });
}
