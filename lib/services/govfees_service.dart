// lib/services/govfees_service.dart
//
// خدمة لإدارة "رسوم الفرزة الحكومية" (govFeeAmount) حسب خط السير.
// - تخزن قواعد الرسوم في مجموعة Firestore اسمها "gov_fees".
// - تدعم قواعد ثابتة حسب مسار محدد (origin -> destination)، قواعد نمطية (wildcard)،
//   وقواعد تعتمد على المسافة (distance tiers).
// - توفر دوال لإنشاء/تحديث/حذف/جلب القواعد، وحساب قيمة govFee لرحلة معينة
//   وتحديث حقل govFeeAmount في وثيقة الرحلة داخل معاملة آمنة.
//
// نموذج مستند gov_fees (مثال):
// {
//   "id": "docId",
//   "origin": "صنعاء",                // أو "*" للمطابقة العامة
//   "destination": "تعز",            // أو "*" للمطابقة العامة
//   "exact": true,                   // إذا true تطابق حرفي origin/destination
//   "distanceBased": false,          // إذا true تستخدم distanceTiers
//   "fixedAmount": 500.0,            // مبلغ ثابت (يُستخدم إذا distanceBased=false)
//   "distanceTiers": [               // يُستخدم إذا distanceBased=true
//       {"minKm":0, "maxKm":50, "amount":200.0},
//       {"minKm":51, "maxKm":200, "amount":500.0}
//   ],
//   "priority": 10,                  // أولوية القاعدة عند وجود تطابقات متعددة (أعلى أفضل)
//   "isActive": true,
//   "createdAt": Timestamp,
//   "updatedAt": Timestamp
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/trip.dart';

class DistanceTier {
  final double minKm;
  final double maxKm;
  final double amount;

  DistanceTier({
    required this.minKm,
    required this.maxKm,
    required this.amount,
  });

