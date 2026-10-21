// lib/providers/trip_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trip.dart';
import '../models/app_user.dart';
import '../services/trip_service.dart';
import '../models/filter_result.dart';

class TripProvider with ChangeNotifier {
  final TripService _tripService;

  TripProvider({TripService? tripService})
      : _tripService = tripService ?? TripService();

  // بيانات محلية
  List<Trip> _availableTrips = [];
  List<Trip> _driverTrips = [];
  List<Trip> _availableTripsBackup = [];

  // cache by id
  final Map<String, Trip> _tripCache = {};

  // حالة
  bool _isLoading = false;
  String? _errorMessage;

  // Streams / subscriptions
  StreamSubscription<List<Trip>>? _availableTripsSub;
  StreamSubscription<List<Trip>>? _driverTripsSub;

  // Getters
  List<Trip> get availableTrips => List.unmodifiable(_availableTrips);
  List<Trip> get driverTrips => List.unmodifiable(_driverTrips);
  bool get isLoading => _isLoading;

  /// Getters مخصصة لشاشة إدارة الرحلات (تصنيف الرحلات النشطة والأرشيف)
  List<Trip> get activeDriverTrips => _driverTrips
      .where((t) =>
  t.status != 'ملغاة' &&
      t.status != 'مكتملة' &&
      t.status != 'cancelled' &&
      t.status != 'completed' &&
      t.status != 'closed')
      .toList();

  List<Trip> get pastDriverTrips => _driverTrips
      .where((t) =>
  t.status == 'ملغاة' ||
      t.status == 'مكتملة' ||
      t.status == 'cancelled' ||
      t.status == 'completed' ||
      t.status == 'closed')
      .toList();

