// lib/providers/agencies_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/agencies_service.dart';
import '../models/agency.dart';
import '../models/agency_transaction.dart';

/// مزود مسؤول عن إدارة حالة المكاتب (Agencies)
/// يجمع بين مزايا النسختين:
/// - تحميل القوائم (مرّة أو في الوقت الحقيقي)
/// - CRUD للمكاتب
/// - عمليات المحفظة (شحن/خصم)
/// - جلب سجل المعاملات
/// - بحث وفلترة محلية وسيرفرية
class AgenciesProvider with ChangeNotifier {
  final AgenciesService _service;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AgenciesProvider({AgenciesService? service}) : _service = service ?? AgenciesService();

  // --- الحالة الداخلية ---
  bool _isLoading = false;
  String? _error;
  List<Agency> _agencies = [];
  List<Agency> _filteredAgencies = [];
  Agency? _currentAgency;
  List<AgencyTransaction> _transactions = [];
  double _totalBalance = 0.0;

  // الاشتراكات اللحظية
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _realtimeSub;
  StreamSubscription<Agency?>? _currentAgencySub;

  // --- Getters ---
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Agency> get agencies =>
      _filteredAgencies.isNotEmpty ? List.unmodifiable(_filteredAgencies) : List.unmodifiable(_agencies);
  Agency? get currentAgency => _currentAgency;
  List<AgencyTransaction> get transactions => List.unmodifiable(_transactions);
  double get totalBalance => _totalBalance;

  // --- Helpers ---
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
    // إذا كانت هناك فلترة محفوظة، نعيد تطبيقها
    if (_filteredAgencies.isNotEmpty) {
      filterLocal();
    } else {
      _filteredAgencies = [];
    }
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

  void clearError() => _setError(null);

  // =============================================================
  // 1. CRUD
  // =============================================================
  Future<void> loadAgencies({bool onlyActive = false}) async {
    _setLoading(true);
    _setError(null);
    try {
      final list = await _service.fetchAllAgencies(onlyActive: onlyActive);
      _setAgencies(list);
      await loadTotalBalance();
    } catch (e, st) {
      debugPrint('AgenciesProvider.loadAgencies error: $e\n$st');
      _setError('فشل جلب المكاتب: ${e.toString()}');
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
        _setCurrentAgency(null);
      } else {
        _setCurrentAgency(a);
        listenToAgency(id);
        await loadTransactions(id);
      }
    } catch (e, st) {
      debugPrint('AgenciesProvider.loadAgencyById error: $e\n$st');
      _setError('فشل جلب بيانات المكتب: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// تحميل المكتب المرتبط بالمستخدم الحالي (حسب authUid داخل مستند المكتب)
  Future<void> loadAgencyForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      _setError('لا يوجد مستخدم مسجل حالياً');
      return;
    }
    await loadAgencyByAuthUid(user.uid);
  }

