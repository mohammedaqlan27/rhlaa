import 'dart:async';
import 'package:flutter/material.dart';
import '../services/agencies_service.dart';
import '../models/agency.dart';
import '../models/agency_transaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgenciesProvider with ChangeNotifier {
  final AgenciesService _service;

  AgenciesProvider({AgenciesService? service}) : _service = service ?? AgenciesService();

  // --- الحالة الداخلية (State) ---
  bool _isLoading = false;
  String? _error;
  List<Agency> _agencies = [];
  List<Agency> _filteredAgencies = []; // للبحث والفلترة
  Agency? _currentAgency;
  List<AgencyTransaction> _transactions = [];
  double _totalBalance = 0.0; // إجمالي السيولة

  // الاشتراكات اللحظية (Real-time Subscriptions)
  StreamSubscription? _realtimeSub;
  StreamSubscription? _currentAgencySub;

  // --- Getters ---
  bool get isLoading => _isLoading;
  String? get error => _error;

  // عرض القائمة المفلترة إذا وجد بحث، وإلا عرض القائمة الكاملة
  List<Agency> get agencies => _filteredAgencies.isEmpty && _error == null ? _agencies : _filteredAgencies;

  Agency? get currentAgency => _currentAgency;
  List<AgencyTransaction> get transactions => List.unmodifiable(_transactions);
  double get totalBalance => _totalBalance;

  // --- Internal helpers ---
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
    _filteredAgencies = list;
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

  void clearError() {
    _setError(null);
  }

  // =============================================================
  // 1. عمليات CRUD الأساسية (نفس خدماتك الأصلية دون حذف)
  // =============================================================

  Future<void> loadAgencies({bool onlyActive = false}) async {
    _setLoading(true);
    _setError(null);
    try {
      final list = await _service.fetchAllAgencies(onlyActive: onlyActive);
      _setAgencies(list);
      await loadTotalBalance(); // تحديث السيولة تلقائياً
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
        listenToAgency(id); // تفعيل التحديث اللحظي للمكتب المختار
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
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception:', ''));
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

  // =============================================================
  // 2. عمليات المحفظة والسيولة (نفس خدماتك الأصلية)
  // =============================================================

  Future<bool> creditAgencyWallet(String id, double amount, {String? reason, String? performedBy}) async {
    _setLoading(true);
    _setError(null);
    try {
      await _service.creditWallet(id, amount, reason: reason, performedBy: performedBy);
      await loadTotalBalance();
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
      await loadTotalBalance();
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception:', ''));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTotalBalance() async {
    _totalBalance = await _service.getTotalAgenciesBalance();
    notifyListeners();
  }

  // =============================================================
  // 3. البحث والفلترة وسجل المعاملات
  // =============================================================

  /// البحث في السيرفر (ميزة احترافية مضافة)
  Future<void> searchAgencies(String query) async {
    if (query.isEmpty) {
      _filteredAgencies = _agencies;
      notifyListeners();
      return;
    }
    _setLoading(true);
    try {
      _filteredAgencies = await _service.searchAgencies(query);
    } catch (e) {
      _setError('خطأ في البحث: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTransactions(String agencyId, {int limit = 100}) async {
    try {
      final list = await _service.fetchTransactions(agencyId, limit: limit);
      _setTransactions(list);
    } catch (e) {
      _setError('فشل جلب سجل المعاملات: $e');
    }
  }

  // =============================================================
  // 4. الاستماع اللحظي (Real-time)
  // =============================================================

  void listenToAgency(String id) {
    _currentAgencySub?.cancel();
    _currentAgencySub = _service.getAgencyStream(id).listen((agency) {
      _currentAgency = agency;
      notifyListeners();
    });
  }

  void startRealtimeListener() {
    _realtimeSub?.cancel();
    _realtimeSub = FirebaseFirestore.instance
        .collection('agencies')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _agencies = snap.docs.map((d) => Agency.fromDoc(d)).toList();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _currentAgencySub?.cancel();
    super.dispose();
  }
}