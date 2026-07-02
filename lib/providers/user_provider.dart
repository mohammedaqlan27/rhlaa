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
    }
  }

  /// 2. جلب بيانات مستخدم معين بواسطة الـ UID
  Future<void> fetchUserById(String uid) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _currentUser = await _userService.getUserById(uid);
      if (_currentUser == null) {
        _errorMessage = "تعذر العثور على بيانات المستخدم في قاعدة البيانات.";
      }
      notifyListeners(); // إشعار الواجهات فور تحديث الكائن
    } catch (e) {
      _errorMessage = "حدث خطأ أثناء جلب البيانات: $e";
    } finally {
      _setLoading(false);
    }
  }

  /// 3. تحديث الملف الشخصي بالكامل
  Future<bool> updateProfile(AppUser updatedUser) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      bool success = await _userService.updateUserProfile(updatedUser);
      if (success) {
        _currentUser = updatedUser;
        notifyListeners();
        return true;
      } else {
        _errorMessage = "فشل تحديث الملف الشخصي.";
        return false;
      }
    } catch (e) {
      _errorMessage = "خطأ: ${e.toString()}";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 4. تحديث حقول معينة فقط في قاعدة البيانات
  Future<bool> updateSpecificFields(Map<String, dynamic> fields) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    try {
      bool success = await _userService.updateUserFields(_currentUser!.id, fields);
      if (success) {
        _currentUser = await _userService.getUserById(_currentUser!.id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 5. رفع وتحديث صورة الملف الشخصي
  Future<bool> updateProfileImage(File imageFile) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    try {
      bool success = await _userService.uploadAndSaveDocument(
          imageFile, _currentUser!.id, 'profile');
      if (success) {
        await refreshUser();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 6. تسجيل الخروج وتصفير البيانات المحلية
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