// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// مراقبة حالة المصادقة
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// معالجة أخطاء Firebase برسائل عربية
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'هذا البريد الإلكتروني غير مسجل.';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة.';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مستخدم بالفعل.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      default:
        return 'حدث خطأ غير متوقع. (${e.code})';
    }
  }

  /// تسجيل الدخول
  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (_) {
      throw 'حدث خطأ أثناء تسجيل الدخول.';
    }
  }

  /// إنشاء حساب جديد
  /// role: استخدم 'Driver' أو 'Passenger' أو أي تسمية تعتمدها في التطبيق
  Future<User?> register(String nickname, String email, String password, String role) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = result.user;

      if (user != null) {
        await _createUserRecord(user.uid, nickname, email, role);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (_) {
      throw 'حدث خطأ أثناء إنشاء الحساب.';
    }
  }

  /// إنشاء سجل المستخدم في Firestore
  Future<void> _createUserRecord(String uid, String nickname, String email, String role) async {
    final userData = {
      'id': uid,
      'nickname': nickname,
      'email': email,
      // نستخدم كلتا الصيغتين (snake_case و camelCase) إن أردت التوافق مع الشاشات
      'user_type': role,
      'userType': role,
      'average_rating': 0.0,
      'averageRating': 0.0,
      'rating_count': 0,
      'ratingCount': 0,
      'profile_picture_url': null,
      'profilePictureUrl': null,
      'mobile_number': null,
      'mobileNumber': null,
      'created_at': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (role.toLowerCase() == 'driver' || role == 'Driver') {
      userData.addAll({
        'driving_license_number': null,
        'car_plate_number': null,
        'car_owner_official_name': null,
        'drivingLicenseNumber': null,
        'carPlateNumber': null,
        'carOwnerOfficialName': null,
      });
    }

    await _firestore.collection('users').doc(uid).set(userData);
  }

  /// جلب بيانات المستخدم
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// تسجيل الخروج
  Future<void> signOut() async => await _auth.signOut();

  /// المستخدم الحالي
  User? getCurrentUser() => _auth.currentUser;
}
