// lib/providers/agencies_provider.dart
import 'package:flutter/material.dart';
import '../services/agencies_service.dart';
import '../models/agency.dart';
import '../models/agency_transaction.dart';

class AgenciesProvider with ChangeNotifier {
  final AgenciesService _service;

  AgenciesProvider({AgenciesService? service}) : _service = service ?? AgenciesService();

  bool _isLoading = false;
  String? _error;
  List<Agency> _agencies = [];
  Agency? _currentAgency;
  List<AgencyTransaction> _transactions = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Agency> get agencies => List.unmodifiable(_agencies);
  Agency? get currentAgency => _currentAgency;
  List<AgencyTransaction> get transactions => List.unmodifiable(_transactions);

  // Internal helpers
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  void _setAgencies(List<Agency> list) {
    _agencies = list;
    notifyListeners();
  }

  void _setCurrentAgency(Agency? a) {
    _currentAgency = a;
    notifyListeners();
  }

  void _setTransactions(List<AgencyTransaction> list) {
    _transactions = list;
    notifyListeners();
  }

  // Public API

  Future<void> loadAgencies({bool onlyActive = false}) async {
    _setLoading(true);
    _setError(null);
    try {
      final list = await _service.fetchAllAgencies(onlyActive: onlyActive);
      _setAgencies(list);
    } catch (e) {
      _setError('فشل جلب المكاتب: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAgencyById(String id) async {
    _setLoading(true);
    _setError(null);
    try {
      final a = await _service.getAgencyById(id);
      if (a == null) {
        _setError('المكتب غير موجود');
      } else {
        _setCurrentAgency(a);
        await loadTransactions(id);
      }
    } catch (e) {
      _setError('فشل جلب بيانات المكتب: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createAgency({
    required String agencyName,
    required String managerName,
    required dynamic location,
    required String mobileNumber,
    double initialBalance = 0.0,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final id = await _service.createAgency(
        agencyName: agencyName,
        managerName: managerName,
        location: location,
        mobileNumber: mobileNumber,
        initialBalance: initialBalance,
      );
      await loadAgencies();
      await loadAgencyById(id);
      return true;
    } catch (e) {
      _setError('فشل إنشاء المكتب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateAgency(String id, Map<String, dynamic> updates) async {
    _setLoading(true);
    _setError(null);
    try {
      await _service.updateAgency(id, updates);
      await loadAgencies();
      if (_currentAgency != null && _currentAgency!.id == id) {
        await loadAgencyById(id);
      }
      return true;
    } catch (e) {
      _setError('فشل تحديث المكتب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAgency(String id) async {
    _setLoading(true);
    _setError(null);
    try {
      await _service.deleteAgency(id);
      await loadAgencies();
      if (_currentAgency != null && _currentAgency!.id == id) {
        _setCurrentAgency(null);
      }
      return true;
    } catch (e) {
      _setError('فشل حذف المكتب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> setAgencyActive(String id, bool isActive) async {
    _setLoading(true);
    _setError(null);
    try {
      await _service.setAgencyActive(id, isActive);
      await loadAgencies();
      if (_currentAgency != null && _currentAgency!.id == id) {
        await loadAgencyById(id);
      }
      return true;
    } catch (e) {
      _setError('فشل تغيير حالة المكتب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> creditAgencyWallet(String id, double amount, {String? reason, String? performedBy}) async {
    _setLoading(true);
    _setError(null);
    try {
      await _service.creditWallet(id, amount, reason: reason, performedBy: performedBy);
      await loadAgencyById(id);
      await loadAgencies();
      return true;
    } catch (e) {
      _setError('فشل شحن رصيد المكتب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> debitAgencyWallet(String id, double amount, {String? reason, String? performedBy}) async {
    _setLoading(true);
    _setError(null);
    try {
      await _service.debitWallet(id, amount, reason: reason, performedBy: performedBy);
      await loadAgencyById(id);
      await loadAgencies();
      return true;
    } catch (e) {
      _setError('فشل خصم من رصيد المكتب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTransactions(String agencyId, {int limit = 100}) async {
    _setLoading(true);
    _setError(null);
    try {
      final list = await _service.fetchTransactions(agencyId, limit: limit);
      _setTransactions(list);
    } catch (e) {
      _setError('فشل جلب سجل المعاملات: $e');
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _setError(null);
  }
}