  factory DistanceTier.fromMap(Map<String, dynamic> m) {
    return DistanceTier(
      minKm: (m['minKm'] ?? 0).toDouble(),
      maxKm: (m['maxKm'] ?? double.infinity).toDouble(),
      amount: (m['amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'minKm': minKm,
    'maxKm': maxKm,
    'amount': amount,
  };
}

class GovFeeRule {
  final String id;
  final String origin; // can be '*' or exact name
  final String destination; // can be '*' or exact name
  final bool exact; // if true require exact match, else allow case-insensitive contains
  final bool distanceBased;
  final double fixedAmount;
  final List<DistanceTier> distanceTiers;
  final int priority;
  final bool isActive;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  GovFeeRule({
    required this.id,
    required this.origin,
    required this.destination,
    required this.exact,
    required this.distanceBased,
    required this.fixedAmount,
    required this.distanceTiers,
    required this.priority,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory GovFeeRule.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final tiersRaw = data['distanceTiers'] as List<dynamic>? ?? [];
    final tiers = tiersRaw.map((e) {
      if (e is Map<String, dynamic>) return DistanceTier.fromMap(e);
      return DistanceTier.fromMap(Map<String, dynamic>.from(e as Map));
    }).toList();
    return GovFeeRule(
      id: doc.id,
      origin: (data['origin'] ?? '*') as String,
      destination: (data['destination'] ?? '*') as String,
      exact: (data['exact'] ?? false) as bool,
      distanceBased: (data['distanceBased'] ?? false) as bool,
      fixedAmount: (data['fixedAmount'] ?? 0.0).toDouble(),
      distanceTiers: tiers,
      priority: (data['priority'] ?? 0) as int,
      isActive: (data['isActive'] ?? true) as bool,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'origin': origin,
      'destination': destination,
      'exact': exact,
      'distanceBased': distanceBased,
      'fixedAmount': fixedAmount,
      'distanceTiers': distanceTiers.map((t) => t.toMap()).toList(),
      'priority': priority,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class GovFeesService {
  final FirebaseFirestore _firestore;
  final String _collection = 'gov_fees';
  final String _tripsCollection = 'trips';

  GovFeesService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _col => _firestore.collection(_collection);

  /// إنشاء قاعدة جديدة لرسوم الفرزة
  Future<String> createRule({
    required String origin,
    required String destination,
    bool exact = false,
    bool distanceBased = false,
    double fixedAmount = 0.0,
    List<DistanceTier>? distanceTiers,
    int priority = 0,
    bool isActive = true,
  }) async {
    final now = Timestamp.now();
    final docRef = await _col.add({
      'origin': origin,
      'destination': destination,
      'exact': exact,
      'distanceBased': distanceBased,
      'fixedAmount': fixedAmount,
      'distanceTiers': (distanceTiers ?? []).map((t) => t.toMap()).toList(),
      'priority': priority,
      'isActive': isActive,
      'createdAt': now,
      'updatedAt': now,
    });
    return docRef.id;
  }

  /// تحديث قاعدة موجودة (جزئي)
  Future<void> updateRule(String id, Map<String, dynamic> updates) async {
    updates.removeWhere((k, v) => v == null);
    updates['updatedAt'] = Timestamp.now();
    await _col.doc(id).update(updates);
  }

  /// حذف قاعدة
  Future<void> deleteRule(String id) async {
    await _col.doc(id).delete();
  }

  /// جلب كل القواعد (قابلة للفلترة)
  Future<List<GovFeeRule>> fetchRules({bool onlyActive = true}) async {
    try {
      Query q = _col.orderBy('priority', descending: true);
      if (onlyActive) q = q.where('isActive', isEqualTo: true);
      final snap = await q.get();
      return snap.docs.map((d) => GovFeeRule.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('GovFeesService.fetchRules error: $e');
      return [];
    }
  }

  /// جلب قاعدة حسب المعرف
  Future<GovFeeRule?> getRuleById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return GovFeeRule.fromDoc(doc);
  }

  // ============================
  // منطق الحساب
  // ============================

  /// يطابق origin/destination مع قاعدة معينة.
  /// يدعم '*' كوايلدكارد، و exact=true للمطابقة الحرفية، وإلا يستخدم contains (case-insensitive).
  bool _matchRoute(String ruleOrigin, String ruleDest, bool exact, String origin, String destination) {
    final oRule = ruleOrigin.trim();
    final dRule = ruleDest.trim();
    final o = origin.trim();
    final d = destination.trim();

    bool matchPart(String pattern, String value) {
      if (pattern == '*' || pattern.isEmpty) return true;
      if (exact) return pattern.toLowerCase() == value.toLowerCase();
      return value.toLowerCase().contains(pattern.toLowerCase());
    }

    return matchPart(oRule, o) && matchPart(dRule, d);
  }

  /// اختيار أفضل قاعدة مطابقة لمسار معين (origin,destination,distanceKm)
  /// تعطي الأولوية لقاعدة ذات أولوية أعلى، ثم القاعدة الأكثر تحديداً (exact).
  Future<GovFeeRule?> _findBestRule(String origin, String destination, {double? distanceKm}) async {
    final rules = await fetchRules(onlyActive: true);
    GovFeeRule? best;
    for (final r in rules) {
      try {
        if (_matchRoute(r.origin, r.destination, r.exact, origin, destination)) {
          if (best == null) {
            best = r;
            continue;
          }
          // مقارنة الأولوية
          if (r.priority > best.priority) {
            best = r;
            continue;
          }
          // إذا نفس الأولوية، اختر الأكثر تحديداً (exact true)
          if (r.priority == best.priority) {
            if (r.exact && !best.exact) {
              best = r;
              continue;
            }
            // إذا نفس الدقة والأولوية، اختر القاعدة ذات fixedAmount أو أقرب tier إن كانت distanceBased
            // لا تغيير افتراضي
          }
        }
      } catch (e) {
        debugPrint('GovFeesService._findBestRule match error: $e');
      }
    }
    return best;
  }

  /// حساب قيمة govFee بناءً على القاعدة (إن وُجدت) وإرجاع القيمة (double).
  /// إذا لم توجد قاعدة، يعيد 0.0.
  double _computeFeeFromRule(GovFeeRule rule, {double? distanceKm}) {
    if (!rule.isActive) return 0.0;
    if (rule.distanceBased) {
      final d = distanceKm ?? 0.0;
      for (final tier in rule.distanceTiers) {
        if (d >= tier.minKm && d <= tier.maxKm) {
          return tier.amount;
        }
      }
      // إذا لم يطابق أي نطاق، نستخدم fixedAmount كقيمة افتراضية إن وُجدت
      if (rule.fixedAmount > 0) return rule.fixedAmount;
      return 0.0;
    } else {
      return rule.fixedAmount;
    }
  }

  /// واجهة عامة: احسب قيمة govFee لرحلة (باستخدام origin,destination,distanceKm)
  /// - يبحث عن أفضل قاعدة ويطبقها.
  /// - يعيد قيمة مزدوجة (0.0 إذا لا توجد قاعدة).
  Future<double> calculateGovFee({
    required String origin,
    required String destination,
    double? distanceKm,
  }) async {
    try {
      final rule = await _findBestRule(origin, destination, distanceKm: distanceKm);
      if (rule == null) return 0.0;
      final fee = _computeFeeFromRule(rule, distanceKm: distanceKm);
      return fee;
    } catch (e) {
      debugPrint('GovFeesService.calculateGovFee error: $e');
      return 0.0;
    }
  }

  /// احسب وقم بتحديث حقل govFeeAmount في وثيقة الرحلة (داخل معاملة آمنة).
  /// يعيد true عند النجاح.
  Future<bool> computeAndSetGovFeeForTrip(String tripId) async {
    final tripRef = _firestore.collection(_tripsCollection).doc(tripId);
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(tripRef);
        if (!snap.exists) throw Exception('Trip not found');
        final trip = Trip.fromDocument(snap);

        final origin = trip.origin ?? '';
        final destination = trip.destination ?? '';
        final distanceKm = trip.distanceKm;

        final fee = await calculateGovFee(origin: origin, destination: destination, distanceKm: distanceKm);

        tx.update(tripRef, {
          'govFeeAmount': fee,
          'manifestStatus': FieldValue.serverTimestamp() == null ? 'pending' : 'pending', // لا تغيير فعلي، مجرد مثال
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return true;
    } catch (e, st) {
      debugPrint('GovFeesService.computeAndSetGovFeeForTrip error: $e\n$st');
      return false;
    }
  }

  /// احسب وقم بتحديث govFeeAmount لعدة رحلات دفعة واحدة (مثلاً عند تغيير قواعد الفرزة)
  Future<int> recomputeGovFeesForAllTrips({int limit = 500}) async {
    int updated = 0;
    try {
      final snap = await _firestore.collection(_tripsCollection).where('status', isEqualTo: 'active').limit(limit).get();
      for (final doc in snap.docs) {
        final trip = Trip.fromDocument(doc);
        final fee = await calculateGovFee(origin: trip.origin ?? '', destination: trip.destination ?? '', distanceKm: trip.distanceKm);
        if ((trip.govFeeAmount ?? 0.0) != fee) {
          await _firestore.collection(_tripsCollection).doc(trip.id).update({
            'govFeeAmount': fee,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          updated++;
        }
      }
    } catch (e) {
      debugPrint('GovFeesService.recomputeGovFeesForAllTrips error: $e');
    }
    return updated;
  }
}