  /// تحميل مكتب حسب authUid (مفيد عندما يكون المستخدم مسجل في Auth ومربوط بمكتب)
  Future<void> loadAgencyByAuthUid(String authUid) async {
    _setLoading(true);
    _setError(null);
    try {
      // نبحث في مجموعة 'agencies' عن المستند الذي يحتوي الحقل authUid == authUid
      final snap = await _firestore
          .collection('agencies')
          .where('authUid', isEqualTo: authUid)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        _setError('لا يوجد مكتب مرتبط بهذا المستخدم');
        _setCurrentAgency(null);
        _setTransactions([]);
        return;
      }

      final doc = snap.docs.first;
      final agency = Agency.fromDoc(doc);
      _setCurrentAgency(agency);
      listenToAgency(agency.id);
      await loadTransactions(agency.id);
    } catch (e, st) {
      debugPrint('AgenciesProvider.loadAgencyByAuthUid error: $e\n$st');
      _setError('فشل جلب المكتب المرتبط: ${e.toString()}');
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
    String? email,
    String? authUid,
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
        authUid: authUid,
        email: email,
      );
      await loadAgencies();
      await loadAgencyById(id);
      return true;
    } catch (e, st) {
      debugPrint('AgenciesProvider.createAgency error: $e\n$st');
      _setError(e.toString().replaceAll('Exception:', '').trim());
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
      if (_currentAgency?.id == id) await loadAgencyById(id);
      return true;
    } catch (e, st) {
      debugPrint('AgenciesProvider.updateAgency error: $e\n$st');
      _setError('فشل تحديث المكتب: ${e.toString()}');
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
      if (_currentAgency?.id == id) _setCurrentAgency(null);
      return true;
    } catch (e, st) {
      debugPrint('AgenciesProvider.deleteAgency error: $e\n$st');
      _setError('فشل حذف المكتب: ${e.toString()}');
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
      if (_currentAgency?.id == id) await loadAgencyById(id);
      return true;
    } catch (e, st) {
      debugPrint('AgenciesProvider.setAgencyActive error: $e\n$st');
      _setError('فشل تغيير حالة المكتب: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =============================================================
  // 2. المحفظة
  // =============================================================
  Future<bool> creditAgencyWallet(String id, double amount, {String? reason, String? performedBy}) async {
    _setLoading(true);
    _setError(null);
    try {
      await _service.creditWallet(id, amount, reason: reason, performedBy: performedBy);
      await loadTotalBalance();
      if (_currentAgency?.id == id) await loadAgencyById(id);
      return true;
    } catch (e, st) {
      debugPrint('AgenciesProvider.creditAgencyWallet error: $e\n$st');
      _setError('فشل شحن رصيد المكتب: ${e.toString()}');
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
      if (_currentAgency?.id == id) await loadAgencyById(id);
      return true;
    } catch (e, st) {
      debugPrint('AgenciesProvider.debitAgencyWallet error: $e\n$st');
      _setError(e.toString().replaceAll('Exception:', '').trim());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTotalBalance() async {
    try {
      _totalBalance = await _service.getTotalAgenciesBalance();
      notifyListeners();
    } catch (e, st) {
      debugPrint('AgenciesProvider.loadTotalBalance error: $e\n$st');
      _setError('فشل جلب إجمالي السيولة: ${e.toString()}');
    }
  }

  // =============================================================
  // 3. البحث والفلترة
  // =============================================================
  Future<void> searchAgencies(String query) async {
    if (query.trim().isEmpty) {
      _filteredAgencies.clear();
      notifyListeners();
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final results = await _service.searchAgencies(query.trim());
      _filteredAgencies = results;
      notifyListeners();
    } catch (e, st) {
      debugPrint('AgenciesProvider.searchAgencies error: $e\n$st');
      _setError('خطأ في البحث: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// فلترة محلية سريعة (بدون استدعاء السيرفر)
  void filterLocal({String? query, bool? onlyActive}) {
    final q = query?.trim().toLowerCase();
    List<Agency> filtered = _agencies;
    if (q != null && q.isNotEmpty) {
      filtered = filtered.where((a) {
        final name = a.agencyName.toLowerCase();
        final manager = a.managerName.toLowerCase();
        final phone = a.mobileNumber.toLowerCase();
        return name.contains(q) || manager.contains(q) || phone.contains(q);
      }).toList();
    }
    if (onlyActive != null) {
      filtered = filtered.where((a) => a.isActive == onlyActive).toList();
    }
    _filteredAgencies = filtered;
    notifyListeners();
  }

  /// جلب سجل المعاملات للمكتب مع دعم حد النتائج وفلاتر زمنية بسيطة
  Future<void> loadTransactions(String agencyId, {int limit = 100, DateTime? from, DateTime? to}) async {
    _setError(null);
    try {
      // إذا كانت الخدمة توفر fetchTransactions مع الفلاتر استخدمها، وإلا ننفذ استعلامًا بسيطًا هنا
      try {
        final list = await _service.fetchTransactions(agencyId, limit: limit, from: from, to: to);
        _setTransactions(list);
        return;
      } catch (_) {
        // fallback إلى استعلام Firestore محلي
      }

      Query<Map<String, dynamic>> q = _firestore
          .collection('agency_transactions')
          .where('agencyId', isEqualTo: agencyId)
          .orderBy('createdAt', descending: true);

      if (from != null) {
        q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
      }
      if (to != null) {
        q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to));
      }

      q = q.limit(limit);

      final snap = await q.get();
      final list = snap.docs.map((d) => AgencyTransaction.fromDoc(d)).toList();
      _setTransactions(list);
    } catch (e, st) {
      debugPrint('AgenciesProvider.loadTransactions error: $e\n$st');
      _setError('فشل جلب سجل المعاملات: ${e.toString()}');
    }
  }

  // =============================================================
  // 4. الاستماع اللحظي (Real-time)
  // =============================================================
  void listenToAgency(String id) {
    _currentAgencySub?.cancel();
    try {
      _currentAgencySub = _service.getAgencyStream(id).listen((agency) {
        _currentAgency = agency;
        notifyListeners();
      }, onError: (e, st) {
        debugPrint('AgenciesProvider.listenToAgency error: $e\n$st');
        _setError('خطأ في الاستماع لمكتب: ${e.toString()}');
      });
    } catch (e, st) {
      debugPrint('AgenciesProvider.listenToAgency exception: $e\n$st');
      _setError('فشل بدء الاستماع للمكتب: ${e.toString()}');
    }
  }

  void startRealtimeListener() {
    _realtimeSub?.cancel();
    try {
      _realtimeSub = _firestore
          .collection('agencies')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snap) {
        final list = snap.docs.map((d) => Agency.fromDoc(d)).toList();
        _setAgencies(list);
      }, onError: (e, st) {
        debugPrint('AgenciesProvider.startRealtimeListener error: $e\n$st');
        _setError('خطأ في الاستماع للتحديثات: ${e.toString()}');
      });
    } catch (e, st) {
      debugPrint('AgenciesProvider.startRealtimeListener exception: $e\n$st');
      _setError('فشل بدء الاستماع في الوقت الحقيقي: ${e.toString()}');
    }
  }

  void stopRealtimeListener() {
    _realtimeSub?.cancel();
    _realtimeSub = null;
    _currentAgencySub?.cancel();
    _currentAgencySub = null;
  }

  // =============================================================
  // تنظيف عند التخلص من المزود
  // =============================================================
  @override
  void dispose() {
    stopRealtimeListener();
    super.dispose();
  }
}
