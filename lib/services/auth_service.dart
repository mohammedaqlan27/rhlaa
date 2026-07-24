// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // الآن الكونستركتور يقبل تبعيات اختيارية (للاختبارات أو المحاكيات)
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // إذا أردت تفعيل محاكيات في وقت التشغيل (اختياري)
  void useEmulators({required String host, required int authPort, required int firestorePort}) {
    try {
      _auth.useAuthEmulator(host, authPort);
    } catch (_) {}
    try {
      _firestore.useFirestoreEmulator(host, firestorePort);
    } catch (_) {}
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

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
      case 'network-request-failed':
        return 'تأكد من اتصالك بالإنترنت.';
      case 'too-many-requests':
        return 'تم حظر المحاولات مؤقتاً. حاول لاحقاً.';
      case 'operation-not-allowed':
        return 'طريقة المصادقة غير مفعلة في إعدادات Firebase.';
      default:
        return e.message ?? 'حدث خطأ أثناء المصادقة.';
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'حدث خطأ غير متوقع أثناء تسجيل الدخول.';
    }
  }

  Future<User?> register({
    required String name,
    required String nickname,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final user = result.user;
      if (user != null) {
        await _createUserRecord(user.uid, name, nickname, email.trim(), role);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'حدث خطأ أثناء إنشاء الحساب.';
    }
  }

  Future<void> _createUserRecord(String uid, String name, String nickname, String email, String role) async {
    final normalizedRole = role.trim().toLowerCase();
    final Map<String, dynamic> userData = {
      'uid': uid,
      'name': name,
      'nickname': nickname,
      'email': email,
      'userType': normalizedRole,
      'averageRating': 0.0,
      'ratingCount': 0,
      'mobileNumber': '',
      'profilePictureUrl': '',
      'familyStatus': false,
      'childrenCount': 0,
      'isIdVerified': false,
      'identityCardUrl': '',
      'documents': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'isDriver': normalizedRole == 'driver',
    };

    if (normalizedRole == 'driver') {
      userData.addAll({
        'drivingLicenseNumber': '',
        'plateNumber': '',
        'carOwnerOfficialName': '',
        'driverNotes': '',
        'vehicleIds': <String>[],
        'isActiveDriver': true,
      });
    }

    if (normalizedRole == 'agency') {
      userData.addAll({
        'agencyName': name,
        'agencyVerified': false,
        'agencyVehicles': <String>[],
      });
    }

    await _firestore.collection('users').doc(uid).set(userData);
  }

  Future<AppUser?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromDocument(doc);
      }
      return null;
    } catch (e) {
      debugPrint('AuthService.getUserData error: $e');
      return null;
    }
  }

  Future<bool> updateUserRecord(String uid, Map<String, dynamic> updates) async {
    if (uid.isEmpty) return false;
    try {
      final payload = Map<String, dynamic>.from(updates);
      payload.removeWhere((k, v) => v == null);
      payload['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(uid).update(payload);
      return true;
    } catch (e) {
      debugPrint('AuthService.updateUserRecord error: $e');
      return false;
    }
  }

  Future<bool> deleteUserAccount(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
      final current = _auth.currentUser;
      if (current != null && current.uid == uid) {
        await current.delete();
      }
      return true;
    } catch (e) {
      debugPrint('AuthService.deleteUserAccount error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? getCurrentUser() => _auth.currentUser;
}
