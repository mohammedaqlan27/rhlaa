// lib/services/agencies_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/agency.dart';
import '../models/agency_transaction.dart';

class AgenciesService {
  final FirebaseFirestore _firestore;

  AgenciesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // حددنا النوع العام Map<String, dynamic> لتجنب مشاكل النوع
  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('agencies');
  CollectionReference<Map<String, dynamic>> get _transactionsCol => _firestore.collection('agency_transactions');

  /// تحويل القيم إلى double بأمان لتجنب أخطاء النوع
  double _toDoubleSafe(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  // =============================================================
  // 1. إدارة المكاتب (CRUD)
  // =============================================================

  /// جلب كل المكاتب مع إمكانية الفلترة للمكاتب النشطة فقط
  Future<List<Agency>> fetchAllAgencies({bool onlyActive = false}) async {
    try {
      Query<Map<String, dynamic>> q = _col.orderBy('createdAt', descending: true);
      if (onlyActive) q = q.where('isActive', isEqualTo: true);
      final snap = await q.get();
      return snap.docs.map((d) => Agency.fromDoc(d)).toList();
    } catch (e, st) {
      debugPrint('AgenciesService.fetchAllAgencies error: $e\n$st');
      return [];
    }
  }

  /// جلب بيانات مكتب واحد حسب المعرف (ID)
  Future<Agency?> getAgencyById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) return null;
      return Agency.fromDoc(doc);
    } catch (e, st) {
      debugPrint('AgenciesService.getAgencyById error: $e\n$st');
      return null;
    }
  }

  /// جلب مكتب بواسطة حقل authUid (مفيد لربط حساب Firebase Auth بالمكتب)
  Future<Agency?> getAgencyByAuthUid(String authUid) async {
    try {
      final snap = await _col.where('authUid', isEqualTo: authUid).limit(1).get();
      if (snap.docs.isEmpty) return null;
      return Agency.fromDoc(snap.docs.first);
    } catch (e, st) {
      debugPrint('AgenciesService.getAgencyByAuthUid error: $e\n$st');
      return null;
    }
  }

  /// تحديث بيانات المكتب (مثل الاسم، الموقع، إلخ)
  Future<void> updateAgency(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _col.doc(id).update(updates);
    } catch (e, st) {
      debugPrint('AgenciesService.updateAgency error: $e\n$st');
      rethrow;
    }
  }

  /// حذف المكتب نهائياً من قاعدة البيانات
  Future<void> deleteAgency(String id) async {
    try {
      await _col.doc(id).delete();
    } catch (e, st) {
      debugPrint('AgenciesService.deleteAgency error: $e\n$st');
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
    } catch (e, st) {
      debugPrint('AgenciesService.setAgencyActive error: $e\n$st');
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
    String? authUid,
    String? email,
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
        'email': email ?? '',
        'authUid': authUid ?? '',
        'walletBalance': initialBalance,
        'isActive': isActive,
        'createdAt': now,
        'updatedAt': now,
        'searchKey': agencyName.toLowerCase(),
      });
      return docRef.id;
    } catch (e, st) {
      debugPrint('AgenciesService.createAgency error: $e\n$st');
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

  /// البحث عن المكاتب برقم الهاتف أو الاسم (بحث بسيط)
  Future<List<Agency>> searchAgencies(String query) async {
    try {
      // بحث برقم الهاتف أولاً
      final snapPhone = await _col.where('mobileNumber', isEqualTo: query).get();
      if (snapPhone.docs.isNotEmpty) return snapPhone.docs.map((d) => Agency.fromDoc(d)).toList();

      // بحث نصي مبسط باستخدام searchKey (يجب أن يكون مخزناً بصيغة lowercase)
      final q = query.toLowerCase();
      final nameSnap = await _col
          .where('searchKey', isGreaterThanOrEqualTo: q)
          .where('searchKey', isLessThanOrEqualTo: '$q\uf8ff')
          .limit(10)
          .get();
      return nameSnap.docs.map((d) => Agency.fromDoc(d)).toList();
    } catch (e, st) {
      debugPrint('AgenciesService.searchAgencies error: $e\n$st');
      return [];
    }
  }

  /// دالة داخلية لإدارة عمليات المحفظة (شحن/خصم) بشكل آمن (Transaction)
  Future<void> _updateWalletTransaction({
    required String agencyId,
    required double amount,
    required String type, // 'credit' أو 'debit'
    required String? reason,
    String? performedBy,
  }) async {
    if (amount <= 0) throw Exception('المبلغ يجب أن يكون أكبر من صفر');
    final docRef = _col.doc(agencyId);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (!snapshot.exists) throw Exception('المكتب غير موجود');

      final data = snapshot.data() as Map<String, dynamic>? ?? <String, dynamic>{};
      final currentBalance = _toDoubleSafe(data['walletBalance']);

      final double newBalance = type == 'credit' ? currentBalance + amount : currentBalance - amount;

      if (type == 'debit' && currentBalance < amount) {
        throw Exception('رصيد المكتب غير كافٍ لإتمام العملية');
      }

      tx.update(docRef, {
        'walletBalance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final txDocRef = _transactionsCol.doc();
      tx.set(txDocRef, {
        'id': txDocRef.id,
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
        final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
        total += _toDoubleSafe(data['walletBalance']);
      }
      return total;
    } catch (e, st) {
      debugPrint('AgenciesService.getTotalAgenciesBalance error: $e\n$st');
      return 0.0;
    }
  }

  /// جلب سجل المعاملات المالية لمكتب معين
  /// يدعم: limit, from, to, startAfterId (للباجينايشن)
  Future<List<AgencyTransaction>> fetchTransactions(
      String agencyId, {
        int limit = 50,
        DateTime? from,
        DateTime? to,
        String? startAfterId,
      }) async {
    try {
      Query<Map<String, dynamic>> q = _transactionsCol
          .where('agencyId', isEqualTo: agencyId)
          .orderBy('createdAt', descending: true);

      if (from != null) {
        q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
      }
      if (to != null) {
        q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to));
      }

      if (startAfterId != null && startAfterId.isNotEmpty) {
        // نحاول الحصول على المستند الذي يمثل نقطة البداية
        try {
          final docSnap = await _transactionsCol.doc(startAfterId).get();
          if (docSnap.exists) {
            q = q.startAfterDocument(docSnap);
          } else {
            // إذا لم يوجد المستند، نتجاهل startAfterId بهدوء
            debugPrint('AgenciesService.fetchTransactions: startAfterId not found: $startAfterId');
          }
        } catch (e) {
          debugPrint('AgenciesService.fetchTransactions: failed to resolve startAfterId: $e');
        }
      }

      q = q.limit(limit);

      final snap = await q.get();
      return snap.docs.map((d) => AgencyTransaction.fromDoc(d)).toList();
    } catch (e, st) {
      debugPrint('AgenciesService.fetchTransactions error: $e\n$st');
      return [];
    }
  }
}
