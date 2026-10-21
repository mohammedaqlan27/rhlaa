// lib/providers/user_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/app_user.dart';
import '../models/agency.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/agencies_service.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final AgenciesService _agenciesService = AgenciesService();

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  /// Refresh user: آمن للاستخدام من initState أو بعد تسجيل الدخول
  Future<void> refreshUser() async {
    final firebaseUser = _authService.getCurrentUser();
    if (firebaseUser != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        fetchUserById(firebaseUser.uid);
      });
    } else {
      _currentUser = null;
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  /// جلب بيانات مستخدم أو مكتب بناءً على uid مع الحماية من التداخل
  Future<void> fetchUserById(String uid, {BuildContext? context}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      // 1. محاولة جلب المستخدم الأساسي من جدول users أولاً (يشمل الأدمن، الحكومة، السائق، الراكب)
      final user = await _userService.getUserById(uid);

      if (user != null) {
        _currentUser = user;
      } else {
        // 2. إذا لم يوجد في جدول users، نفحص حصرياً هل هو وكالة مسجلة في جدول agencies
        final Agency? agency = await _agenciesService.getAgencyByAuthUid(uid);
        if (agency != null) {
          _currentUser = AppUser(
            id: agency.id,
            uid: uid,
            name: agency.agencyName ?? agency.managerName ?? 'مكتب',
            nickname: '',
            email: agency.email ?? '',
            userType: 'agency',
            mobileNumber: agency.mobileNumber ?? '',
            agencyName: agency.agencyName,
            agencyVerified: agency.isActive,
            agencyId: agency.id,
            walletBalance: agency.walletBalance,
          );
        } else {
          _currentUser = null;
          _errorMessage = "تعذر العثور على بيانات المستخدم أو المكتب في قاعدة البيانات.";
          if (context != null) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
              );
            });
          }
        }
      }

      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } catch (e, st) {
      _errorMessage = "حدث خطأ أثناء جلب البيانات: $e";
      debugPrint('UserProvider.fetchUserById error: $e\n$st');
      if (context != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
          );
        });
      }
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createOrSetUser(AppUser user) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final success = await _userService.createOrSetUser(user);
      if (success) {
        _currentUser = user;
        SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
        return true;
      } else {
        _errorMessage = 'فشل إنشاء/تحديث المستخدم.';
        return false;
      }
    } catch (e, st) {
      _errorMessage = 'خطأ أثناء إنشاء المستخدم: ${e.toString()}';
      debugPrint('UserProvider.createOrSetUser error: $e\n$st');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile(AppUser updatedUser) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final success = await _userService.updateUserProfile(updatedUser);
      if (success) {
        _currentUser = await _userService.getUserById(updatedUser.id);
        SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
        return true;
      } else {
        _errorMessage = "فشل تحديث الملف الشخصي.";
        return false;
      }
    } catch (e, st) {
      _errorMessage = "خطأ: ${e.toString()}";
      debugPrint('UserProvider.updateProfile error: $e\n$st');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateSpecificFields(Map<String, dynamic> fields) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _errorMessage = null;
    try {
      fields.removeWhere((k, v) => v == null);
      if (fields.containsKey('childrenCount')) {
        final v = fields['childrenCount'];
        if (v is String) fields['childrenCount'] = int.tryParse(v) ?? 0;
        else if (v is double) fields['childrenCount'] = v.toInt();
      }
      final success = await _userService.updateUserFields(_currentUser!.id, fields);
      if (success) {
        _currentUser = await _userService.getUserById(_currentUser!.id);
        SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
        return true;
      } else {
        _errorMessage = 'فشل تحديث الحقول.';
        return false;
      }
    } catch (e, st) {
      _errorMessage = e.toString();
      debugPrint('UserProvider.updateSpecificFields error: $e\n$st');
      return false;
    } finally {
      _setLoading(false);
    }
  }

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
    } catch (e, st) {
      _errorMessage = e.toString();
      debugPrint('UserProvider.updateProfileImage error: $e\n$st');
      return false;
    } finally {
      _setLoading(false);
    }
  }

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
    } catch (e, st) {
      _errorMessage = e.toString();
      debugPrint('UserProvider.uploadDocument error: $e\n$st');
      return false;
    } finally {
      _setLoading(false);
    }
  }

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
    } catch (e, st) {
      _errorMessage = e.toString();
      debugPrint('UserProvider.deleteDocument error: $e\n$st');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateDriverInfo({
    List<String>? vehicleIds,
    String? drivingLicenseNumber,
    String? driverNotes,
    String? carPlateNumber,
    String? carOwnerOfficialName,
    String? agencyStatus,
    bool? isIdVerified,
  }) async {
    if (_currentUser == null) return false;
    final Map<String, dynamic> fields = {};
    if (vehicleIds != null) fields['vehicleIds'] = vehicleIds;
    if (drivingLicenseNumber != null) fields['drivingLicenseNumber'] = drivingLicenseNumber;
    if (driverNotes != null) fields['driverNotes'] = driverNotes;
    if (carPlateNumber != null) fields['carPlateNumber'] = carPlateNumber;
    if (carOwnerOfficialName != null) fields['carOwnerOfficialName'] = carOwnerOfficialName;
    if (agencyStatus != null) fields['agencyStatus'] = agencyStatus;
    if (isIdVerified != null) fields['isIdVerified'] = isIdVerified;
    return await updateSpecificFields(fields);
  }

  Future<void> logout() async {
    await _authService.signOut();
    _currentUser = null;
    _errorMessage = null;
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<Object?> isIdVerified({required BuildContext context}) async {}

  Future<Object?> isActiveDriver({required BuildContext context}) async {}
}