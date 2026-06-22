// lib/screens/user_ratings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserRatingsScreen extends StatelessWidget {
  final String userId;

  const UserRatingsScreen({super.key, required this.userId});

  // ثيمات الهوية البصرية لتطبيق رحلاء
  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoTeal = Color(0xFF17A5A3);
  static const Color _starColor = Color(0xFFFFB300);
  static const Color _backgroundColor = Color(0xFFF8FAFC);

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

        String fromUserName = 'عضو في رحلاء';
        if (fromUserId != null) {
          try {
            final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(fromUserId.toString()).get();
            if (userSnapshot.exists) {
              final userData = userSnapshot.data();
              if (userData != null) {
                fromUserName = (userData['nickname'] ?? userData['name'] ?? userData['displayName'] ?? fromUserName).toString();
              }
            }
          } catch (_) {}
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
    if (ts == null) return 'تاريخ غير محدد';
    try {
      if (ts is Timestamp) return DateFormat('yyyy/MM/dd | hh:mm a', 'ar').format(ts.toDate());
      if (ts is DateTime) return DateFormat('yyyy/MM/dd | hh:mm a', 'ar').format(ts);
    } catch (_) {}
    return 'قبل قليل';
  }

  Widget _buildRatingCard(Map<String, dynamic> rating) {
    final createdAtText = _formatTimestamp(rating['createdAt']);
    final note = (rating['note'] ?? '').toString().trim();
    final displayNote = note.isNotEmpty ? note : 'اكتفى بالتقييم بالنجوم فقط دون إضافة ملاحظة.';
    final rawRating = rating['rating'];
    final ratingValue = (rawRating is num) ? rawRating.toDouble() : double.tryParse(rawRating?.toString() ?? '') ?? 0.0;
    final stars = ratingValue.round().clamp(0, 5);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: _logoBlue.withOpacity(0.06), shape: BoxShape.circle),
                    child: const Icon(Icons.person_outline_rounded, size: 16, color: _logoBlue),
                  ),
                  const SizedBox(width: 8),
                  Text(rating['fromUserName'] ?? 'راكب/سائق', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              Text(createdAtText, style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade400, fontSize: 10)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 4)),
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                color: i < stars ? _starColor : Colors.grey.shade300,
                size: 16,
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            displayNote,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: note.isNotEmpty ? Colors.black : Colors.grey.shade500, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('سجل الآراء والتقييمات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchRatings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5, color: _logoBlue),
                  SizedBox(height: 12),
                  Text('جاري مراجعة سجل التقييمات...', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey)),
                ],
              ),
            );
          }

          final ratings = snapshot.data ?? [];
          if (ratings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_outline_rounded, size: 54, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('لا توجد تقييمات مسجلة لهذا الحساب حتى الآن.', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey)),
                ],
              ),
            );
          }

          // حساب الإحصائيات الرياضية
          final numericRatings = ratings.map((r) {
            final raw = r['rating'];
            return (raw is num) ? raw.toDouble() : double.tryParse(raw?.toString() ?? '') ?? 0.0;
          }).toList();

          final average = numericRatings.reduce((a, b) => a + b) / numericRatings.length;

          return Column(
            children: [
              // كرت علوي مخصص للملخص العام
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Text(average.toStringAsFixed(1), style: TextStyle(fontFamily: 'Cairo', fontSize: 36, fontWeight: FontWeight.bold, color: _logoBlue, height: 1.1)),
                        const Text('من 5 درجات', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Container(width: 1, height: 50, color: Colors.grey.shade200),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star_rounded, color: _starColor, size: 18),
                              const SizedBox(width: 4),
                              Text('إجمالي المراجعات: ${ratings.length}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('يعكس هذا المتوسط سلوك وموثوقية العضو أثناء الرحلات المشتركة.', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ],
                ),
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