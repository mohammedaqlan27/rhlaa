// lib/services/govfees_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/trip.dart';

/// تمثيل شريحة مسافة لرسوم الحكومة
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
    double toDouble(dynamic v, [double fallback = 0.0]) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }
    return DistanceTier(
      minKm: toDouble(m['minKm'] ?? m['min_km']),
      maxKm: toDouble(m['maxKm'] ?? m['max_km'], double.infinity),
      amount: toDouble(m['amount'] ?? m['fee']),
    );
  }

  Map<String, dynamic> toMap() => {
    'minKm': minKm,
    'maxKm': maxKm,
    'amount': amount,
  };
}

/// نموذج قاعدة رسوم حكومية (GovFeeRule)
class GovFeeRule {
  final String id;
  final String origin;
  final String destination;
  final bool exact; // إذا كان true يتطلب تطابقاً حرفياً، وإذا كان false يسمح بالتطابق الجزئي
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

    List<DistanceTier> parseTiers(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => DistanceTier.fromMap(Map<String, dynamic>.from(e))).toList();
      }
      return [];
    }

    return GovFeeRule(
      id: doc.id,
      origin: (data['origin'] ?? '*').toString(),
      destination: (data['destination'] ?? '*').toString(),
      exact: (data['exact'] ?? false) as bool,
      distanceBased: (data['distanceBased'] ?? false) as bool,
      fixedAmount: (data['fixedAmount'] ?? 0.0).toDouble(),
      distanceTiers: parseTiers(data['distanceTiers']),
      priority: (data['priority'] ?? 0) as int,
      isActive: (data['isActive'] ?? true) as bool,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  /// تحويل الكائن إلى Map للحفظ في Firestore
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
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    }..removeWhere((k, v) => v == null);
  }

  /// منطق المطابقة الذكي: يدعم الوايلدكارد، المطابقة الحرفية، والمطابقة الجزئية
  bool matches(String tripOrigin, String tripDest) {
    if (!isActive) return false;

    bool checkMatch(String pattern, String value) {
      final p = pattern.trim().toLowerCase();
      final v = value.trim().toLowerCase();

      if (p == '*' || p.isEmpty) return true; // الوايلدكارد يطابق أي شيء
      if (exact) return v == p;               // مطابقة حرفية تامة
      return v.contains(p);                  // مطابقة جزئية
    }

    return checkMatch(origin, tripOrigin) && checkMatch(destination, tripDest);
  }

  /// حساب القيمة بناءً على المسافة أو المبلغ الثابت
  double calculate(double? distanceKm) {
    if (!distanceBased) return fixedAmount;

    final d = distanceKm ?? 0.0;
    for (final tier in distanceTiers) {
      if (d >= tier.minKm && d <= tier.maxKm) {
        return tier.amount;
      }
    }
    return fixedAmount;
  }
}

class GovFeesService {
  final FirebaseFirestore _firestore;
  final String _collection = 'gov_fees';
  final String _tripsCollection = 'trips';

  GovFeesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// جلب القواعد النشطة مرتبة حسب الأولوية
  Future<List<GovFeeRule>> _getActiveRules() async {
    try {
      final snap = await _firestore.collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true)
          .get();
      return snap.docs.map((d) => GovFeeRule.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('GovFeesService._getActiveRules error: $e');
      return [];
    }
  }

  /// حساب الرسوم لرحلة معينة بناءً على أفضل قاعدة مطابقة
  Future<double> calculateGovFee({
    required String origin,
    required String destination,
    double? distanceKm,
  }) async {
    final rules = await _getActiveRules();
    for (final rule in rules) {
      if (rule.matches(origin, destination)) {
        return rule.calculate(distanceKm);
      }
    }
    return 0.0;
  }

  /// تحديث رسوم الرحلة داخل Transaction آمن
  Future<bool> computeAndSetGovFeeForTrip(String tripId) async {
    final tripRef = _firestore.collection(_tripsCollection).doc(tripId);

    try {
      final rules = await _getActiveRules();

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(tripRef);
        if (!snap.exists) return;

        final trip = Trip.fromDocument(snap);
        double fee = 0.0;

        for (final rule in rules) {
          if (rule.matches(trip.origin, trip.destination)) {
            fee = rule.calculate(trip.distanceKm);
            break;
          }
        }

        tx.update(tripRef, {
          'govFeeAmount': fee,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return true;
    } catch (e) {
      debugPrint('GovFeesService.computeAndSetGovFeeForTrip error: $e');
      return false;
    }
  }

  // --- دوال الإدارة (CRUD) ---

  Future<String> createRule(GovFeeRule rule) async {
    final doc = await _firestore.collection(_collection).add(rule.toMap());
    return doc.id;
  }

  Future<void> updateRule(String id, Map<String, dynamic> data) async {
    await _firestore.collection(_collection).doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRule(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// إعادة حساب الرسوم لجميع الرحلات النشطة
  Future<int> recomputeGovFeesForAllActiveTrips({int limit = 100}) async {
    int updatedCount = 0;
    try {
      final rules = await _getActiveRules();
      final tripsSnap = await _firestore.collection(_tripsCollection)
          .where('status', isEqualTo: 'active')
          .limit(limit)
          .get();

      for (var doc in tripsSnap.docs) {
        final trip = Trip.fromDocument(doc);
        double fee = 0.0;
        for (final rule in rules) {
          if (rule.matches(trip.origin, trip.destination)) {
            fee = rule.calculate(trip.distanceKm);
            break;
          }
        }

        if (trip.govFeeAmount != fee) {
          await doc.reference.update({'govFeeAmount': fee});
          updatedCount++;
        }
      }
    } catch (e) {
      debugPrint('GovFeesService.recomputeGovFees error: $e');
    }
    return updatedCount;
  }
}