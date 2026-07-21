// test/services/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rhlaa/services/auth_service.dart';

// توليد الـ Mocks باستخدام Mockito
@GenerateMocks([
  FirebaseAuth,
  User,
  UserCredential,
])
import 'auth_service_test.mocks.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late AuthService authService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    authService = AuthService(auth: mockAuth, firestore: fakeFirestore);
  });

  group('AuthService basic flows', () {
    test('signIn returns user on success', () async {
      final mockUser = MockUser();
      final mockCred = MockUserCredential();

      // إعداد التوقعات (صيغة Mockito الصحيحة)
      when(mockUser.uid).thenReturn('test_uid_123');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockCred.user).thenReturn(mockUser);

      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCred);

      final user = await authService.signIn('test@example.com', 'password123');

      expect(user, isNotNull);
      expect(user?.uid, 'test_uid_123');
      expect(user?.email, 'test@example.com');
    });

    test('register creates user and writes Firestore record', () async {
      final mockUser = MockUser();
      final mockCred = MockUserCredential();

      when(mockUser.uid).thenReturn('new_uid_1');
      when(mockUser.email).thenReturn('new@example.com');
      when(mockCred.user).thenReturn(mockUser);

      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCred);

      final user = await authService.register(
        name: 'Ali',
        nickname: 'Abu Ali',
        email: 'new@example.com',
        password: 'password123',
        role: 'driver',
      );

      expect(user, isNotNull);
      final docSnapshot = await fakeFirestore.collection('users').doc(user!.uid).get();
      expect(docSnapshot.exists, true);
      expect(docSnapshot.data()?['name'], 'Ali');
      expect(docSnapshot.data()?['userType'], 'driver');
    });

    test('signOut calls FirebaseAuth.signOut', () async {
      when(mockAuth.signOut()).thenAnswer((_) async => {});

      await authService.signOut();

      verify(mockAuth.signOut()).called(1);
    });
  });

  group('AuthService error handling', () {
    test('signIn throws localized message for user-not-found', () async {
      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(FirebaseAuthException(code: 'user-not-found'));

      try {
        await authService.signIn('noone@example.com', 'pwd');
        fail('Should have thrown an error');
      } catch (e) {
        expect(e, isA<String>());
        // تأكد من أن الرسالة تحتوي على النص العربي المتوقع في الـ Service
        expect(e.toString(), contains('غير مسجل'));
      }
    });
  });

  group('AuthService delete account', () {
    test('deleteUserAccount deletes firestore doc and auth user', () async {
      final uid = 'uid123';
      await fakeFirestore.collection('users').doc(uid).set({'uid': uid});

      final mockUser = MockUser();
      when(mockUser.uid).thenReturn(uid);
      when(mockUser.delete()).thenAnswer((_) async => {});
      when(mockAuth.currentUser).thenReturn(mockUser);

      final ok = await authService.deleteUserAccount(uid);

      expect(ok, isTrue);
      verify(mockUser.delete()).called(1);

      final doc = await fakeFirestore.collection('users').doc(uid).get();
      expect(doc.exists, isFalse);
    });
  });
}