// lib/services/auth_service.dart
//
// خدمة المصادقة والتعامل مع سجل المستخدم في Firestore.
// تحسينات:
// - توحيد حقول المستخدم عند الإنشاء (أنواع مناسبة).
// - رسائل خطأ عربية واضحة عبر استثناءات نصية.
// - استخدام FieldValue.serverTimestamp() لحقل createdAt.
// - ضمان أن childrenCount يخزن كـ int وليس double.
// - دوال مساعدة لجلب بيانات المستخدم وتحويلها إلى AppUser.
//
// ملاحظة: تأكد أن لديك ملف models/app_user.dart مع AppUser.fromDocument
// الذي يتعامل مع الحقول الموضوعة هنا.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'package:flutter/material.dart';
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthService();

  /// بث حالة المصادقة
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// تحويل أخطاء FirebaseAuthException إلى رسائل عربية مفهومة
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

  /// تسجيل الدخول بواسطة البريد الإلكتروني وكلمة المرور
  /// يعيد كائن User عند النجاح أو يرمي استثناء نصي عند الفشل
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

  /// إنشاء حساب جديد وحفظ بياناته في Firestore
  /// يعيد كائن User عند النجاح أو يرمي استثناء نصي عند الفشل
  Future<User?> register({
    required String name,
    required String nickname,
    required String email,
    required String password,
    required String role, // مثال: 'driver' أو 'passenger'
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

  /// إنشاء سجل المستخدم في Firestore بصيغة موحّدة وآمنة
  Future<void> _createUserRecord(String uid, String name, String nickname, String email, String role) async {
    // توحيد نوع الحقول: childrenCount كـ int، familyStatus كـ bool، documents كـ Map
    final normalizedRole = role.trim().toLowerCase();

    final Map<String, dynamic> userData = {
      'uid': uid,
      'name': name,
      'nickname': nickname,
      'email': email,
      'userType': normalizedRole, // 'driver' أو 'passenger' أو 'agency' ...
      'averageRating': 0.0,
      'ratingCount': 0,
      'mobileNumber': '',
      'profilePictureUrl': '',
      'familyStatus': false,
      'childrenCount': 0, // int
      'isIdVerified': false,
      'identityCardUrl': '',
      'documents': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      // حقول اختيارية عامة
      'isDriver': normalizedRole == 'driver',
    };

    // حقول إضافية خاصة بالسائق
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

    // حقول إضافية خاصة بالمكتب (agency)
    if (normalizedRole == 'agency') {
      userData.addAll({
        'agencyName': name,
        'agencyVerified': false,
        'agencyVehicles': <String>[],
      });
    }

    await _firestore.collection('users').doc(uid).set(userData);
  }

  /// جلب بيانات المستخدم ككائن AppUser مباشرة
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

  /// تحديث بعض حقول ملف المستخدم (جزئي)
  /// updates: خريطة الحقول المراد تحديثها (تأكد من إزالة nulls قبل النداء)
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

  /// حذف حساب المستخدم (Auth + Firestore) — يتطلب صلاحيات مناسبة
  Future<bool> deleteUserAccount(String uid) async {
    try {
      // حذف سجل المستخدم من Firestore
      await _firestore.collection('users').doc(uid).delete();

      // حذف حساب Firebase Auth إن كان المستخدم الحالي هو نفسه
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

  /// تسجيل الخروج
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// الحصول على المستخدم الحالي من Firebase Auth
  User? getCurrentUser() => _auth.currentUser;
}
