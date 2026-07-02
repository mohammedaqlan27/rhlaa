// lib/providers/trip_provider.dart
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/trip_service.dart';

class TripProvider with ChangeNotifier {
  final TripService _tripService = TripService();

  List<Trip> _availableTrips = [];
  List<Trip> _driverTrips = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Trip> get availableTrips => _availableTrips;
  List<Trip> get driverTrips => _driverTrips;
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

  /// جلب جميع الرحلات المتاحة (للركاب)
  Future<void> fetchAvailableTrips() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _availableTrips = await _tripService.getAvailableTrips();
      debugPrint("✅ تم جلب ${_availableTrips.length} رحلة متاحة للركاب");
    } catch (e) {
      debugPrint("🔴 خطأ أثناء جلب الرحلات المتاحة: $e");
      _errorMessage = "حدث خطأ أثناء جلب الرحلات المتاحة.";
    } finally {
      _setLoading(false);
    }
  }

  /// جلب الرحلات الخاصة بسائق معين
  Future<void> fetchDriverTrips(String driverId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _driverTrips = await _tripService.getDriverTrips(driverId);
      debugPrint("✅ تم جلب ${_driverTrips.length} رحلة خاصة بالسائق");
    } catch (e) {
      debugPrint("🔴 خطأ أثناء جلب رحلات السائق: $e");
      _errorMessage = "حدث خطأ أثناء جلب رحلاتك الخاصة كـ سائق.";
    } finally {
      _setLoading(false);
    }
  }

  /// إنشاء رحلة جديدة (للسائقين)
  Future<String?> createNewTrip(Trip trip) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final tripId = await _tripService.createTrip(trip);
      if (tripId != null) {
        await fetchDriverTrips(trip.driverId);
        return tripId;
      } else {
        _errorMessage = "تعذر إنشاء الرحلة. تأكد من توثيق حسابك ومركبتك.";
        return null;
      }
    } catch (e) {
      _errorMessage = "خطأ غير متوقع: $e";
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث بيانات رحلة موجودة
  Future<bool> updateExistingTrip(String tripId, Trip updatedTrip) async {
    _setLoading(true);
    try {
      final success = await _tripService.updateTrip(tripId, updatedTrip);
      if (success) {
        await fetchDriverTrips(updatedTrip.driverId);
        return true;
      }
      _errorMessage = "فشل في تحديث الرحلة";
      return false;
    } catch (e) {
      _errorMessage = "خطأ أثناء التحديث: $e";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// حذف رحلة
  Future<bool> removeTrip(String tripId, String driverId) async {
    _setLoading(true);
    try {
      final success = await _tripService.deleteTrip(tripId);
      if (success) {
        _driverTrips.removeWhere((t) => t.id == tripId);
        notifyListeners();
        return true;
      }
      _errorMessage = "فشل في حذف الرحلة";
      return false;
    } catch (e) {
      _errorMessage = "خطأ أثناء الحذف: $e";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// تغيير حالة الرحلة
  Future<void> updateStatus(String tripId, String newStatus, String driverId) async {
    try {
      await _tripService.changeTripStatus(tripId, newStatus);
      await fetchDriverTrips(driverId);
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  /// فلترة محلية سريعة
  void filterTrips({String? origin, String? destination, String? category}) {
    if (origin == null && destination == null && category == null) {
      fetchAvailableTrips();
      return;
    }

    _availableTrips = _availableTrips.where((trip) {
      final matchOrigin = origin == null || trip.origin.toLowerCase().contains(origin.toLowerCase());
      final matchDest = destination == null || trip.destination.toLowerCase().contains(destination.toLowerCase());
      final matchCat = category == null || trip.tripCategory == category;
      return matchOrigin && matchDest && matchCat;
    }).toList();

    notifyListeners();
  }
}
