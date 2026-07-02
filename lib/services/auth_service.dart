import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// مراقبة حالة المصادقة (هل المستخدم مسجل دخول أم لا)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// معالجة أخطاء Firebase برسائل عربية واضحة للمستخدم
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
      default:
        return 'حدث خطأ: ${e.message}';
    }
  }

  /// تسجيل الدخول بواسطة البريد الإلكتروني وكلمة المرور
  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'حدث خطأ غير متوقع أثناء تسجيل الدخول.';
    }
  }

  /// إنشاء حساب جديد وحفظ بياناته في Firestore
  Future<User?> register({
    required String name,
    required String nickname,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = result.user;

      if (user != null) {
        await _createUserRecord(user.uid, name, nickname, email, role);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'حدث خطأ أثناء إنشاء الحساب.';
    }
  }

  /// إنشاء سجل المستخدم في Firestore بالصيغة المحدثة والمتوافقة 100%
  Future<void> _createUserRecord(String uid, String name, String nickname, String email, String role) async {
    // تجهيز البيانات الأساسية (عامة للراكب والسائق)
    final userData = {
      'Id': uid, // الحقل المعرف كما هو في قاعدة بياناتك
      'uid': uid,
      'name': name,
      'nickname': nickname,
      'email': email,
      'userType': role.toLowerCase(), // تخزينها بصيغة lowercase لتوحيد عمليات الفلترة والبحث
      'averageRating': 0.0,
      'ratingCount': 0,
      'mobileNumber': '',
      'profilePictureUrl': '',
      'familyStatus': false, // القيمة الافتراضية كـ boolean
      'childrenCount': 0.0, // القيمة الافتراضية كـ double لتطابق الـ Firestore تماماً
      'isIdVerified': false,
      'identityCardUrl': '',
      'documents': {},
      'createdAt': FieldValue.serverTimestamp(),
    };

    // إضافة حقول إضافية خاصة بالسائق فقط إذا كان الدور 'driver'
    if (role.toLowerCase() == 'driver') {
      userData.addAll({
        'drivingLicenseNumber': '',
        'plateNumber': '',
        'carOwnerOfficialName': '',
        'driverNotes': '',
        'vehicleIds': [],
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
      print('Error fetching user data: $e');
      return null;
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async => await _auth.signOut();

  /// الحصول على كائن المستخدم الحالي من Firebase Auth
  User? getCurrentUser() => _auth.currentUser;
}