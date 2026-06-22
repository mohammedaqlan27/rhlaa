import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String id;
  final String? tripId;
  final String? bookingId;
  final String fromUserId;
  final String toUserId;
  final double rating;
  final int? score;
  final String? note;
  final String? comment;
  final Timestamp? createdAt;

  Rating({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.rating,
    this.tripId,
    this.bookingId,
    this.score,
    this.note,
    this.comment,
    this.createdAt,
  });

  /// تحويل النموذج إلى خريطة للكتابة إلى Firestore
  /// تم تنظيف التكرار المزدوج لـ snake_case والاعتماد على camelCase
  Map<String, dynamic> toMap() {
    return {
      if (tripId != null) 'tripId': tripId,
      if (bookingId != null) 'bookingId': bookingId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'rating': rating,
      if (score != null) 'score': score,
      if (note != null) 'note': note,
      if (comment != null) 'comment': comment,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  /// إنشاء نموذج من مستند Firestore يدعم قراءة كافة البدائل الممكنة
  factory Rating.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String _getString(List<String> keys, [String fallback = '']) {
      for (final k in keys) {
        final v = data[k];
        if (v != null) return v.toString();
      }
      return fallback;
    }

    double _getDouble(List<String> keys, [double fallback = 0.0]) {
      for (final k in keys) {
        final v = data[k];
        if (v is double) return v;
        if (v is num) return (v as num).toDouble();
        if (v is String) {
          final parsed = double.tryParse(v.replaceAll(',', ''));
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    int? _getIntNullable(List<String> keys) {
      for (final k in keys) {
        final v = data[k];
        if (v is int) return v;
        if (v is num) return (v as num).toInt();
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    Timestamp? _getTimestampNullable(List<String> keys) {
      for (final k in keys) {
        final v = data[k];
        if (v is Timestamp) return v;
        if (v is DateTime) return Timestamp.fromDate(v);
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return Timestamp.fromDate(parsed);
        }
      }
      return null;
    }

    final tripId = _getString(['tripId', 'trip_id'], '');
    final bookingId = _getString(['bookingId', 'booking_id'], '');
    final fromUserId = _getString(['fromUserId', 'from_user_id'], '');
    final toUserId = _getString(['toUserId', 'to_user_id'], '');
    final ratingValue = _getDouble(['rating', 'rating_value'], 0.0);
    final scoreValue = _getIntNullable(['score']);
    final note = data['note']?.toString();
    final comment = data['comment']?.toString();
    final createdAt = _getTimestampNullable(['createdAt', 'created_at']);

    return Rating(
      id: doc.id,
      tripId: tripId.isEmpty ? null : tripId,
      bookingId: bookingId.isEmpty ? null : bookingId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      rating: ratingValue,
      score: scoreValue,
      note: note,
      comment: comment,
      createdAt: createdAt,
    );
  }

  Rating copyWith({
    String? id,
    String? tripId,
    String? bookingId,
    String? fromUserId,
    String? toUserId,
    double? rating,
    int? score,
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
    return 'Rating(id: $id, from: $fromUserId, to: $toUserId, rating: $rating)';
  }
}