// lib/state/auth_state.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthState with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  bool isLoading = false;
  String? errorMessage;
  String? verificationId; // خاص بالتحقق من الهاتف

  String? userType;
  String? userRole;

  StreamSubscription<User?>? _authSub;

  AuthState() {
    _user = _auth.currentUser;
    if (_user != null) _loadUserProfile(_user!.uid);

    _authSub = _auth.userChanges().listen((u) {
      _user = u;
      if (u != null) {
        _loadUserProfile(u.uid);
      } else {
        userType = null;
        userRole = null;
        notifyListeners();
      }
    });
  }

  User? get firebaseUser => _user;
  bool get isPhoneVerified => verificationId != null;

  // --- منطق التحقق من الهاتف ---
  Future<void> verifyPhoneNumber(String phoneNumber, Function(String) onCodeSent) async {
    isLoading = true;
    notifyListeners();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          errorMessage = e.message;
          isLoading = false;
          notifyListeners();
        },
        codeSent: (String verId, int? resendToken) {
          verificationId = verId;
          isLoading = false;
          notifyListeners();
          onCodeSent(verId);
        },
        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
        },
      );
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithOTP(String smsCode) async {
    if (verificationId == null) return false;
    try {
      isLoading = true;
      notifyListeners();
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      errorMessage = "كود التحقق غير صحيح";
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // --- التسجيل المطور ---
  Future<bool> register({
    required String email,
    required String password,
    required String nickname,
    required String userType,
    String? mobileNumber,
    String? idNumber,
    String? plateNumber,
    String? agencyStatus, // الحقل الجديد
    String? drivingLicenseNumber,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      UserCredential cred;
      if (_auth.currentUser != null) {
        cred = await _auth.currentUser!.linkWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
      } else {
        cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      }

      final uid = cred.user?.uid;
      if (uid == null) throw Exception('فشل إنشاء المستخدم');

      final userMap = <String, dynamic>{
        'email': email,
        'nickname': nickname,
        'userType': userType,
        'mobileNumber': mobileNumber,
        'idNumber': idNumber,
        'carPlateNumber': plateNumber,
        'agencyStatus': agencyStatus ?? 'مستقل',
        'drivingLicenseNumber': drivingLicenseNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(uid).set(userMap, SetOptions(merge: true));
      await _loadUserProfile(uid);
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (_auth.currentUser != null) await _loadUserProfile(_auth.currentUser!.uid);
      return true;
    } catch (e) {
      errorMessage = "خطأ في البريد أو كلمة المرور";
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();

      if (data != null) {
        final rawUserType = data['userType'] ?? data['user_type'] ?? data['role'] ?? data['userRole'] ?? data['user_role'];
        final rawUserRole = data['userRole'] ?? data['user_role'] ?? data['role'] ?? data['userType'] ?? data['user_type'];

        userType = rawUserType?.toString().trim();
        userRole = rawUserRole?.toString().trim();

        if ((userRole == null || userRole!.isEmpty) && userType != null && userType!.isNotEmpty) {
          userRole = userType;
        }
      } else {
        userType = null;
        userRole = null;
      }
    } catch (e, st) {
      debugPrint('AuthState._loadUserProfile error: $e\n$st');
      userType = null;
      userRole = null;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }
}
