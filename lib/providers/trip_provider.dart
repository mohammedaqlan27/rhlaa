// lib/providers/trip_provider.dart
//
// مزود لإدارة حالة الرحلات في الواجهة (TripProvider).
// - يجمع بين TripService و GovFeesService عبر TripService (الذي يدمج GovFeesService).
// - يدعم جلب الرحلات المتاحة، رحلات السائق، إنشاء/تحديث/حذف الرحلات، تحديث المقاعد محلياً ومزامنتها.
// - يضيف وظائف إضافية: جلب رحلة واحدة، إعادة حساب رسوم الفرزة لرحلة واحدة أو لجميع الرحلات النشطة، فلترة محلية، وتجديد القوائم.
// - يحافظ على حالة التحميل ورسائل الخطأ ويُحدّث المستمعين (notifyListeners).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';
import '../services/trip_service.dart';

class TripProvider with ChangeNotifier {
  final TripService _tripService = TripService();

  List<Trip> _availableTrips = [];
  List<Trip> _driverTrips = [];
  bool _isLoading = false;
  String? _errorMessage;

  // دعم للبحث والفلترة المحلية (حفظ نسخة أصلية)
  List<Trip> _availableTripsBackup = [];

  // Getters
  List<Trip> get availableTrips => List.unmodifiable(_availableTrips);
  List<Trip> get driverTrips => List.unmodifiable(_driverTrips);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// جلب جميع الرحلات المتاحة (نشطة + مقاعد متاحة)
  Future<void> fetchAvailableTrips({bool forceRefresh = false}) async {
    // إذا كانت القائمة محلية وموجودة ولا نريد فرض التحديث، نعيدها مباشرة
    if (!forceRefresh && _availableTrips.isNotEmpty) {
      return;
    }

    _setLoading(true);
    _errorMessage = null;
    try {
      final trips = await _tripService.getAvailableTrips();
      _availableTrips = trips;
      // احتفظ بنسخة احتياطية للفلترة المحلية
      _availableTripsBackup = List<Trip>.from(trips);
      debugPrint("✅ تم جلب ${_availableTrips.length} رحلة متاحة للركاب");
    } catch (e, st) {
      debugPrint("🔴 TripProvider.fetchAvailableTrips error: $e\n$st");
      _errorMessage = "حدث خطأ أثناء جلب الرحلات المتاحة.";
    } finally {
      _setLoading(false);
    }
  }

  /// إعادة تحميل/تحديث القائمة من السيرفر (قوة التحديث)
  Future<void> refreshAvailableTrips() async {
    await fetchAvailableTrips(forceRefresh: true);
  }

  /// جلب الرحلات الخاصة بسائق معين (مرتبة حسب createdAt تنازلياً)
  Future<void> fetchDriverTrips(String driverId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _driverTrips.isNotEmpty) {
      // إذا أردت دوماً تحديث من السيرفر، مرّر forceRefresh = true
    }

