// lib/services/rating_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/rating_model.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();
  final String _collection = 'ratings';

  /// إضافة تقييم جديد أو تحديث الموجود
  Future<bool> addOrUpdateRating({
    required String tripId,
    required String bookingId,
    required String passengerId,
    required String driverId,
    required int score,
    String? comment,
  }) async {
    try {
      // 1) حاول العثور على تقييم موجود بصيغ متعددة للحقل
      QuerySnapshot existing = await _firestore
          .collection(_collection)
          .where('tripId', isEqualTo: tripId)
          .where('bookingId', isEqualTo: bookingId)
          .where('fromUserId', isEqualTo: passengerId)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        // محاولة بديلة بصيغة snake_case
        existing = await _firestore
            .collection(_collection)
            .where('trip_id', isEqualTo: tripId)
            .where('booking_id', isEqualTo: bookingId)
            .where('from_user_id', isEqualTo: passengerId)
            .limit(1)
            .get();
      }

      if (existing.docs.isNotEmpty) {
        // تحديث التقييم الحالي (ندعم كتابة الحقول بصيغتيْن)
        final docRef = existing.docs.first.reference;
        final now = FieldValue.serverTimestamp();
        await docRef.update({
          'score': score,
          'comment': comment,
          'rating': score.toDouble(),
          'updatedAt': now,
          'updated_at': now,
        });
        return true;
      }

      // إنشاء تقييم جديد متوافق مع نموذج Rating
      final ratingId = _uuid.v4();
      final rating = Rating(
        id: ratingId,
        fromUserId: passengerId,
        toUserId: driverId,
        rating: score.toDouble(),
        tripId: tripId,
        bookingId: bookingId,
        score: score,
        comment: comment,
        createdAt: null, // سنستخدم serverTimestamp عند الكتابة
      );

      // اكتب الحقول بصيغ متعددة لزيادة التوافق مع قواعد البيانات القديمة
      final now = FieldValue.serverTimestamp();
      final payload = rating.toMap();
      payload.addAll({
        'createdAt': now,
        'created_at': now,
        // تكرار بعض الحقول بصيغ بديلة
        'trip_id': tripId,
        'booking_id': bookingId,
        'from_user_id': passengerId,
        'to_user_id': driverId,
        'score': score,
        'rating': score.toDouble(),
      });

      await _firestore.collection(_collection).doc(ratingId).set(payload);
      return true;
    } catch (e, st) {
      debugPrint('RatingService.addOrUpdateRating error: $e\n$st');
      return false;
    }
  }

  /// جلب تقييمات مستخدم معين (تيار موحّد يدعم camelCase و snake_case)
  Stream<List<Rating>> getRatingsForUser(String userId) {
    // نستمع لكامل المجموعة ثم نفلتر محليًا حسب الحقول الممكنة
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final List<Rating> list = [];
      for (final doc in snapshot.docs) {
        try {
          final rating = Rating.fromDocument(doc);
          final data = doc.data() as Map<String, dynamic>;
          final toUser = rating.toUserId ??
              (data['toUserId'] ?? data['to_user_id'] ?? data['driverId'] ?? data['driver_id'])?.toString();
          if (toUser != null && toUser == userId) {
            list.add(rating);
          }
        } catch (err, st) {
          debugPrint('RatingService.parse doc error: $err\n$st');
        }
      }
      // فرز حسب createdAt الأحدث أولاً (دعم null)
      list.sort((a, b) {
        final ta = a.createdAt;
        final tb = b.createdAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  /// حساب متوسط التقييم لمستخدم (يدعم حقول rating و score)
  Future<double> getAverageRating(String userId) async {
    try {
      final snapshot = await _firestore.collection(_collection).get();

      final List<double> values = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final toUser = (data['toUserId'] ?? data['to_user_id'] ?? data['driverId'] ?? data['driver_id'])?.toString();
        if (toUser == userId) {
          double? val;
          if (data['rating'] != null) {
            final r = data['rating'];
            if (r is num) val = (r as num).toDouble();
            else if (r is String) val = double.tryParse(r);
          } else if (data['score'] != null) {
            final s = data['score'];
            if (s is num) val = (s as num).toDouble();
            else if (s is String) val = double.tryParse(s);
          }
          if (val != null) values.add(val);
        }
      }

      if (values.isEmpty) return 0.0;
      final total = values.reduce((a, b) => a + b);
      return total / values.length;
    } catch (e, st) {
      debugPrint('RatingService.getAverageRating error: $e\n$st');
      return 0.0;
    }
  }
}
