import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String id; // معرف المستند
  final String? tripId;
  final String? bookingId;
  final String fromUserId; // المعرف العام للراسل
  final String toUserId;   // المعرف العام للمستقبل
  final String? passengerId; // معرف الراكب (حسب Firestore)
  final String? driverId;    // معرف السائق (حسب Firestore)
  final double rating;
  final int score;
  final String? note;
  final String? comment;
  final Timestamp? createdAt;

  Rating({
    required this.id,
    this.tripId,
    this.bookingId,
    required this.fromUserId,
    required this.toUserId,
    this.passengerId,
    this.driverId,
    required this.rating,
    required this.score,
    this.note,
    this.comment,
    this.createdAt,
  });

  /// تحويل النموذج إلى Map للكتابة إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'bookingId': bookingId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'passengerId': passengerId ?? fromUserId, // افتراضياً هو الراسل إذا كان راكباً
      'driverId': driverId ?? toUserId,         // افتراضياً هو المستقبل إذا كان سائقاً
      'rating': rating,
      'score': score,
      'note': note,
      'comment': comment,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  /// إنشاء نموذج من مستند Firestore مع معالجة ذكية للبيانات
  factory Rating.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // --- دوال مساعدة ذكية لمنع الـ Crash ---

    // جلب النصوص مع فحص مفاتيح متعددة
    String _s(List<String> keys, [String fallback = '']) {
      for (final k in keys) {
        if (data[k] != null && data[k].toString().trim().isNotEmpty) {
          return data[k].toString().trim();
        }
      }
      return fallback;
    }

    // جلب الأرقام العشرية (double) بأمان
    double _d(List<String> keys, [double fallback = 0.0]) {
      for (final k in keys) {
        final v = data[k];
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    // جلب الأرقام الصحيحة (int) بأمان
    int _i(List<String> keys, [int fallback = 0]) {
      for (final k in keys) {
        final v = data[k];
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    // جلب التاريخ (Timestamp) بأمان
    Timestamp? _t(List<String> keys) {
      for (final k in keys) {
        final v = data[k];
        if (v is Timestamp) return v;
        if (v is DateTime) return Timestamp.fromDate(v);
        if (v is String) {
          final p = DateTime.tryParse(v);
          if (p != null) return Timestamp.fromDate(p);
        }
      }
      return null;
    }

    return Rating(
      id: doc.id,
      tripId: _s(['tripId', 'trip_id']),
      bookingId: _s(['bookingId', 'booking_id']),
      fromUserId: _s(['fromUserId', 'from_user_id', 'passengerId']),
      toUserId: _s(['toUserId', 'to_user_id', 'driverId']),
      passengerId: _s(['passengerId', 'fromUserId']),
      driverId: _s(['driverId', 'toUserId']),
      rating: _d(['rating', 'rating_value']),
      score: _i(['score', 'stars']),
      note: _s(['note']),
      comment: _s(['comment']),
      createdAt: _t(['createdAt', 'created_at']),
    );
  }

  Rating copyWith({
    String? id,
    String? tripId,
    String? bookingId,
    String? fromUserId,
    String? toUserId,
    String? passengerId,
    String? driverId,
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
      passengerId: passengerId ?? this.passengerId,
      driverId: driverId ?? this.driverId,
      rating: rating ?? this.rating,
      score: score ?? this.score,
      note: note ?? this.note,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Rating(ID: $id, Score: $score, From: $fromUserId, To: $toUserId)';
}