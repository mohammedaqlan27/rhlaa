// lib/providers/agency_provider.dart
//
// مزود لإدارة حالة المكاتب (Agencies) في الواجهة.
// - يعتمد على AgenciesService و نماذج Agency و AgencyTransaction.
// - يدعم: جلب القوائم، جلب مكتب واحد، إنشاء/تحديث/حذف، تفعيل/تعطيل، شحن/خصم المحفظة، جلب سجل المعاملات.
// - يوفر أيضاً دعم الاستماع في الوقت الحقيقي (realtime) عبر StreamSubscription.
// - يُرجع أخطاء قابلة للعرض في الواجهة ويحدّث حالة التحميل عبر notifyListeners().

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/agencies_service.dart';
import '../models/agency.dart';
import '../models/agency_transaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgencyProvider with ChangeNotifier {
  final AgenciesService _service;

  AgencyProvider({AgenciesService? service}) : _service = service ?? AgenciesService();

  // --- الحالة الداخلية (State) ---
  bool _isLoading = false;
  String? _error;
  List<Agency> _agencies = [];
  Agency? _currentAgency;
  List<AgencyTransaction> _transactions = [];
  double _totalBalance = 0.0; // ميزة جديدة: إجمالي السيولة في كل المكاتب

  // الاشتراكات (Subscriptions)
  StreamSubscription? _realtimeSub;
  StreamSubscription? _currentAgencySub; // ميزة جديدة: الاستماع لمكتب واحد

  // --- Getters ---
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Agency> get agencies => List.unmodifiable(_agencies);
  Agency? get currentAgency => _currentAgency;
  List<AgencyTransaction> get transactions => List.unmodifiable(_transactions);
  double get totalBalance => _totalBalance; // الوصول لإجمالي السيولة

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

  // ============================
  // عمليات CRUD أساسية والبحث
  // ============================

  /// تحميل كل المكاتب وتحديث إجمالي السيولة
  Future<void> loadAgencies({bool onlyActive = false}) async {
    _setLoading(true);
    _setError(null);
    try {
      final list = await _service.fetchAllAgencies(onlyActive: onlyActive);
      _setAgencies(list);
      await loadTotalBalance(); // تحديث إجمالي السيولة تلقائياً
    } catch (e) {
      debugPrint('AgencyProvider.loadAgencies error: $e');
      _setError('فشل جلب المكاتب: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// البحث في السيرفر (باستخدام ميزة البحث الاحترافية في الخدمة)
  Future<void> searchAgencies(String query) async {
    if (query.isEmpty) {
      await loadAgencies();
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final results = await _service.searchAgencies(query);
      _setAgencies(results);
    } catch (e) {
      debugPrint('AgencyProvider.searchAgencies error: $e');
      _setError('خطأ في البحث: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// جلب مكتب واحد وتعيينه كحالي مع الاستماع لتحديثاته اللحظية
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
        listenToAgency(id); // بدء الاستماع اللحظي لهذا المكتب
        await loadTransactions(id);
      }
    } catch (e) {
      debugPrint('AgencyProvider.loadAgencyById error: $e');
      _setError('فشل جلب بيانات المكتب: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// إنشاء مكتب جديد
  Future<bool> createAgency({
    required String agencyName,
    required String managerName,
    dynamic location,
    required String mobileNumber,
    double initialBalance = 0.0,
    bool isActive = true,
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
        isActive: isActive,
      );
      await loadAgencies();
      await loadAgencyById(id);
      return true;
    } catch (e) {
      debugPrint('AgencyProvider.createAgency error: $e');
      _setError(e.toString().replaceAll('Exception:', ''));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث بيانات المكتب
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
      debugPrint('AgencyProvider.updateAgency error: $e');
      _setError('فشل تحديث المكتب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// حذف مكتب
  Future<bool> deleteAgency(String id) async {
    _setLoading(true);
    _setError(null);
    try {
      await _service.deleteAgency(id);
      _agencies.removeWhere((a) => a.id == id);
      if (_currentAgency != null && _currentAgency!.id == id) _setCurrentAgency(null);
      await loadTotalBalance();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AgencyProvider.deleteAgency error: $e');
      _setError('فشل حذف المكتب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// تفعيل/تعطيل المكتب
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
      debugPrint('AgencyProvider.setAgencyActive error: $e');
      _setError('فشل تغيير حالة المكتب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================
  // عمليات المحفظة والسيولة
  // ============================

  /// شحن رصيد المكتب
  Future<bool> creditAgencyWallet(String id, double amount, {String? reason, String? performedBy}) async {
    _setLoading(true);
    _setError(null);
    try {
      await _service.creditWallet(id, amount, reason: reason, performedBy: performedBy);
      await loadTotalBalance();
      return true;
    } catch (e) {
      debugPrint('AgencyProvider.creditAgencyWallet error: $e');
      _setError('فشل شحن رصيد المكتب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// خصم من رصيد المكتب
  Future<bool> debitAgencyWallet(String id, double amount, {String? reason, String? performedBy}) async {
    _setLoading(true);
    _setError(null);
    try {
      await _service.debitWallet(id, amount, reason: reason, performedBy: performedBy);
      await loadTotalBalance();
      return true;
    } catch (e) {
      debugPrint('AgencyProvider.debitAgencyWallet error: $e');
      _setError(e.toString().replaceAll('Exception:', ''));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// جلب إجمالي السيولة في كل المكاتب
  Future<void> loadTotalBalance() async {
    try {
      _totalBalance = await _service.getTotalAgenciesBalance();
      notifyListeners();
    } catch (e) {
      debugPrint('AgencyProvider.loadTotalBalance error: $e');
    }
  }

  // ============================
  // سجل المعاملات
  // ============================

  /// جلب سجل المعاملات لمكتب معين
  Future<void> loadTransactions(String agencyId, {int limit = 200}) async {
    try {
      final list = await _service.fetchTransactions(agencyId, limit: limit);
      _setTransactions(list);
    } catch (e) {
      debugPrint('AgencyProvider.loadTransactions error: $e');
      _setError('فشل جلب سجل المعاملات: $e');
    }
  }

  // ============================
  // وظائف إضافية مفيدة للواجهة
  // ============================

  /// فلترة محلية سريعة للمكاتب المحملة مسبقاً
  void filterAgencies({String? query, bool? onlyActive}) {
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
    _setAgencies(filtered);
  }

  /// إعادة تحميل القوائم المحلية من السيرفر
  Future<void> resetAndReload({bool onlyActive = false}) async {
    await loadAgencies(onlyActive: onlyActive);
  }

  // ============================
  // دعم الاستماع في الوقت الحقيقي (Realtime)
  // ============================

  /// الاستماع لمكتب واحد فقط (لتحديث الرصيد فوراً في شاشة التفاصيل)
  void listenToAgency(String id) {
    _currentAgencySub?.cancel();
    _currentAgencySub = _service.getAgencyStream(id).listen((agency) {
      _currentAgency = agency;
      notifyListeners();
    }, onError: (e) => debugPrint('AgencyProvider.listenToAgency error: $e'));
  }

  /// ابدأ الاستماع للتغييرات في كل المكاتب
  void startRealtimeListener({void Function(List<Agency>)? onData}) {
    stopRealtimeListener();
    try {
      _realtimeSub = FirebaseFirestore.instance
          .collection('agencies')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
            (snap) {
          final list = snap.docs.map((d) => Agency.fromDoc(d)).toList();
          _agencies = list;
          notifyListeners();
          if (onData != null) onData(list);
        },
        onError: (e) {
          debugPrint('AgencyProvider.realtime error: $e');
          _setError('خطأ في الاستماع للتحديثات: $e');
        },
      );
    } catch (e) {
      debugPrint('AgencyProvider.startRealtimeListener error: $e');
      _setError('فشل بدء الاستماع في الوقت الحقيقي: $e');
    }
  }

  /// إيقاف الاستماع في الوقت الحقيقي
  void stopRealtimeListener() {
    _realtimeSub?.cancel();
    _realtimeSub = null;
    _currentAgencySub?.cancel();
    _currentAgencySub = null;
  }

  // ============================
  // تنظيف عند التخلص من المزود
  // ============================
  @override
  void dispose() {
    stopRealtimeListener();
    super.dispose();
  }
}