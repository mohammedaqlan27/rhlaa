// lib/providers/vehicle_provider.dart
import 'package:flutter/foundation.dart';
import '../models/vehicle.dart';
import '../services/vehicle_service.dart';

/// VehicleProvider
/// - يحافظ على قائمة المركبات للمستخدم الحالي (driver/owner)
/// - يدير المركبة المحددة selectedVehicle
/// - يعيد جلب البيانات بعد الإضافة/التحديث/الحذف لضمان التزامن
class VehicleProvider with ChangeNotifier {
  final VehicleService _vehicleService;

  VehicleProvider({VehicleService? vehicleService})
      : _vehicleService = vehicleService ?? VehicleService();

  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
  bool _isLoading = false;
  String? _errorMessage;

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  Vehicle? get selectedVehicle => _selectedVehicle;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  /// جلب مركبات السائق/المالك بناءً على driverId أو ownerId
  /// driverId قد يكون uid للسائق أو owner identifier
  Future<void> fetchDriverVehicles(String driverId) async {
    _setLoading(true);
    _setError(null);
    try {
      final list = await _vehicleService.getDriverVehicles(driverId);
      _vehicles = list ?? [];

      // إذا لم تكن هناك مركبة محددة، عين الأولى تلقائياً
      if (_selectedVehicle == null && _vehicles.isNotEmpty) {
        _selectedVehicle = _vehicles.first;
      } else if (_selectedVehicle != null) {
        // إذا كانت المركبة المحددة موجودة في القائمة، حدّثها من القائمة
        final found = _vehicles.firstWhere(
              (v) => v.id == _selectedVehicle!.id,
          orElse: () => _selectedVehicle!,
        );
        _selectedVehicle = found;
      }

      notifyListeners();
    } catch (e, st) {
      _setError('فشل في جلب المركبات: $e');
      if (kDebugMode) {
        debugPrint('VehicleProvider.fetchDriverVehicles error: $e\n$st');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// اختيار مركبة محلياً حسب المعرف.
  /// إذا لم توجد في القائمة، ننشئ كائنًا مؤقتًا (يمكن لاحقاً استبداله بجلب فعلي).
  void selectVehicleById(String? id) {
    if (id == null || id.isEmpty) {
      _selectedVehicle = null;
      notifyListeners();
      return;
    }

    final found = _vehicles.where((v) => v.id == id).toList();
    if (found.isNotEmpty) {
      _selectedVehicle = found.first;
      notifyListeners();
      return;
    }

    // إنشاء مركبة افتراضية مؤقتة للحفاظ على نوعية البيانات
    _selectedVehicle = Vehicle(
      id: id,
      plateNumber: '',
      vehicleOwner: '',
      ownerId: null,
      driverId: null,
      driverName: null,
      vehicleType: '',
      makeModelYear: '',
      color: '',
      maxCapacity: 0,
      licenseNumber: '',
      isVerified: false,
      sGovernmentRegistered: false,
      notes: '',
      extra: null,
      vehicleDocuments: const [],
      insuranceExpiryDate: null,
      lastInspectionDate: null,
      carOwnerOfficialName: '',
      createdAt: null,
      updatedAt: null,
    );
    notifyListeners();
  }

  /// محاولة جلب مركبة واحدة من الخدمة وتعيينها كمحددة
  Future<void> selectVehicleByIdAsync(String id) async {
    if (id.isEmpty) {
      _selectedVehicle = null;
      notifyListeners();
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final doc = await _vehicleService.getVehicleById(id);
      if (doc != null) {
        _selectedVehicle = doc;
        // إذا لم تكن موجودة في القائمة، أضفها مؤقتاً
        final exists = _vehicles.any((v) => v.id == doc.id);
        if (!exists) {
          _vehicles = [doc, ..._vehicles];
        }
      } else {
        // إذا لم تُرجع الخدمة شيئًا، أنشئ كائنًا مؤقتًا
        selectVehicleById(id);
      }
      notifyListeners();
    } catch (e, st) {
      _setError('فشل في جلب بيانات المركبة: $e');
      if (kDebugMode) debugPrint('selectVehicleByIdAsync error: $e\n$st');
    } finally {
      _setLoading(false);
    }
  }

  /// إضافة مركبة جديدة، يعيد معرف المستند عند النجاح
  /// vehicle.ownerId أو vehicle.driverId يجب أن يحتوي على المعرف المستخدم لربط المركبة
  Future<String?> addVehicle(Vehicle vehicle) async {
    _setLoading(true);
    _setError(null);
    try {
      final id = await _vehicleService.createVehicle(vehicle);
      if (id != null && id.isNotEmpty) {
        // إعادة جلب قائمة المركبات للمالك/السائق
        final ownerKey = vehicle.ownerId ?? vehicle.driverId ?? vehicle.vehicleOwner;
        if (ownerKey.toString().isNotEmpty) {
          await fetchDriverVehicles(ownerKey.toString());
        } else {
          // إذا لم نعرف المالك، نجلب كل المركبات مرة واحدة (fallback)
          _vehicles = await _vehicleService.getAllVehicles() ?? [];
        }

        // تعيين المركبة الجديدة كمحددة محلياً إن أمكن
        final newVehicle = _vehicles.firstWhere((v) => v.id == id, orElse: () => vehicle.copyWith(id: id));
        _selectedVehicle = newVehicle;
        notifyListeners();
        return id;
      } else {
        _setError('تعذر إضافة المركبة');
        return null;
      }
    } catch (e, st) {
      _setError('خطأ أثناء إضافة المركبة: $e');
      if (kDebugMode) debugPrint('addVehicle error: $e\n$st');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث مركبة موجودة
  Future<bool> updateVehicle(String vehicleId, Vehicle updated) async {
    _setLoading(true);
    _setError(null);
    try {
      final ok = await _vehicleService.updateVehicle(vehicleId, updated);
      if (ok) {
        // إعادة جلب المركبات للمالك/السائق لضمان التزامن
        final ownerKey = updated.ownerId ?? updated.driverId ?? updated.vehicleOwner;
        if (ownerKey.toString().isNotEmpty) {
          await fetchDriverVehicles(ownerKey.toString());
        } else {
          // تحديث محلي إن لم نتمكن من إعادة الجلب
          final idx = _vehicles.indexWhere((v) => v.id == vehicleId);
          if (idx >= 0) {
            _vehicles[idx] = updated.copyWith(id: vehicleId);
          }
        }

        // تحديث المحدد محلياً إن كان هو نفسه
        if (_selectedVehicle?.id == vehicleId) {
          _selectedVehicle = updated.copyWith(id: vehicleId);
        }
        notifyListeners();
        return true;
      }
      _setError('فشل في تحديث المركبة');
      return false;
    } catch (e, st) {
      _setError('خطأ أثناء التحديث: $e');
      if (kDebugMode) debugPrint('updateVehicle error: $e\n$st');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// حذف مركبة
  Future<bool> removeVehicle(String vehicleId, {String? ownerId}) async {
    _setLoading(true);
    _setError(null);
    try {
      final ok = await _vehicleService.deleteVehicle(vehicleId);
      if (ok) {
        _vehicles.removeWhere((v) => v.id == vehicleId);
        if (_selectedVehicle?.id == vehicleId) _selectedVehicle = null;
        // إعادة جلب القائمة إن وُجد ownerId
        if (ownerId != null && ownerId.isNotEmpty) {
          await fetchDriverVehicles(ownerId);
        }
        notifyListeners();
        return true;
      }
      _setError('فشل في حذف المركبة');
      return false;
    } catch (e, st) {
      _setError('خطأ أثناء الحذف: $e');
      if (kDebugMode) debugPrint('removeVehicle error: $e\n$st');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// مساعدة: مسح الاختيار الحالي
  void clearSelection() {
    _selectedVehicle = null;
    notifyListeners();
  }

  /// مساعدة: تعيين مركبة محددة مباشرة
  void setSelectedVehicle(Vehicle? v) {
    _selectedVehicle = v;
    notifyListeners();
  }
}
