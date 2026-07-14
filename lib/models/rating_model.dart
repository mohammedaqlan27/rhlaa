// lib/models/rating_model.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج Rating موحّد وآمن للقراءة والكتابة إلى Firestore.
/// يدعم أسماء الحقول البديلة (camelCase / snake_case) ويتعامل مع أنواع متعددة بأمان.
class Rating {
  final String id;
  final String tripId;
  final String bookingId;
  final String fromUserId;
  final String toUserId;
  final String? driverId;
  final String? passengerId;

  /// rating: descriptive label (e.g., "excellent", "good", "poor")
  final String rating;

  /// score: numeric score (e.g., 4.5)
  final double score;

  /// category: نوع التقييم (رحلة، سائق، مركبة)
  final String category;

  /// نص ملاحظات قصيرة أو وصفية
  final String? note;

  /// تعليق أطول إن وُجد
  final String? comment;

  /// كلمات مفتاحية أو وسوم
  final List<String> tags;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  Rating({
    required this.id,
    required this.tripId,
    required this.bookingId,
    required this.fromUserId,
    required this.toUserId,
    this.driverId,
    this.passengerId,
    this.rating = '',
    this.score = 0.0,
    this.category = '',
    this.note,
    this.comment,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// تحويل الكائن إلى خريطة جاهزة للحفظ في Firestore
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'bookingId': bookingId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'driverId': driverId,
      'passengerId': passengerId,
      'rating': rating,
      'score': score,
      'category': category,
      'note': note,
      'comment': comment,
      'tags': tags,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    }..removeWhere((key, value) => value == null);
  }

  /// إنشاء نموذج من مستند Firestore مع دعم أسماء حقول متعددة (camelCase / snake_case)
  factory Rating.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String s(List<String> keys, [String fallback = '']) {
      for (var k in keys) {
        final v = data[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    double d(List<String> keys, [double fallback = 0.0]) {
      for (var k in keys) {
        final v = data[k];
        if (v is num) return v.toDouble();
        if (v is String) {
          final parsed = double.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    Timestamp? ts(List<String> keys) {
      for (var k in keys) {
        final v = data[k];
        if (v is Timestamp) return v;
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return Timestamp.fromDate(parsed);
        }
        if (v is int) {
          try {
            return Timestamp.fromMillisecondsSinceEpoch(v);
          } catch (_) {}
        }
      }
      return null;
    }

    List<String> list(List<String> keys) {
      for (var k in keys) {
        final v = data[k];
        if (v is List) {
          return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
        }
      }
      return [];
    }

    return Rating(
      id: doc.id,
      tripId: s(['tripId', 'trip_id']),
      bookingId: s(['bookingId', 'booking_id']),
      fromUserId: s(['fromUserId', 'from_user_id', 'fromId']),
      toUserId: s(['toUserId', 'to_user_id', 'toId']),
      driverId: s(['driverId', 'driver_id']),
      passengerId: s(['passengerId', 'passenger_id']),
      rating: s(['rating', 'ratingLabel', 'rate']),
      score: d(['score', 'ratingScore', 'rate_value']),
      category: s(['category', 'ratingCategory']),
      note: s(['note', 'notes']),
      comment: s(['comment', 'comments']),
      tags: list(['tags']),
      createdAt: ts(['createdAt', 'created_at', 'timestamp']),
      updatedAt: ts(['updatedAt', 'updated_at']),
    );
  }

  Rating copyWith({
    String? id,
    String? tripId,
    String? bookingId,
    String? fromUserId,
    String? toUserId,
    String? driverId,
    String? passengerId,
    String? rating,
    double? score,
    String? category,
    String? note,
    String? comment,
    List<String>? tags,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return Rating(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      bookingId: bookingId ?? this.bookingId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      driverId: driverId ?? this.driverId,
      passengerId: passengerId ?? this.passengerId,
      rating: rating ?? this.rating,
      score: score ?? this.score,
      category: category ?? this.category,
      note: note ?? this.note,
      comment: comment ?? this.comment,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Rating(id: $id, tripId: $tripId, bookingId: $bookingId, from: $fromUserId, to: $toUserId, rating: $rating, score: $score, category: $category)';
  }
}
