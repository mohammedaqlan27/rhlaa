// lib/models/gov_fee_rule.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    double _toDouble(dynamic v, [double fallback = 0.0]) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    return DistanceTier(
      minKm: _toDouble(m['minKm'] ?? m['min_km'] ?? m['min'] ?? 0.0),
      maxKm: _toDouble(m['maxKm'] ?? m['max_km'] ?? m['max'] ?? double.infinity),
      amount: _toDouble(m['amount'] ?? m['fee'] ?? 0.0),
    );
  }

  Map<String, dynamic> toMap() => {
    'minKm': minKm,
    'maxKm': maxKm,
    'amount': amount,
  };
}

/// نموذج قاعدة رسوم حكومية (gov fee rule)
class GovFeeRule {
  final String id;
  final String origin; // اسم نقطة الانطلاق أو '*'
  final String destination; // اسم الوجهة أو '*'
  final bool exact; // تطابق دقيق origin/destination
  final bool distanceBased; // هل تعتمد الرسوم على المسافة
  final double fixedAmount; // مبلغ ثابت إن وُجد
  final List<DistanceTier> distanceTiers; // شرائح المسافة
  final int priority; // أولوية القاعدة
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

  /// مساعدة لتحويل قيمة إلى double بأمان
  static double _toDoubleSafe(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  /// مساعدة لتحويل قيمة إلى int بأمان
  static int _toIntSafe(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  /// قراءة Timestamp بأمان من أنواع متعددة
  static Timestamp _parseTimestamp(dynamic v) {
    if (v is Timestamp) return v;
    if (v is DateTime) return Timestamp.fromDate(v);
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    if (v is int) {
      try {
        return Timestamp.fromMillisecondsSinceEpoch(v);
      } catch (_) {}
    }
    return Timestamp.now();
  }

  /// إنشاء من مستند Firestore
  factory GovFeeRule.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // distanceTiers قد تكون Map أو List أو JSON string

    List<DistanceTier> parseTiers(dynamic raw) {
      if (raw == null) return [];

      // إذا كانت خريطة (map) من كائنات
      if (raw is Map) {
        try {
          return raw.values.map((e) {
            final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
            return DistanceTier.fromMap(m);
          }).toList();
        } catch (_) {
          return [];
        }
      }

      // إذا كانت قائمة
      if (raw is List) {
        return raw.map((e) {
          if (e is Map<String, dynamic>) return DistanceTier.fromMap(e);
          if (e is Map) return DistanceTier.fromMap(Map<String, dynamic>.from(e));
          return DistanceTier(minKm: 0.0, maxKm: double.infinity, amount: 0.0);
        }).toList();
      }

      // إذا كانت نص JSON
      if (raw is String) {
        final parsed = raw.trim();
        if (parsed.isEmpty) return [];
        try {
          final decoded = jsonDecode(parsed);
          if (decoded is List) {
            return decoded.map((e) => DistanceTier.fromMap(Map<String, dynamic>.from(e))).toList();
          }
          if (decoded is Map) {
            return decoded.values.map((e) => DistanceTier.fromMap(Map<String, dynamic>.from(e))).toList();
          }
        } catch (_) {
          // JSON غير صالح — نرجع قائمة فارغة بدل رمي استثناء
          return [];
        }
      }

      // أي نوع آخر
      return [];
    }
    final tiers = parseTiers(data['distanceTiers'] ?? data['distance_tiers'] ?? data['tiers']);

    return GovFeeRule(
      id: doc.id,
      origin: (data['origin'] ?? '*').toString(),
      destination: (data['destination'] ?? '*').toString(),
      exact: (data['exact'] ?? false) as bool,
      distanceBased: (data['distanceBased'] ?? data['distance_based'] ?? false) as bool,
      fixedAmount: _toDoubleSafe(data['fixedAmount'] ?? data['fixed_amount'] ?? 0.0),
      distanceTiers: tiers,
      priority: _toIntSafe(data['priority'] ?? 0),
      isActive: data['isActive'] is bool ? data['isActive'] as bool : (data['isActive']?.toString().toLowerCase() == 'true'),
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : _parseTimestamp(data['createdAt']),
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] as Timestamp : (data['updatedAt'] != null ? _parseTimestamp(data['updatedAt']) : null),
    );
  }

  /// تحويل إلى Map للحفظ في Firestore
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

  /// احسب الرسوم الحكومية لرحلة بناءً على المسافة والقاعدة
  /// ترجع null إذا لم تنطبق القاعدة (مثلاً origin/destination لا تطابق)
  double? calculateFee({required double distanceKm, required String origin, required String destination}) {
    // تحقق من التطابق مع origin/destination
    if (exact) {
      if (this.origin != '*' && this.origin != origin) return null;
      if (this.destination != '*' && this.destination != destination) return null;
    } else {
      if (this.origin != '*' && this.origin != origin) return null;
      if (this.destination != '*' && this.destination != destination) return null;
    }

    if (!isActive) return null;

    if (!distanceBased) {
      return fixedAmount;
    }

    // البحث في الشرائح
    for (final tier in distanceTiers) {
      final minOk = distanceKm >= tier.minKm;
      final maxOk = tier.maxKm.isFinite ? distanceKm <= tier.maxKm : true;
      if (minOk && maxOk) return tier.amount;
    }

    // إذا لم يطابق أي شريحة، استخدم fixedAmount إن وُجد
    return fixedAmount;
  }
}
