// lib/services/agencies_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/agency.dart';
import '../models/agency_transaction.dart';

class AgenciesService {
  final FirebaseFirestore _firestore;

  AgenciesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _col => _firestore.collection('agencies');
  CollectionReference get _transactionsCol => _firestore.collection('agency_transactions');

  /// تحويل القيم إلى double بأمان لتجنب أخطاء النوع
  double _toDoubleSafe(dynamic v) => (v is num) ? v.toDouble() : (double.tryParse(v?.toString() ?? '0.0') ?? 0.0);

  // =============================================================
  // 1. إدارة المكاتب (CRUD)
  // =============================================================

  /// جلب كل المكاتب مع إمكانية الفلترة للمكاتب النشطة فقط
  Future<List<Agency>> fetchAllAgencies({bool onlyActive = false}) async {
    try {
      Query q = _col.orderBy('createdAt', descending: true);
      if (onlyActive) q = q.where('isActive', isEqualTo: true);
      final snap = await q.get();
      return snap.docs.map((d) => Agency.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('Error fetchAllAgencies: $e');
      return [];
    }
  }

  /// جلب بيانات مكتب واحد حسب المعرف (ID)
  Future<Agency?> getAgencyById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) return null;
      return Agency.fromDoc(doc);
    } catch (e) {
      debugPrint('Error getAgencyById: $e');
      return null;
    }
  }

  /// تحديث بيانات المكتب (مثل الاسم، الموقع، إلخ)
  Future<void> updateAgency(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _col.doc(id).update(updates);
    } catch (e) {
      debugPrint('Error updateAgency: $e');
      rethrow;
    }
  }

  /// حذف المكتب نهائياً من قاعدة البيانات
  Future<void> deleteAgency(String id) async {
    try {
      await _col.doc(id).delete();
    } catch (e) {
      debugPrint('Error deleteAgency: $e');
      rethrow;
    }
  }

  /// تفعيل أو تعطيل حساب المكتب
  Future<void> setAgencyActive(String id, bool isActive) async {
    try {
      await _col.doc(id).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setAgencyActive: $e');
      rethrow;
    }
  }

  /// إنشاء مكتب جديد مع التحقق من عدم تكرار رقم الهاتف
  Future<String> createAgency({
    required String agencyName,
    required String managerName,
    required dynamic location,
    required String mobileNumber,
    double initialBalance = 0.0,
    bool isActive = true,
  }) async {
    try {
      final existing = await _col.where('mobileNumber', isEqualTo: mobileNumber).get();
      if (existing.docs.isNotEmpty) {
        throw Exception('رقم الهاتف مسجل لمكتب آخر بالفعل');
      }

      final now = Timestamp.now();
      final docRef = await _col.add({
        'agencyName': agencyName,
        'managerName': managerName,
        'location': location,
        'mobileNumber': mobileNumber,
        'walletBalance': initialBalance,
        'isActive': isActive,
        'createdAt': now,
        'updatedAt': now,
        'searchKey': agencyName.toLowerCase(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating agency: $e');
      rethrow;
    }
  }

  // =============================================================
  // 2. النظام المالي والاستماع اللحظي
  // =============================================================

  /// الاستماع لتحديثات مكتب معين في الوقت الحقيقي
  Stream<Agency?> getAgencyStream(String id) {
    return _col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Agency.fromDoc(doc);
    });
  }

  /// البحث عن المكاتب برقم الهاتف أو الاسم
  Future<List<Agency>> searchAgencies(String query) async {
    try {
      final snap = await _col.where('mobileNumber', isEqualTo: query).get();
      if (snap.docs.isNotEmpty) return snap.docs.map((d) => Agency.fromDoc(d)).toList();

      final nameSnap = await _col
          .where('searchKey', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('searchKey', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
          .limit(10)
          .get();
      return nameSnap.docs.map((d) => Agency.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('Error searchAgencies: $e');
      return [];
    }
  }

  /// دالة داخلية لإدارة عمليات المحفظة (شحن/خصم) بشكل آمن (Transaction)
  Future<void> _updateWalletTransaction({
    required String agencyId,
    required double amount,
    required String type,
    required String? reason,
    String? performedBy,
  }) async {
    if (amount <= 0) throw Exception('المبلغ يجب أن يكون أكبر من صفر');
    final docRef = _col.doc(agencyId);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (!snapshot.exists) throw Exception('المكتب غير موجود');

      // تصحيح: الوصول للبيانات كـ Map لضمان التوافق
      final data = snapshot.data() as Map<String, dynamic>;
      final currentBalance = _toDoubleSafe(data['walletBalance']);

      double newBalance = type == 'credit' ? currentBalance + amount : currentBalance - amount;

      if (type == 'debit' && currentBalance < amount) {
        throw Exception('رصيد المكتب غير كافٍ لإتمام العملية');
      }

      tx.update(docRef, {
        'walletBalance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final txDoc = _transactionsCol.doc();
      tx.set(txDoc, {
        'id': txDoc.id,
        'agencyId': agencyId,
        'amount': amount,
        'type': type,
        'reason': reason ?? (type == 'credit' ? 'شحن رصيد' : 'خصم رصيد'),
        'performedBy': performedBy ?? 'system',
        'createdAt': FieldValue.serverTimestamp(),
        'oldBalance': currentBalance,
        'newBalance': newBalance,
      });
    });
  }

  Future<void> creditWallet(String agencyId, double amount, {String? reason, String? performedBy}) {
    return _updateWalletTransaction(agencyId: agencyId, amount: amount, type: 'credit', reason: reason, performedBy: performedBy);
  }

  Future<void> debitWallet(String agencyId, double amount, {String? reason, String? performedBy}) {
    return _updateWalletTransaction(agencyId: agencyId, amount: amount, type: 'debit', reason: reason, performedBy: performedBy);
  }

  /// حساب إجمالي أرصدة جميع المكاتب (للتقارير الإدارية)
  Future<double> getTotalAgenciesBalance() async {
    try {
      final snap = await _col.get();
      double total = 0;
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += _toDoubleSafe(data['walletBalance']);
      }
      return total;
    } catch (e) {
      debugPrint('Error getTotalAgenciesBalance: $e');
      return 0.0;
    }
  }

  /// جلب سجل المعاملات المالية لمكتب معين
  Future<List<AgencyTransaction>> fetchTransactions(String agencyId, {int limit = 50}) async {
    try {
      final snap = await _transactionsCol
          .where('agencyId', isEqualTo: agencyId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => AgencyTransaction.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('Error fetchTransactions: $e');
      return [];
    }
  }
}