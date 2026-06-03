// lib/state/auth_state.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthState with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  bool isLoading = false;
  String? errorMessage;

  String? userType;
  String? userRole;

  AuthState() {
    _user = _auth.currentUser;
    if (_user != null) {
      _loadUserProfile(_user!.uid);
    }

    _auth.userChanges().listen((u) {
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
  User? get user => _user;
  String? get userId => _user?.uid;

  Future<bool> register({
    required String email,
    required String password,
    required String nickname,
    required String userType,
    String? mobileNumber,
    String? idNumber,
    String? plateNumber,
    String? carOwnerOfficialName,
    String? drivingLicenseNumber,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) throw Exception('فشل إنشاء المستخدم');

      final userMap = <String, dynamic>{
        'email': email,
        'nickname': nickname,
        'userType': userType,
        if (mobileNumber != null && mobileNumber.isNotEmpty) 'mobileNumber': mobileNumber,
        if (idNumber != null && idNumber.isNotEmpty) 'idNumber': idNumber,
        if (plateNumber != null && plateNumber.isNotEmpty) 'carPlateNumber': plateNumber,
        if (carOwnerOfficialName != null && carOwnerOfficialName.isNotEmpty) 'carOwnerOfficialName': carOwnerOfficialName,
        if (drivingLicenseNumber != null && drivingLicenseNumber.isNotEmpty) 'drivingLicenseNumber': drivingLicenseNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(uid).set(userMap, SetOptions(merge: true));

      _user = _auth.currentUser;

      try {
        if (_user != null && (_user!.displayName == null || _user!.displayName!.isEmpty)) {
          await _user!.updateDisplayName(nickname);
          _user = _auth.currentUser;
        }
      } catch (_) {}

      await _loadUserProfile(uid);

      errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      errorMessage = e.toString();
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
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      _user = cred.user;
      errorMessage = null;

      if (_user != null) {
        await _loadUserProfile(_user!.uid);
      }

      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    userType = null;
    userRole = null;
    notifyListeners();
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() as Map<String, dynamic>?;

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
    } finally {
      notifyListeners();
    }
  }

  Future<void> reloadProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _loadUserProfile(uid);
    }
  }
}
