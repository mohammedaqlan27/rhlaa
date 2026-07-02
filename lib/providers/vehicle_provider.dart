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

  void selectVehicleById(String? id) {
    if (id == null) {
      _selectedVehicle = null;
    } else {
      _selectedVehicle = _vehicles.firstWhere(
            (v) => v.id == id,
        orElse: () => _selectedVehicle ?? Vehicle(
          id: id,
          driverId: '',
          makeModelYear: '',
          maxCapacity: 0,
          plateNumber: '',
          vehicleOwner: '',
        ),
      );
    }
    notifyListeners();
  }

  Future<String?> addVehicle(Vehicle vehicle) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final id = await _vehicleService.createVehicle(vehicle);
      if (id != null) {
        await fetchDriverVehicles(vehicle.driverId);
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

  Future<bool> updateVehicle(String vehicleId, Vehicle updated) async {
    _setLoading(true);
    try {
      final ok = await _vehicleService.updateVehicle(vehicleId, updated);
      if (ok) {
        await fetchDriverVehicles(updated.driverId);
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

  Future<bool> removeVehicle(String vehicleId, String driverId) async {
    _setLoading(true);
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

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
