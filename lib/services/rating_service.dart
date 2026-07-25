// lib/services/rating_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/rating_model.dart';

class RatingService {
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();
  final String _collection = 'ratings';

  // التعديل هنا: المشيد الآن يدعم حقن الاعتمادات (Dependency Injection)
  // إذا لم يتم تمرير firestore، سيستخدم النسخة الحقيقية تلقائياً
  RatingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// إضافة أو تحديث تقييم مع تحديث إحصائيات المستخدم (المُقيَّم) تلقائياً
  /// score يجب أن يكون قيمة رقمية (مثلاً 4.5)
  /// ratingLabel يمكن أن يكون نصًا وصفيًا مثل "excellent" أو "جيد"
  Future<bool> addOrUpdateRating({
    required String tripId,
    required String bookingId,
    required String fromUserId,
    required String toUserId,
    required double score,
    String? ratingLabel,
    String? comment,
    String? note,
  }) async {
    try {
      // 1. التحقق من وجود تقييم سابق من هذا المقيّم لنفس الرحلة/الحجز
      final existing = await _firestore
          .collection(_collection)
          .where('tripId', isEqualTo: tripId)
          .where('bookingId', isEqualTo: bookingId)
          .where('fromUserId', isEqualTo: fromUserId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // تحديث التقييم الموجود
        final docRef = existing.docs.first.reference;
        final updateData = <String, dynamic>{
          'score': score,
          'rating': ratingLabel ?? (score.toString()),
          'comment': comment,
          'note': note,
          'updatedAt': FieldValue.serverTimestamp(),
        }..removeWhere((k, v) => v == null);

        await docRef.update(updateData);
      } else {
        // إضافة تقييم جديد باستخدام الموديل المحدث
        final ratingId = _uuid.v4();
        final rating = Rating(
          id: ratingId,
          tripId: tripId,
          bookingId: bookingId,
          fromUserId: fromUserId,
          toUserId: toUserId,
          rating: ratingLabel ?? '',
          score: score,
          note: note,
          comment: comment,
          createdAt: Timestamp.now(),
        );

        await _firestore.collection(_collection).doc(ratingId).set(rating.toMap());
      }

      // 2. تحديث إحصائيات المستخدم (المُقيَّم) في مجموعة users
      await _updateUserRatingStats(toUserId);

      return true;
    } catch (e, st) {
      debugPrint('RatingService.addOrUpdateRating error: $e\n$st');
      return false;
    }
  }

  /// دالة داخلية لحساب وتحديث متوسط التقييم وعدد التقييمات في مستند المستخدم
  Future<void> _updateUserRatingStats(String userId) async {
    if (userId.isEmpty) return;
    try {
      // جلب جميع تقييمات هذا المستخدم (التي وجهت إليه)
      final snapshot = await _firestore
          .collection(_collection)
          .where('toUserId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) {
        // إذا لم توجد تقييمات، نصفر الإحصائيات
        await _firestore.collection('users').doc(userId).update({
          'averageRating': 0.0,
          'ratingCount': 0,
        });
        return;
      }

      int count = snapshot.docs.length;
      double totalScore = 0.0;

      for (var doc in snapshot.docs) {
        try {
          final ratingObj = Rating.fromDocument(doc);
          totalScore += ratingObj.score;
        } catch (e) {
          debugPrint('RatingService._updateUserRatingStats parse error: $e');
        }
      }

      final double average = count > 0 ? totalScore / count : 0.0;

      // تحديث مستند المستخدم بالحقول الموحدة
      await _firestore.collection('users').doc(userId).update({
        'averageRating': double.parse(average.toStringAsFixed(1)), // تقريب لمنزلة واحدة
        'ratingCount': count,
      });

      debugPrint('Stats updated for $userId: Avg ${average.toStringAsFixed(2)}, Count $count');
    } catch (e, st) {
      debugPrint('RatingService._updateUserRatingStats error: $e\n$st');
    }
  }

  /// جلب التقييمات الموجهة للمستخدم (Stream) لعرضها في الملف الشخصي
  Stream<List<Rating>> getRatingsForUser(String userId) {
    return _firestore
        .collection(_collection)
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final List<Rating> list = [];
      for (final doc in snapshot.docs) {
        try {
          list.add(Rating.fromDocument(doc));
        } catch (e) {
          debugPrint('RatingService.getRatingsForUser parse error: $e');
        }
      }

      // الترتيب حسب التاريخ الأحدث (من الأحدث إلى الأقدم)
      list.sort((a, b) {
        final DateTime? dateA = a.createdAt?.toDate();
        final DateTime? dateB = b.createdAt?.toDate();
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      return list;
    });
  }

  /// جلب متوسط التقييم الحالي من مستند المستخدم مباشرة (للسرعة)
  Future<double> getAverageRatingFromUserDoc(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        final val = data?['averageRating'] ?? 0.0;
        if (val is num) return val.toDouble();
        if (val is String) return double.tryParse(val) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      debugPrint('RatingService.getAverageRatingFromUserDoc error: $e');
      return 0.0;
    }
  }
}