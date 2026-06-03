// lib/screens/user_ratings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserRatingsScreen extends StatelessWidget {
  final String userId;

  const UserRatingsScreen({super.key, required this.userId});

  Future<List<Map<String, dynamic>>> _fetchRatings() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('toUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final ratings = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fromUserId = data['fromUserId'] ?? data['from_user_id'];

        String fromUserName = 'مستخدم غير معروف';
        if (fromUserId != null) {
          try {
            final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(fromUserId.toString()).get();
            if (userSnapshot.exists) {
              final userData = userSnapshot.data();
              if (userData != null) {
                fromUserName = (userData['name'] ?? userData['nickname'] ?? userData['displayName'] ?? fromUserName).toString();
              }
            }
          } catch (_) {
            // تجاهل خطأ جلب اسم المستخدم، نستخدم الاسم الافتراضي
          }
        }

        ratings.add({
          'rating': data['rating'] ?? data['score'] ?? 0,
          'note': data['note'] ?? data['comment'] ?? '',
          'createdAt': data['createdAt'] ?? data['created_at'],
          'fromUserName': fromUserName,
        });
      }

      return ratings;
    } catch (e) {
      debugPrint('UserRatingsScreen._fetchRatings error: $e');
      return <Map<String, dynamic>>[];
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'غير معروف';
    try {
      if (ts is Timestamp) {
        return DateFormat('yyyy-MM-dd – HH:mm').format(ts.toDate());
      }
      if (ts is DateTime) {
        return DateFormat('yyyy-MM-dd – HH:mm').format(ts);
      }
      final parsed = DateTime.tryParse(ts.toString());
      if (parsed != null) return DateFormat('yyyy-MM-dd – HH:mm').format(parsed);
    } catch (_) {}
    return 'غير معروف';
  }

  Widget _buildRatingCard(Map<String, dynamic> rating) {
    final createdAtText = _formatTimestamp(rating['createdAt']);
    final note = (rating['note'] ?? '').toString().trim();
    final displayNote = note.isNotEmpty ? note : 'لا توجد ملاحظة';
    final rawRating = rating['rating'];
    final ratingValue = (rawRating is num) ? rawRating.toDouble() : double.tryParse(rawRating?.toString() ?? '') ?? 0.0;
    final stars = ratingValue.round().clamp(0, 5);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('👤 من: ${rating['fromUserName']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < stars ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('📝 الملاحظة: $displayNote'),
          const SizedBox(height: 6),
          Text('📅 التاريخ: $createdAtText', style: const TextStyle(color: Colors.grey)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⭐ التقييمات السابقة'),
        backgroundColor: Colors.orange.shade700,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchRatings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('جاري تحميل التقييمات...', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('❌ حدث خطأ أثناء تحميل التقييمات: ${snapshot.error}'));
          }

          final ratings = snapshot.data ?? [];
          if (ratings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('لا توجد تقييمات حتى الآن.', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          // حساب المتوسط بأمان
          final numericRatings = ratings.map((r) {
            final raw = r['rating'];
            if (raw is num) return raw.toDouble();
            return double.tryParse(raw?.toString() ?? '') ?? 0.0;
          }).toList();

          final average = numericRatings.isNotEmpty
              ? numericRatings.reduce((a, b) => a + b) / numericRatings.length
              : 0.0;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('⭐ متوسط التقييم: ${average.toStringAsFixed(1)} من 5',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: ratings.length,
                  itemBuilder: (context, index) => _buildRatingCard(ratings[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