    _setLoading(true);
    _errorMessage = null;
    try {
      final trips = await _tripService.getDriverTrips(driverId);
      _driverTrips = trips;
      debugPrint("✅ تم جلب ${_driverTrips.length} رحلة خاصة بالسائق");
    } catch (e, st) {
      debugPrint("🔴 TripProvider.fetchDriverTrips error: $e\n$st");
      _errorMessage = "حدث خطأ أثناء جلب رحلاتك الخاصة كـ سائق.";
    } finally {
      _setLoading(false);
    }
  }

  /// جلب رحلة واحدة بواسطة المعرف (مفيد للشاشات التفصيلية)
  Future<Trip?> fetchTripById(String tripId, {bool forceRefresh = false}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final trip = await _tripService.getTripById(tripId);
      _setLoading(false);
      return trip;
    } catch (e, st) {
      debugPrint("🔴 TripProvider.fetchTripById error: $e\n$st");
      _errorMessage = "تعذر جلب بيانات الرحلة.";
      _setLoading(false);
      return null;
    }
  }

  /// إنشاء رحلة جديدة (للسائقين)
  /// يعيد tripId عند النجاح أو null عند الفشل
  Future<String?> createNewTrip(Trip trip) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final tripId = await _tripService.createTrip(trip);
      if (tripId != null) {
        // تحديث قائمة رحلات السائق بعد الإنشاء
        await fetchDriverTrips(trip.driverId, forceRefresh: true);
        // إعادة تحميل الرحلات المتاحة لأن رحلة جديدة قد تكون متاحة
        await fetchAvailableTrips(forceRefresh: true);
        return tripId;
      } else {
        _errorMessage = "تعذر إنشاء الرحلة. تأكد من توثيق حسابك ومركبتك.";
        return null;
      }
    } catch (e, st) {
      debugPrint("🔴 TripProvider.createNewTrip error: $e\n$st");
      _errorMessage = "خطأ غير متوقع أثناء إنشاء الرحلة.";
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث بيانات رحلة موجودة
  Future<bool> updateExistingTrip(String tripId, Trip updatedTrip) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final success = await _tripService.updateTrip(tripId, updatedTrip);
      if (success) {
        // إعادة جلب رحلات السائق لضمان التزامن
        await fetchDriverTrips(updatedTrip.driverId, forceRefresh: true);
        // إعادة تحميل الرحلات المتاحة لأن التحديث قد يؤثر عليها
        await fetchAvailableTrips(forceRefresh: true);
        return true;
      }
      _errorMessage = "فشل في تحديث الرحلة";
      return false;
    } catch (e, st) {
      debugPrint("🔴 TripProvider.updateExistingTrip error: $e\n$st");
      _errorMessage = "خطأ أثناء التحديث: $e";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// حذف رحلة
  Future<bool> removeTrip(String tripId, String driverId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final success = await _tripService.deleteTrip(tripId);
      if (success) {
        _driverTrips.removeWhere((t) => t.id == tripId);
        _availableTrips.removeWhere((t) => t.id == tripId);
        notifyListeners();
        return true;
      }
      _errorMessage = "فشل في حذف الرحلة";
      return false;
    } catch (e, st) {
      debugPrint("🔴 TripProvider.removeTrip error: $e\n$st");
      _errorMessage = "خطأ أثناء الحذف: $e";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// تغيير حالة الرحلة (active, cancelled, completed)
  Future<void> updateStatus(String tripId, String newStatus, String driverId) async {
    _errorMessage = null;
    try {
      await _tripService.changeTripStatus(tripId, newStatus);
      await fetchDriverTrips(driverId, forceRefresh: true);
      await fetchAvailableTrips(forceRefresh: true);
    } catch (e, st) {
      debugPrint("🔴 TripProvider.updateStatus error: $e\n$st");
      _errorMessage = "فشل تغيير حالة الرحلة.";
    }
  }

  /// تحديث حالة المقاعد محلياً ثم مزامنة مع السيرفيس
  Future<bool> updateSeatStatusLocally(String tripId, List<bool> seatStatus, int availableSeats) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final success = await _tripService.updateSeatStatus(tripId, seatStatus, availableSeats);
      if (success) {
        // تحديث القوائم المحلية إن كانت تحتوي الرحلة
        final idxA = _availableTrips.indexWhere((t) => t.id == tripId);
        if (idxA != -1) {
          _availableTrips[idxA] = _availableTrips[idxA].copyWith(
            seatStatus: seatStatus,
            availableSeats: availableSeats,
            updatedAt: Timestamp.now(),
          );
        }
        final idxD = _driverTrips.indexWhere((t) => t.id == tripId);
        if (idxD != -1) {
          _driverTrips[idxD] = _driverTrips[idxD].copyWith(
            seatStatus: seatStatus,
            availableSeats: availableSeats,
            updatedAt: Timestamp.now(),
          );
        }
        // تحديث النسخة الاحتياطية أيضاً
        final idxB = _availableTripsBackup.indexWhere((t) => t.id == tripId);
        if (idxB != -1) {
          _availableTripsBackup[idxB] = _availableTripsBackup[idxB].copyWith(
            seatStatus: seatStatus,
            availableSeats: availableSeats,
            updatedAt: Timestamp.now(),
          );
        }
        notifyListeners();
        return true;
      } else {
        _errorMessage = "فشل تحديث حالة المقاعد على السيرفر.";
        return false;
      }
    } catch (e, st) {
      debugPrint("🔴 TripProvider.updateSeatStatusLocally error: $e\n$st");
      _errorMessage = "خطأ أثناء تحديث المقاعد.";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// فلترة محلية سريعة (تستخدم الحقول origin, destination, tripCategory)
  /// إذا لم تُمرّر أي فلتر، تعيد النسخة الأصلية من القائمة
  void filterTrips({String? origin, String? destination, String? category}) {
    if ((origin == null || origin.isEmpty) && (destination == null || destination.isEmpty) && (category == null || category.isEmpty)) {
      // استرجع النسخة الاحتياطية
      _availableTrips = List<Trip>.from(_availableTripsBackup);
      notifyListeners();
      return;
    }

    final filtered = _availableTripsBackup.where((trip) {
      final matchOrigin = origin == null || origin.isEmpty || trip.origin.toLowerCase().contains(origin.toLowerCase());
      final matchDest = destination == null || destination.isEmpty || trip.destination.toLowerCase().contains(destination.toLowerCase());
      final matchCat = category == null || category.isEmpty || trip.tripCategory.toLowerCase() == category.toLowerCase();
      return matchOrigin && matchDest && matchCat;
    }).toList();

    _availableTrips = filtered;
    notifyListeners();
  }

  /// إعادة حساب رسوم الفرزة لرحلة واحدة (يدعو TripService.recomputeAndSetGovFeeForTrip)
  Future<bool> recomputeGovFeeForTrip(String tripId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final ok = await _tripService.recomputeAndSetGovFeeForTrip(tripId);
      if (ok) {
        // تحديث القوائم المحلية إن كانت تحتوي الرحلة
        final updatedTrip = await _tripService.getTripById(tripId);
        if (updatedTrip != null) {
          final idxA = _availableTrips.indexWhere((t) => t.id == tripId);
          if (idxA != -1) {
            _availableTrips[idxA] = updatedTrip;
          }
          final idxD = _driverTrips.indexWhere((t) => t.id == tripId);
          if (idxD != -1) {
            _driverTrips[idxD] = updatedTrip;
          }
          // تحديث النسخة الاحتياطية أيضاً
          final idxB = _availableTripsBackup.indexWhere((t) => t.id == tripId);
          if (idxB != -1) _availableTripsBackup[idxB] = updatedTrip;
          notifyListeners();
        }
        return true;
      } else {
        _errorMessage = "فشل إعادة حساب رسوم الفرزة للرحلة.";
        return false;
      }
    } catch (e, st) {
      debugPrint("🔴 TripProvider.recomputeGovFeeForTrip error: $e\n$st");
      _errorMessage = "خطأ أثناء إعادة حساب رسوم الفرزة.";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// إعادة حساب رسوم الفرزة لجميع الرحلات النشطة (يدعو TripService.recomputeGovFeesForAllActiveTrips)
  Future<int> recomputeGovFeesForAllActiveTrips({int limit = 500}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final updatedCount = await _tripService.recomputeGovFeesForAllActiveTrips(limit: limit);
      // بعد إعادة الحساب، نحدّث القوائم المحلية
      await fetchAvailableTrips(forceRefresh: true);
      await fetchDriverTripsForAllLoadedDrivers();
      return updatedCount;
    } catch (e, st) {
      debugPrint("🔴 TripProvider.recomputeGovFeesForAllActiveTrips error: $e\n$st");
      _errorMessage = "فشل إعادة حساب رسوم الفرزة لجميع الرحلات.";
      return 0;
    } finally {
      _setLoading(false);
    }
  }

  /// مساعدة: إعادة جلب رحلات السائقين الموجودين حالياً في الذاكرة (للمزامنة بعد عمليات على قواعد الرسوم)
  Future<void> fetchDriverTripsForAllLoadedDrivers() async {
    final driverIds = _driverTrips.map((t) => t.driverId).toSet().toList();
    for (final driverId in driverIds) {
      try {
        await fetchDriverTrips(driverId, forceRefresh: true);
      } catch (_) {}
    }
  }

  /// مساعدة: الحصول على فهرس رحلة في القوائم المحلية
  int indexOfTrip(String tripId) {
    final idxA = _availableTrips.indexWhere((t) => t.id == tripId);
    if (idxA != -1) return idxA;
    final idxD = _driverTrips.indexWhere((t) => t.id == tripId);
    return idxD;
  }
}
