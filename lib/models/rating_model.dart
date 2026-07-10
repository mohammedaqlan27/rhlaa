// lib/models/rating_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String id;
  final String tripId;
  final String bookingId;
  final String fromUserId;
  final String toUserId;

  /// rating: descriptive label (e.g., "excellent", "good", "poor")
  final String rating;
  /// score: numeric score (e.g., 4.5)
  final double score;

  /// نص ملاحظات قصيرة أو وصفية
  final String? note;
  /// تعليق أطول إن وُجد
  final String? comment;

  final Timestamp? createdAt;

  Rating({
    required this.id,
    required this.tripId,
    required this.bookingId,
    required this.fromUserId,
    required this.toUserId,
    this.rating = '',
    this.score = 0.0,
    this.note,
    this.comment,
    this.createdAt,
  });

  /// تحويل الكائن إلى خريطة جاهزة للحفظ في Firestore
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'bookingId': bookingId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'rating': rating,
      'score': score,
      'note': note,
      'comment': comment,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
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
      }
      return null;
    }

    return Rating(
      id: doc.id,
      tripId: s(['tripId', 'trip_id']),
      bookingId: s(['bookingId', 'booking_id']),
      fromUserId: s(['fromUserId', 'from_user_id', 'fromId']),
      toUserId: s(['toUserId', 'to_user_id', 'toId']),
      rating: s(['rating', 'ratingLabel', 'rate']),
      score: d(['score', 'ratingScore', 'rate_value']),
      note: s(['note', 'notes']),
      comment: s(['comment', 'comments']),
      createdAt: ts(['createdAt', 'created_at', 'timestamp']),
    );
  }

  Rating copyWith({
    String? id,
    String? tripId,
    String? bookingId,
    String? fromUserId,
    String? toUserId,
    String? rating,
    double? score,
    String? note,
    String? comment,
    Timestamp? createdAt,
  }) {
    return Rating(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      bookingId: bookingId ?? this.bookingId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      rating: rating ?? this.rating,
      score: score ?? this.score,
      note: note ?? this.note,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Rating(id: $id, tripId: $tripId, bookingId: $bookingId, from: $fromUserId, to: $toUserId, rating: $rating, score: $score)';
  }
}
