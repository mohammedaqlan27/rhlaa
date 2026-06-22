import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/rating_model.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();
  final String _collection = 'ratings';

  Future<bool> addOrUpdateRating({
    required String tripId,
    required String bookingId,
    required String passengerId,
    required String driverId,
    required int score,
    String? comment,
  }) async {
    try {
      // البحث بفلترة دقيقة وسريعة لمنع استهلاك الموارد
      QuerySnapshot existing = await _firestore
          .collection(_collection)
          .where('tripId', isEqualTo: tripId)
          .where('bookingId', isEqualTo: bookingId)
          .where('fromUserId', isEqualTo: passengerId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final docRef = existing.docs.first.reference;
        await docRef.update({
          'score': score,
          'comment': comment,
          'rating': score.toDouble(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

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
        createdAt: Timestamp.now(), // تخزين كـ Timestamp مباشرة
      );

      await _firestore.collection(_collection).doc(ratingId).set(rating.toMap());
      return true;
    } catch (e, st) {
      debugPrint('RatingService.addOrUpdateRating error: $e\n$st');
      return false;
    }
  }

  /// جلب التقييمات الموجهة للمستخدم مع فلترة مباشرة من السيرفر (Server-side Filter)
  Stream<List<Rating>> getRatingsForUser(String userId) {
    return _firestore
        .collection(_collection)
        .where('toUserId', isEqualTo: userId) // تحسين ضخم لمنع جلب بيانات التطبيق بالكامل
        .snapshots()
        .map((snapshot) {
      final List<Rating> list = [];
      for (final doc in snapshot.docs) {
        try {
          list.add(Rating.fromDocument(doc));
        } catch (e) {
          debugPrint('Error parsing rating doc: $e');
        }
      }

      // الترتيب بحسب التاريخ الأحدث باستخدام Timestamp
      list.sort((a, b) {
        final Timestamp? ta = a.createdAt is Timestamp ? a.createdAt as Timestamp : null;
        final Timestamp? tb = b.createdAt is Timestamp ? b.createdAt as Timestamp : null;

        final DateTime? taDate = ta?.toDate();
        final DateTime? tbDate = tb?.toDate();

        if (taDate == null && tbDate == null) return 0;
        if (taDate == null) return 1;
        if (tbDate == null) return -1;
        return tbDate.compareTo(taDate);
      });

      return list;
    });
  }

  /// حساب المتوسط الحسابي بكفاءة عالية ومباشرة عبر السيرفر لتخفيف التكلفة والاكتفاء بقراءات محددة
  Future<double> getAverageRating(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('toUserId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      final List<double> values = [];
      for (final doc in snapshot.docs) {
        try {
          final rating = Rating.fromDocument(doc);
          values.add(rating.rating);
        } catch (_) {}
      }

      if (values.isEmpty) return 0.0;
      final total = values.reduce((a, b) => a + b);
      return total / values.length;
    } catch (e) {
      debugPrint('RatingService.getAverageRating error: $e');
      return 0.0;
    }
  }
}
