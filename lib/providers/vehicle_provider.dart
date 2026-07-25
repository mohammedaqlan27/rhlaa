// lib/providers/vehicle_provider.dart
import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../services/vehicle_service.dart';

class VehicleProvider with ChangeNotifier {
  final VehicleService _vehicleService = VehicleService();

  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
  bool _isLoading = false;
  String? _errorMessage;

  List<Vehicle> get vehicles => _vehicles;
  Vehicle? get selectedVehicle => _selectedVehicle;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  VehicleProvider();

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// جلب مركبات السائق/المالك بناءً على الحقل الموحد vehicleOwner
  Future<void> fetchDriverVehicles(String driverId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _vehicles = await _vehicleService.getDriverVehicles(driverId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'فشل في جلب المركبات: $e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  /// اختيار مركبة حسب المعرف. إذا لم توجد، ننشئ كائن مؤقت بالحقل id فقط
  void selectVehicleById(String? id) {
    if (id == null) {
      _selectedVehicle = null;
    } else {
      try {
        _selectedVehicle = _vehicles.firstWhere((v) => v.id == id);
      } catch (_) {
        // إنشاء مركبة افتراضية مؤقتة للحفاظ على نوعية البيانات
        _selectedVehicle = Vehicle(
          id: id,
          plateNumber: '',
          vehicleOwner: '',
          vehicleType: '',
          makeModelYear: '',
          color: '',
          maxCapacity: 0,
          licenseNumber: '',
          isVerified: false,
          notes: '',
        );
      }
    }
    notifyListeners();
  }

  /// إضافة مركبة جديدة، يعيد معرف المستند عند النجاح
  Future<String?> addVehicle(Vehicle vehicle) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final id = await _vehicleService.createVehicle(vehicle);
      if (id != null) {
        // إعادة جلب قائمة المركبات للمالك/السائق
        await fetchDriverVehicles(vehicle.vehicleOwner);
        return id;
      } else {
        _errorMessage = 'تعذر إضافة المركبة';
        return null;
      }
    } catch (e) {
      _errorMessage = 'خطأ أثناء إضافة المركبة: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث مركبة موجودة
  Future<bool> updateVehicle(String vehicleId, Vehicle updated) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final ok = await _vehicleService.updateVehicle(vehicleId, updated);
      if (ok) {
        // إعادة جلب المركبات للمالك/السائق لضمان التزامن
        await fetchDriverVehicles(updated.vehicleOwner);
        // تحديث المحدد محلياً إن كان هو نفسه
        if (_selectedVehicle?.id == vehicleId) {
          _selectedVehicle = updated.copyWith(id: vehicleId);
        }
        return true;
      }
      _errorMessage = 'فشل في تحديث المركبة';
      return false;
    } catch (e) {
      _errorMessage = 'خطأ أثناء التحديث: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// حذف مركبة
  Future<bool> removeVehicle(String vehicleId, String driverId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final ok = await _vehicleService.deleteVehicle(vehicleId);
      if (ok) {
        _vehicles.removeWhere((v) => v.id == vehicleId);
        if (_selectedVehicle?.id == vehicleId) _selectedVehicle = null;
        notifyListeners();
        return true;
      }
      _errorMessage = 'فشل في حذف المركبة';
      return false;
    } catch (e) {
      _errorMessage = 'خطأ أثناء الحذف: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
