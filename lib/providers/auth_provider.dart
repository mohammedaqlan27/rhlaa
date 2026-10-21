// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// مزوّد بسيط لحالة المصادقة يوفر الحقول التي تحتاجها الشاشات:
/// - currentUserId
/// - currentUserName
/// - currentUser (AppUser-like minimal map)
class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _firebaseUser;
  String? _currentUserName;
  Map<String, dynamic>? _currentUserData;

  AuthProvider() {
    _firebaseUser = _auth.currentUser;
    if (_firebaseUser != null) _loadUserData(_firebaseUser!.uid);
    // استمع لتغيّر حالة المصادقة
    _auth.userChanges().listen((u) {
      _firebaseUser = u;
      if (u != null) {
        _loadUserData(u.uid);
      } else {
        _currentUserName = null;
        _currentUserData = null;
        notifyListeners();
      }
    });
  }

  String? get currentUserId => _firebaseUser?.uid;
  String? get currentUserName => _currentUserName;
  Map<String, dynamic>? get currentUser => _currentUserData;

  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _currentUserData = data;
        _currentUserName = (data['name'] ?? data['nickname'] ?? _firebaseUser?.displayName) as String?;
      } else {
        _currentUserData = null;
        _currentUserName = _firebaseUser?.displayName;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AuthProvider._loadUserData error: $e');
      _currentUserData = null;
      _currentUserName = _firebaseUser?.displayName;
    } finally {
      notifyListeners();
    }
  }

  /// إعادة تحميل بيانات المستخدم يدوياً
  Future<void> refresh() async {
    final uid = _firebaseUser?.uid;
    if (uid != null) await _loadUserData(uid);
  }
}
