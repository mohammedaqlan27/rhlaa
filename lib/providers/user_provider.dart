// lib/providers/user_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters للوصول للبيانات من الواجهات
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  /// 1. جلب بيانات المستخدم الحالي عند فتح التطبيق أو تسجيل الدخول
  Future<void> refreshUser() async {
    final firebaseUser = _authService.getCurrentUser();
    if (firebaseUser != null) {
      await fetchUserById(firebaseUser.uid);
    } else {
      // لم يتم تسجيل الدخول
      _currentUser = null;
      notifyListeners();
    }
  }

  /// 2. جلب بيانات مستخدم معين بواسطة الـ UID
  Future<void> fetchUserById(String uid) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final user = await _userService.getUserById(uid);
      if (user == null) {
        _errorMessage = "تعذر العثور على بيانات المستخدم في قاعدة البيانات.";
        _currentUser = null;
      } else {
        _currentUser = user;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = "حدث خطأ أثناء جلب البيانات: $e";
      debugPrint('UserProvider.fetchUserById error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 3. إنشاء مستخدم جديد أو تعيين بيانات المستخدم (يستخدم AppUser.toMap)
  Future<bool> createOrSetUser(AppUser user) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final success = await _userService.createOrSetUser(user);
      if (success) {
        _currentUser = user;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'فشل إنشاء/تحديث المستخدم.';
        return false;
      }
    } catch (e) {
      _errorMessage = 'خطأ أثناء إنشاء المستخدم: ${e.toString()}';
      debugPrint('UserProvider.createOrSetUser error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 4. تحديث الملف الشخصي بالكامل
  Future<bool> updateProfile(AppUser updatedUser) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final success = await _userService.updateUserProfile(updatedUser);
      if (success) {
        // إعادة جلب المستخدم لضمان التوافق مع الحقول في Firestore
        _currentUser = await _userService.getUserById(updatedUser.id);
        notifyListeners();
        return true;
      } else {
        _errorMessage = "فشل تحديث الملف الشخصي.";
        return false;
      }
    } catch (e) {
      _errorMessage = "خطأ: ${e.toString()}";
      debugPrint('UserProvider.updateProfile error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 5. تحديث حقول معينة فقط في قاعدة البيانات
  Future<bool> updateSpecificFields(Map<String, dynamic> fields) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _errorMessage = null;
    try {
      // تنظيف الحقول من القيم null
      fields.removeWhere((k, v) => v == null);

      // تحويل أنواع إن لزم (مثال childrenCount)
      if (fields.containsKey('childrenCount')) {
        final v = fields['childrenCount'];
        if (v is String) {
          fields['childrenCount'] = int.tryParse(v) ?? 0;
        } else if (v is double) {
          fields['childrenCount'] = v.toInt();
        }
      }

      final success = await _userService.updateUserFields(_currentUser!.id, fields);
      if (success) {
        // إعادة جلب المستخدم لتحديث الكائن المحلي
        _currentUser = await _userService.getUserById(_currentUser!.id);
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'فشل تحديث الحقول.';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('UserProvider.updateSpecificFields error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 6. رفع وتحديث صورة الملف الشخصي (تخزن في profilePictureUrl)
  Future<bool> updateProfileImage(File imageFile) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _errorMessage = null;
    try {
      final success = await _userService.uploadAndSaveDocument(imageFile, _currentUser!.id, 'profile');
      if (success) {
        await refreshUser();
        return true;
      } else {
        _errorMessage = 'فشل رفع صورة الملف الشخصي.';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('UserProvider.updateProfileImage error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 7. رفع وثيقة هوية أو رخصة أو أي مستند وتخزينه في documents map
  Future<bool> uploadDocument(File file, String type, {String? extension}) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _errorMessage = null;
    try {
      final success = await _userService.uploadAndSaveDocument(file, _currentUser!.id, type, extension: extension);
      if (success) {
        await refreshUser();
        return true;
      } else {
        _errorMessage = 'فشل رفع المستند.';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('UserProvider.uploadDocument error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 8. حذف رابط وثيقة من Storage و Firestore
  Future<bool> deleteDocument(String type, {String? extension}) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _errorMessage = null;
    try {
      final success = await _userService.deleteDocument(_currentUser!.id, type, extension: extension);
      if (success) {
        await refreshUser();
        return true;
      } else {
        _errorMessage = 'فشل حذف المستند.';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('UserProvider.deleteDocument error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 9. تحديث بيانات السائق الخاصة (مثلاً عند تفعيل حساب السائق أو تعديل بيانات المركبة)
  Future<bool> updateDriverInfo({
    List<String>? vehicleIds,
    String? drivingLicenseNumber,
    String? driverNotes,
    String? carPlateNumber,
    String? carOwnerOfficialName,
    bool? isIdVerified,
  }) async {
    if (_currentUser == null) return false;
    final Map<String, dynamic> fields = {};
    if (vehicleIds != null) fields['vehicleIds'] = vehicleIds;
    if (drivingLicenseNumber != null) fields['drivingLicenseNumber'] = drivingLicenseNumber;
    if (driverNotes != null) fields['driverNotes'] = driverNotes;
    if (carPlateNumber != null) fields['carPlateNumber'] = carPlateNumber;
    if (carOwnerOfficialName != null) fields['carOwnerOfficialName'] = carOwnerOfficialName;
    if (isIdVerified != null) fields['isIdVerified'] = isIdVerified;

    return await updateSpecificFields(fields);
  }

  /// 10. تسجيل الخروج وتصفير البيانات المحلية
  Future<void> logout() async {
    await _authService.signOut();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  // دالة مساعدة لإدارة حالة التحميل
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // مسح رسائل الخطأ
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
