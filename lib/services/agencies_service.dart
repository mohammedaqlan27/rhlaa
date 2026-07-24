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

  double _toDoubleSafe(dynamic v) => (v is num) ? v.toDouble() : (double.tryParse(v?.toString() ?? '0.0') ?? 0.0);

  // =============================================================
  // 1. إدارة المكاتب (CRUD) مع التحقق
  // =============================================================

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
      // التحقق من وجود رقم الهاتف مسبقاً
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
        'searchKey': agencyName.toLowerCase(), // للبحث السهل
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating agency: $e');
      rethrow;
    }
  }

  /// جلب بيانات مكتب واحد (Stream) للتحديث اللحظي في الواجهة
  Stream<Agency?> getAgencyStream(String id) {
    return _col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Agency.fromDoc(doc);
    });
  }

  /// البحث عن المكاتب بالاسم أو الهاتف
  Future<List<Agency>> searchAgencies(String query) async {
    final snap = await _col
        .where('mobileNumber', isEqualTo: query) // بحث برقم الهاتف أولاً
        .get();

    if (snap.docs.isNotEmpty) {
      return snap.docs.map((d) => Agency.fromDoc(d)).toList();
    }

    // إذا لم يجد بالهاتف، يبحث بالاسم (بداية الاسم)
    final nameSnap = await _col
        .where('searchKey', isGreaterThanOrEqualTo: query.toLowerCase())
        .where('searchKey', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
        .limit(10)
        .get();

    return nameSnap.docs.map((d) => Agency.fromDoc(d)).toList();
  }

  // =============================================================
  // 2. النظام المالي (Wallet & Transactions)
  // =============================================================

  /// عملية مالية موحدة (شحن أو خصم) لضمان تقليل تكرار الكود
  Future<void> _updateWalletTransaction({
    required String agencyId,
    required double amount,
    required String type, // 'credit' or 'debit'
    required String reason,
    String? performedBy,
  }) async {
    if (amount <= 0) throw Exception('المبلغ يجب أن يكون أكبر من صفر');

    final docRef = _col.doc(agencyId);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (!snapshot.exists) throw Exception('المكتب غير موجود');

      final currentBalance = _toDoubleSafe(snapshot.data()?['walletBalance']);
      double newBalance;

      if (type == 'credit') {
        newBalance = currentBalance + amount;
      } else {
        if (currentBalance < amount) throw Exception('رصيد المكتب غير كافٍ');
        newBalance = currentBalance - amount;
      }

      // 1. تحديث رصيد المكتب
      tx.update(docRef, {
        'walletBalance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. تسجيل العملية المالية
      final txDoc = _transactionsCol.doc();
      tx.set(txDoc, {
        'id': txDoc.id,
        'agencyId': agencyId,
        'amount': amount,
        'type': type,
        'reason': reason,
        'performedBy': performedBy ?? 'system',
        'createdAt': FieldValue.serverTimestamp(),
        'oldBalance': currentBalance,
        'newBalance': newBalance,
      });
    });
  }

  Future<void> creditWallet(String agencyId, double amount, {String? reason, String? performedBy}) {
    return _updateWalletTransaction(
      agencyId: agencyId,
      amount: amount,
      type: 'credit',
      reason: reason ?? 'شحن رصيد يدوي',
      performedBy: performedBy,
    );
  }

  Future<void> debitWallet(String agencyId, double amount, {String? reason, String? performedBy}) {
    return _updateWalletTransaction(
      agencyId: agencyId,
      amount: amount,
      type: 'debit',
      reason: reason ?? 'خصم رصيد يدوي',
      performedBy: performedBy,
    );
  }

  // =============================================================
  // 3. التقارير والإحصائيات
  // =============================================================

  /// جلب إجمالي أرصدة المكاتب (للمدير العام)
  Future<double> getTotalAgenciesBalance() async {
    final snap = await _col.get();
    double total = 0;
    for (var doc in snap.docs) {
      total += _toDoubleSafe(doc.data()?['walletBalance']);
    }
    return total;
  }

  /// جلب سجل العمليات مع دعم الترتيب الزمني
  Future<List<AgencyTransaction>> fetchTransactions(String agencyId, {int limit = 50}) async {
    try {
      final snap = await _transactionsCol
          .where('agencyId', isEqualTo: agencyId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => AgencyTransaction.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      return [];
    }
  }
}

extension on Object? {
  operator [](String other) {}
}