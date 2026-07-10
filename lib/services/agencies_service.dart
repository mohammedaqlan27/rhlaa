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

  // Helper محلي لتحويل القيم إلى double بأمان (يحل محل استدعاءات Agency.toDoubleSafe إن لم تكن متاحة)
  double _toDoubleSafe(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /// إنشاء مكتب جديد
  Future<String> createAgency({
    required String agencyName,
    required String managerName,
    required dynamic location,
    required String mobileNumber,
    double initialBalance = 0.0,
    bool isActive = true,
  }) async {
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
    });
    return docRef.id;
  }

  /// جلب مكتب حسب المعرف
  Future<Agency?> getAgencyById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) return null;
      return Agency.fromDoc(doc);
    } catch (e) {
      debugPrint('AgenciesService.getAgencyById error: $e');
      rethrow;
    }
  }

  /// جلب كل المكاتب
  Future<List<Agency>> fetchAllAgencies({bool onlyActive = false}) async {
    try {
      Query q = _col.orderBy('createdAt', descending: true);
      if (onlyActive) q = q.where('isActive', isEqualTo: true);
      final snap = await q.get();
      return snap.docs.map((d) => Agency.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('AgenciesService.fetchAllAgencies error: $e');
      return <Agency>[];
    }
  }

  /// تحديث بيانات المكتب (جزئي)
  Future<void> updateAgency(String id, Map<String, dynamic> updates) async {
    try {
      updates.removeWhere((key, value) => value == null);
      updates['updatedAt'] = Timestamp.now();
      await _col.doc(id).update(updates);
    } catch (e) {
      debugPrint('AgenciesService.updateAgency error: $e');
      rethrow;
    }
  }

  /// حذف المكتب
  Future<void> deleteAgency(String id) async {
    try {
      await _col.doc(id).delete();
    } catch (e) {
      debugPrint('AgenciesService.deleteAgency error: $e');
      rethrow;
    }
  }

  /// تفعيل/تعطيل المكتب
  Future<void> setAgencyActive(String id, bool isActive) async {
    try {
      await _col.doc(id).update({'isActive': isActive, 'updatedAt': Timestamp.now()});
    } catch (e) {
      debugPrint('AgenciesService.setAgencyActive error: $e');
      rethrow;
    }
  }

  /// شحن رصيد المحفظة للمكتب (transaction آمن) مع تسجيل المعاملة
  Future<void> creditWallet(String agencyId, double amount, {String? reason, String? performedBy}) async {
    if (amount <= 0) return;
    final docRef = _col.doc(agencyId);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (!snapshot.exists) throw Exception('Agency not found');
      final current = (snapshot.data() as Map<String, dynamic>?)?['walletBalance'];
      final currentBalance = _toDoubleSafe(current);
      final newBalance = currentBalance + amount;
      tx.update(docRef, {
        'walletBalance': newBalance,
        'updatedAt': Timestamp.now(),
      });

      // سجل المعاملة
      final txDoc = _transactionsCol.doc();
      final now = Timestamp.now();
      tx.set(
        txDoc,
        AgencyTransaction(
          id: txDoc.id,
          agencyId: agencyId,
          amount: amount,
          type: 'credit',
          reason: reason ?? 'manual_credit',
          performedBy: performedBy,
          createdAt: now,
        ).toMap(),
      );
    });
  }

  /// خصم من رصيد المحفظة للمكتب (transaction آمن) مع تسجيل المعاملة
  Future<void> debitWallet(String agencyId, double amount, {String? reason, String? performedBy}) async {
    if (amount <= 0) return;
    final docRef = _col.doc(agencyId);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (!snapshot.exists) throw Exception('Agency not found');
      final current = (snapshot.data() as Map<String, dynamic>?)?['walletBalance'];
      final currentBalance = _toDoubleSafe(current);
      if (currentBalance < amount) throw Exception('Insufficient agency wallet balance');
      final newBalance = currentBalance - amount;
      tx.update(docRef, {
        'walletBalance': newBalance,
        'updatedAt': Timestamp.now(),
      });

      // سجل المعاملة
      final txDoc = _transactionsCol.doc();
      final now = Timestamp.now();
      tx.set(
        txDoc,
        AgencyTransaction(
          id: txDoc.id,
          agencyId: agencyId,
          amount: amount,
          type: 'debit',
          reason: reason ?? 'manual_debit',
          performedBy: performedBy,
          createdAt: now,
        ).toMap(),
      );
    });
  }

  /// جلب سجل المعاملات لمكتب معين (مرتّب تنازلياً)
  Future<List<AgencyTransaction>> fetchTransactions(String agencyId, {int limit = 100}) async {
    try {
      final snap = await _transactionsCol
          .where('agencyId', isEqualTo: agencyId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => AgencyTransaction.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('AgenciesService.fetchTransactions error: $e');
      return <AgencyTransaction>[];
    }
  }
}
