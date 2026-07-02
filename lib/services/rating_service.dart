import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/rating_model.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();
  final String _collection = 'ratings';

  /// إضافة أو تحديث تقييم مع تحديث إحصائيات المستخدم (السائق/الراكب) تلقائياً
  Future<bool> addOrUpdateRating({
    required String tripId,
    required String bookingId,
    required String passengerId,
    required String driverId,
    required int score,
    String? comment,
    String? note,
  }) async {
    try {
      // 1. التحقق من وجود تقييم سابق من هذا الراكب لهذه الرحلة وهذا الحجز
      QuerySnapshot existing = await _firestore
          .collection(_collection)
          .where('tripId', isEqualTo: tripId)
          .where('bookingId', isEqualTo: bookingId)
          .where('fromUserId', isEqualTo: passengerId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // تحديث التقييم الموجود
        final docRef = existing.docs.first.reference;
        await docRef.update({
          'score': score,
          'rating': score.toDouble(),
          'comment': comment,
          'note': note,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // إضافة تقييم جديد باستخدام الموديل المحدث
        final ratingId = _uuid.v4();
        final rating = Rating(
          id: ratingId,
          tripId: tripId,
          bookingId: bookingId,
          fromUserId: passengerId,
          toUserId: driverId,
          passengerId: passengerId, // الحقل الجديد
          driverId: driverId,       // الحقل الجديد
          rating: score.toDouble(),
          score: score,
          comment: comment,
          note: note,
          createdAt: Timestamp.now(),
        );
        await _firestore.collection(_collection).doc(ratingId).set(rating.toMap());
      }

      // 2. تحديث إحصائيات المستخدم (المُقيَّم) في مجموعة users
      await _updateUserRatingStats(driverId);

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
      double totalScore = 0;

      for (var doc in snapshot.docs) {
        // استخدام الموديل لضمان قراءة البيانات بشكل آمن (Smart Parsing)
        final ratingObj = Rating.fromDocument(doc);
        totalScore += ratingObj.rating;
      }

      double average = totalScore / count;

      // تحديث مستند المستخدم بالحقول الموحدة
      await _firestore.collection('users').doc(userId).update({
        'averageRating': double.parse(average.toStringAsFixed(1)), // تقريب لمنزلة واحدة (مثلاً 4.7)
        'ratingCount': count,
      });

      debugPrint('Stats updated for $userId: Avg $average, Count $count');
    } catch (e) {
      debugPrint('Error updating user rating stats: $e');
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
          debugPrint('Error parsing rating doc: $e');
        }
      }

      // الترتيب يدوياً حسب التاريخ الأحدث (من الأحدث إلى الأقدم)
      list.sort((a, b) {
        final DateTime? dateA = a.createdAt?.toDate();
        final DateTime? dateB = b.createdAt?.toDate();
        if (dateA == null || dateB == null) return 0;
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
        return (data?['averageRating'] ?? 0.0).toDouble();
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }
}