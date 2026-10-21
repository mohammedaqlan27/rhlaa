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

  // Completer لانتظار انتهاء التهيئة الأولية (مفيد قبل التنقل)
  final Completer<void> _readyCompleter = Completer<void>();

  AuthState() {
    // تهيئة الحالة بشكل غير متزامن
    _init();
    // نستمع لتغيرات حالة المصادقة
    _authSub = _auth.userChanges().listen((u) {
      _user = u;
      if (u != null) {
        // عند تسجيل دخول جديد أو تغيير المستخدم، نجدد التوكن ونحمّل البروفايل
        _refreshTokenAndLoadProfile(u);
      } else {
        // عند تسجيل الخروج
        userType = null;
        userRole = null;
        notifyListeners();
      }
    });
  }

  /// تهيئة أولية: تحميل المستخدم الحالي وتجديد التوكن إن وُجد
  Future<void> _init() async {
    try {
      _user = _auth.currentUser;
      if (_user != null) {
        isLoading = true;
        notifyListeners();
        await _refreshTokenAndLoadProfile(_user!);
      }
    } catch (e, st) {
      debugPrint('AuthState._init error: $e\n$st');
    } finally {
      isLoading = false;
      notifyListeners();
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  /// انتظر انتهاء التهيئة الأولية (يمكن استدعاؤها قبل التنقل)
  Future<void> waitForInitialization() => _readyCompleter.future;

  // --- getters ---
  User? get firebaseUser => _user;
  bool get isPhoneVerified => verificationId != null;
  bool get isAuthenticated => _auth.currentUser != null;

  // --- منطق التحقق من الهاتف ---
  Future<void> verifyPhoneNumber(String phoneNumber, Function(String) onCodeSent) async {
    isLoading = true;
    notifyListeners();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          final userCred = await _auth.signInWithCredential(credential);
          _user = userCred.user;
          // بعد تسجيل الدخول عبر credential، نجدد التوكن ونحمّل البروفايل
          if (_auth.currentUser != null) {
            await _refreshTokenAndLoadProfile(_auth.currentUser!);
          }
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
      final userCred = await _auth.signInWithCredential(credential);
      _user = userCred.user;

      // بعد تسجيل الدخول بنجاح، نجدد التوكن ونحمّل البروفايل
      if (userCred.user != null) {
        await _refreshTokenAndLoadProfile(userCred.user!);
      }
      return true;
    } catch (e) {
      errorMessage = "كود التحقق غير صحيح";
      debugPrint('AuthState.signInWithOTP error: $e');
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
    String? agencyStatus,
    String? drivingLicenseNumber,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      UserCredential cred;
      if (_auth.currentUser != null) {
        // إذا كان هناك مستخدم مسجل عبر OTP، نحاول الربط (link) مع بيانات البريد/كلمة المرور
        try {
          cred = await _auth.currentUser!.linkWithCredential(
            EmailAuthProvider.credential(email: email, password: password),
          );
        } on FirebaseAuthException catch (e) {
          // إذا فشل الربط لأن البريد مستخدم مسبقًا، نحاول تسجيل الدخول بالبريد بدلاً من الربط
          if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
            debugPrint('AuthState.register: credential already in use, trying signInWithEmailAndPassword');
            final userCred = await _auth.signInWithEmailAndPassword(email: email, password: password);
            cred = userCred;
          } else {
            rethrow;
          }
        }
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
      _user = cred.user;
      await _loadUserProfile(uid);

      // بعد التسجيل، نجدد الـ ID token ونقرأ الـ custom claims إن وُجدت
      if (cred.user != null) {
        await _refreshTokenAndLoadProfile(cred.user!);
      }

      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message;
      debugPrint('AuthState.register FirebaseAuthException: code=${e.code} message=${e.message}');
      return false;
    } catch (e, st) {
      errorMessage = e.toString();
      debugPrint('AuthState.register unexpected error: $e\n$st');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // --- تسجيل الدخول بالبريد وكلمة المرور ---
  Future<bool> login(String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();
      final userCred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      _user = userCred.user;
      debugPrint('Auth: signIn success uid=${userCred.user?.uid}');

      if (_auth.currentUser != null) {
        await _refreshTokenAndLoadProfile(_auth.currentUser!);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth: signIn failed code=${e.code} message=${e.message}');
      errorMessage = e.message ?? "خطأ في البريد أو كلمة المرور";
      return false;
    } catch (e, st) {
      debugPrint('Auth: unexpected error $e\n$st');
      errorMessage = "خطأ في البريد أو كلمة المرور";
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // --- تجديد التوكن وقراءة الـ custom claims ثم تحميل البروفايل ---
  Future<void> _refreshTokenAndLoadProfile(User user) async {
    try {
      // تحديث المرجع المحلي للمستخدم
      _user = user;
      notifyListeners();

      // يجبر تجديد الـ ID token من الخادم
      await user.getIdToken(true);

      // جلب idTokenResult لقراءة الـ custom claims
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims ?? {};
      debugPrint('AuthState: ID token claims for ${user.uid}: $claims');

      // إذا كان هناك دور داخل الـ claims يمكن استخدامه لتعيين userRole محلياً
      if (claims.containsKey('role')) {
        userRole = claims['role']?.toString();
        debugPrint('AuthState: userRole set from claims => $userRole');
      }

      // حمّل بيانات المستخدم من Firestore (ستقوم _loadUserProfile بتعيين userType/userRole إن وُجدت)
      await _loadUserProfile(user.uid);

      // إذا لم يتم تعيين userRole من الـ claims، فابقَ على ما جلبته من Firestore أو افتراضي
      if ((userRole == null || userRole!.isEmpty) && claims.containsKey('role')) {
        userRole = claims['role']?.toString();
      }

      notifyListeners();
    } catch (e, st) {
      debugPrint('AuthState._refreshTokenAndLoadProfile error: $e\n$st');
    }
  }

  // --- دالة مساعدة لإجبار تجديد التوكن من خارج الكلاس ---
  Future<void> forceRefreshToken() async {
    final u = _auth.currentUser;
    if (u != null) {
      await _refreshTokenAndLoadProfile(u);
    }
  }

  // --- دالة مساعدة للحصول على ID token كسلسلة لاستخدامها في طلبات HTTP ---
  Future<String?> getIdTokenForRequests({bool forceRefresh = false}) async {
    final u = _auth.currentUser;
    if (u == null) return null;
    try {
      if (forceRefresh) {
        await u.getIdToken(true);
      }
      final token = await u.getIdToken();
      return token;
    } catch (e) {
      debugPrint('AuthState.getIdTokenForRequests error: $e');
      return null;
    }
  }

  // --- تحميل بروفايل المستخدم من Firestore ---
  Future<void> _loadUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();

      if (data != null) {
        final rawUserType = data['userType'] ?? data['user_type'] ?? data['role'] ?? data['userRole'] ?? data['user_role'];
        final rawUserRole = data['userRole'] ?? data['user_role'] ?? data['role'] ?? data['userType'] ?? data['user_type'];

        userType = rawUserType?.toString().trim();
        final firestoreRole = rawUserRole?.toString().trim();

        // إذا لم يكن userRole محددًا من الـ claims، استخدم ما في Firestore
        if (firestoreRole != null && firestoreRole.isNotEmpty) {
          userRole = firestoreRole;
        }

        if ((userRole == null || userRole!.isEmpty) && userType != null && userType!.isNotEmpty) {
          userRole = userType;
        }
      } else {
        userType = null;
        // لا نغير userRole هنا لأن قد يكون قد تم تعيينه من الـ claims
      }
    } catch (e, st) {
      debugPrint('AuthState._loadUserProfile error: $e\n$st');
      userType = null;
      // لا نغير userRole هنا حفاظًا على أي قيمة من الـ claims
    }
  }

  // --- تسجيل الخروج ---
  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    userType = null;
    userRole = null;
    notifyListeners();
  }

  // --- تنظيف الموارد عند التخلص من الحالة ---
  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