  /// Compatibility alias: some widgets expect `provider.error`
  String? get errorMessage => _errorMessage;
  String? get error => _errorMessage;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // -------------------------
  // Helpers
  // -------------------------
  Future<T> _withRetry<T>(
      Future<T> Function() fn, {
        int retries = 2,
        Duration delay = const Duration(milliseconds: 200),
      }) async {
    var attempt = 0;
    var wait = delay;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        if (attempt > retries) rethrow;
        if (kDebugMode) {
          debugPrint('TripProvider retry #$attempt after error: $e');
        }
        await Future.delayed(wait);
        wait *= 2;
      }
    }
  }

  // -------------------------
  // Fetch / Streams
  // -------------------------

  Future<void> fetchAvailableTrips({bool forceRefresh = false}) async {
    if (!forceRefresh && _availableTrips.isNotEmpty) return;
    _setLoading(true);
    _setError(null);
    try {
      final trips = await _withRetry(() => _tripService.getAvailableTrips());
      _availableTrips = trips;
      _availableTripsBackup = List<Trip>.from(trips);
      for (final t in trips) {
        _tripCache[t.id] = t;
      }
      if (kDebugMode) {
        debugPrint('TripProvider: fetched ${trips.length} available trips');
      }
      notifyListeners();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('TripProvider.fetchAvailableTrips error: $e\n$st');
      }
      _setError('فشل جلب الرحلات المتاحة.');
    } finally {
      _setLoading(false);
    }
  }

  void watchAvailableTripsRealtime() {
    _availableTripsSub?.cancel();
    _setLoading(true);
    _availableTripsSub = _tripService.streamAvailableTrips().listen((trips) {
      _availableTrips = trips;
      _availableTripsBackup = List<Trip>.from(trips);
      for (final t in trips) {
        _tripCache[t.id] = t;
      }
      _setLoading(false);
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) {
        debugPrint('TripProvider.watchAvailableTripsRealtime error: $e');
      }
      _setError('خطأ في تحديث الرحلات المباشر.');
      _setLoading(false);
    });
  }

  void stopWatchingAvailableTrips() {
    _availableTripsSub?.cancel();
    _availableTripsSub = null;
  }

  Future<void> fetchDriverTrips(String driverId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _driverTrips.isNotEmpty) return;
    _setLoading(true);
    _setError(null);
    try {
      final trips = await _withRetry(() => _tripService.getDriverTrips(driverId));
      _driverTrips = trips;
      for (final t in trips) {
        _tripCache[t.id] = t;
      }
      if (kDebugMode) {
        debugPrint('TripProvider: fetched ${trips.length} driver trips');
      }
      notifyListeners();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('TripProvider.fetchDriverTrips error: $e\n$st');
      }
      _setError('فشل جلب رحلات السائق.');
    } finally {
      _setLoading(false);
    }
  }

  void watchDriverTripsRealtime(String driverId) {
    _driverTripsSub?.cancel();
    _setLoading(true);
    _driverTripsSub = _tripService.streamDriverTrips(driverId).listen((trips) {
      _driverTrips = trips;
      for (final t in trips) {
        _tripCache[t.id] = t;
      }
      _setLoading(false);
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) {
        debugPrint('TripProvider.watchDriverTripsRealtime error: $e');
      }
      _setError('خطأ في تحديث رحلات السائق المباشر.');
      _setLoading(false);
    });
  }

  void stopWatchingDriverTrips() {
    _driverTripsSub?.cancel();
    _driverTripsSub = null;
  }

  // -------------------------
  // Filtering helper (applies locally on backup list)
  // -------------------------
  void filterAvailableTrips({FilterResult? filter}) {
    if (filter == null) {
      _availableTrips = List<Trip>.from(_availableTripsBackup);
      notifyListeners();
      return;
    }

    final start = filter.priceStart ?? double.negativeInfinity;
    final end = filter.priceEnd ?? double.infinity;
    final vehicle = filter.vehicle;
    final onlyDirect = filter.onlyDirect ?? false;
    final activeOnly = filter.activeOnly ?? false;
    final from = filter.from;
    final to = filter.to;
    final direction = filter.direction;

    final filtered = _availableTripsBackup.where((t) {
      final priceOk = (t.price >= start && t.price <= end);
      final vehicleOk = (vehicle == null ||
          vehicle == 'الكل' ||
          vehicle.isEmpty ||
          t.vehicleType == vehicle);
      final directOk = !onlyDirect || true;
      final activeOk = (!activeOnly) ||
          (t.status == 'active' || t.status == 'open' || t.status == 'مفعّلة');
      final fromOk = (from == null) || (t.origin == from);
      final toOk = (to == null) || (t.destination == to);
      final directionOk = (direction == null) ||
          (direction == 'local' ? (t.origin == t.destination) : true);

      return priceOk &&
          vehicleOk &&
          directOk &&
          activeOk &&
          fromOk &&
          toOk &&
          directionOk;
    }).toList();

    _availableTrips = filtered;
    notifyListeners();
  }

  // -------------------------
  // CRUD Operations
  // -------------------------

  Future<Trip?> fetchTripById(String tripId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _tripCache.containsKey(tripId)) {
      return _tripCache[tripId];
    }
    _setLoading(true);
    _setError(null);
    try {
      final trip = await _withRetry(() => _tripService.getTripById(tripId));
      if (trip != null) _tripCache[trip.id] = trip;
      return trip;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('TripProvider.fetchTripById error: $e\n$st');
      }
      _setError('تعذر جلب بيانات الرحلة.');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> createNewTrip(Trip trip, AppUser? currentUser) async {
    _setLoading(true);
    _setError(null);

    AppUser? user = currentUser;
    if (user == null) {
      try {
        if (trip.driverId.isEmpty) {
          _setError('معرّف السائق غير متوفر.');
          _setLoading(false);
          return null;
        }
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(trip.driverId)
            .get();
        if (doc.exists) {
          try {
            user = AppUser.fromDocument(doc);
            if (kDebugMode) {
              debugPrint(
                  'TripProvider.createNewTrip: loaded AppUser from firestore for ${trip.driverId}');
            }
          } catch (e) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            user = AppUser(
              id: doc.id,
              name: data['name']?.toString() ?? '',
              email: data['email']?.toString() ?? '',
              plateNumber: data['carPlateNumber']?.toString() ??
                  data['plateNumber']?.toString() ??
                  '',
              vehicleIds: (data['vehicleIds'] is List)
                  ? List<String>.from(data['vehicleIds'])
                  : <String>[],
              agencyStatus: data['agencyStatus']?.toString(),
              uid: '',
              nickname: '',
              userType: '',
            );
            if (kDebugMode) {
              debugPrint(
                  'TripProvider.createNewTrip: built minimal AppUser fallback for ${trip.driverId}');
            }
          }
        } else {
          _setError('بيانات المستخدم غير موجودة.');
          _setLoading(false);
          return null;
        }
      } on FirebaseException catch (e, st) {
        if (kDebugMode) {
          debugPrint(
              'TripProvider.createNewTrip: failed to fetch user doc: $e\n$st');
        }
        _setError(
            'فشل في جلب بيانات المستخدم من الخادم: ${e.message ?? e.code}');
        _setLoading(false);
        return null;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
              'TripProvider.createNewTrip unexpected while loading user: $e\n$st');
        }
        _setError('خطأ غير متوقع أثناء جلب بيانات المستخدم.');
        _setLoading(false);
        return null;
      }
    }

    final hasPlate = (user?.plateNumber != null && user!.plateNumber!.trim().isNotEmpty);
    final hasVehicles = (user?.vehicleIds != null && user!.vehicleIds.isNotEmpty);
    final hasAgency = (user?.agencyStatus != null && user!.agencyStatus!.trim().isNotEmpty);

    if (!hasPlate && !hasVehicles && !hasAgency) {
      _setError('يجب إكمال بيانات المركبة وتحديد تبعية السائق قبل إنشاء الرحلة.');
      _setLoading(false);
      return null;
    }

    if ((trip.vehicleId == null || trip.vehicleId!.isEmpty) &&
        (trip.carPlateNumber == null || trip.carPlateNumber!.trim().isEmpty)) {
      if (hasVehicles) {
        final fallbackVehicleId = user!.vehicleIds.first;
        if (fallbackVehicleId.isNotEmpty) {
          trip = trip.copyWith(vehicleId: fallbackVehicleId);
          if (kDebugMode) {
            debugPrint(
                'TripProvider.createNewTrip: applied fallback vehicleId=$fallbackVehicleId');
          }
        }
      }
      if ((trip.vehicleId == null || trip.vehicleId!.isEmpty) &&
          (trip.carPlateNumber == null || trip.carPlateNumber!.trim().isEmpty)) {
        _setError('لا توجد بيانات مركبة كافية لإنشاء الرحلة.');
        _setLoading(false);
        return null;
      }
    }

    try {
      if (kDebugMode) {
        debugPrint(
            'TripProvider.createNewTrip: attempting to create trip for driver=${trip.driverId}');
      }
      final tripId = await _withRetry(() => _tripService.createTrip(trip));
      if (tripId != null && tripId.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('TripProvider.createNewTrip: created tripId=$tripId');
        }
        try {
          await fetchDriverTrips(trip.driverId, forceRefresh: true);
        } catch (_) {}
        try {
          await fetchAvailableTrips(forceRefresh: true);
        } catch (_) {}
        _setError(null);
        return tripId;
      } else {
        _setError('تعذر إنشاء الرحلة.');
        return null;
      }
    } on FirebaseException catch (e, st) {
      if (kDebugMode) {
        debugPrint('TripProvider.createNewTrip FirebaseException: $e\n$st');
      }
      _setError('خطأ في الاتصال بقاعدة البيانات: ${e.message ?? e.code}');
      return null;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('TripProvider.createNewTrip unexpected error: $e\n$st');
      }
      _setError('خطأ أثناء إنشاء الرحلة.');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateExistingTrip(String tripId, Trip updatedTrip) async {
    _setLoading(true);
    _setError(null);
    try {
      final ok = await _withRetry(() => _tripService.updateTrip(tripId, updatedTrip));
      if (ok) {
        await fetchDriverTrips(updatedTrip.driverId, forceRefresh: true);
        await fetchAvailableTrips(forceRefresh: true);
        return true;
      }
      _setError('فشل في تحديث الرحلة.');
      return false;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('TripProvider.updateExistingTrip error: $e\n$st');
      }
      _setError('خطأ أثناء تحديث الرحلة.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> removeTrip(String tripId, String driverId) async {
    _setLoading(true);
    _setError(null);
    try {
      final ok = await _withRetry(() => _tripService.deleteTrip(tripId));
      if (ok) {
        _driverTrips.removeWhere((t) => t.id == tripId);
        _availableTrips.removeWhere((t) => t.id == tripId);
        notifyListeners();
        return true;
      }
      _setError('فشل في حذف الرحلة.');
      return false;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('TripProvider.removeTrip error: $e\n$st');
      }
      _setError('خطأ أثناء حذف الرحلة.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث حالة الرحلة (يدعم التحديث المحلي التفاعلي الأسرع للمستخدم Optimistic Update)
  Future<bool> updateStatus(String tripId, String newStatus, String driverId) async {
    _setError(null);

    // 1. تحديث الحالة محلياً أولاً لتجاوب فوري في الواجهة
    final driverIdx = _driverTrips.indexWhere((t) => t.id == tripId);
    Trip? originalDriverTrip;
    if (driverIdx != -1) {
      originalDriverTrip = _driverTrips[driverIdx];
      _driverTrips[driverIdx] = originalDriverTrip.copyWith(status: newStatus);
    }

    final availIdx = _availableTrips.indexWhere((t) => t.id == tripId);
    Trip? originalAvailTrip;
    if (availIdx != -1) {
      originalAvailTrip = _availableTrips[availIdx];
      _availableTrips[availIdx] = originalAvailTrip.copyWith(status: newStatus);
    }
    notifyListeners();

    // 2. تحديث التغيير على قاعدة البيانات Firestore
    try {
      await _withRetry(() => _tripService.changeTripStatus(tripId, newStatus));
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('TripProvider.updateStatus error: $e\n$st');
      }
      // التراجع عن التحديث المحلي في حال الفشل
      if (driverIdx != -1 && originalDriverTrip != null) {
        _driverTrips[driverIdx] = originalDriverTrip;
      }
      if (availIdx != -1 && originalAvailTrip != null) {
        _availableTrips[availIdx] = originalAvailTrip;
      }
      _setError('فشل تغيير حالة الرحلة.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> closeTrip(String tripId) async {
    _setLoading(true);
    _setError(null);
    try {
      Trip? trip;
      if (_tripCache.containsKey(tripId)) {
        trip = _tripCache[tripId];
      } else {
        final idxDriver = _driverTrips.indexWhere((t) => t.id == tripId);
        if (idxDriver != -1) {
          trip = _driverTrips[idxDriver];
        } else {
          final idxAvail = _availableTrips.indexWhere((t) => t.id == tripId);
          if (idxAvail != -1) trip = _availableTrips[idxAvail];
        }
      }

      final driverId = trip?.driverId ?? '';
      final success = await updateStatus(tripId, 'closed', driverId);
      _setLoading(false);
      return success;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('TripProvider.closeTrip error: $e\n$st');
      }
      _setError('فشل إغلاق الرحلة.');
      _setLoading(false);
      return false;
    }
  }

  @override
  void dispose() {
    _availableTripsSub?.cancel();
    _driverTripsSub?.cancel();
    super.dispose();
  }
}