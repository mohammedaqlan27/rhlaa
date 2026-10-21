// lib/screens/user_ratings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// شاشة عرض تقييمات ومراجعات المستخدم
/// تحسينات:
/// - تحويل إلى StatefulWidget لتمكين إعادة التحميل وعرض رسائل الخطأ
/// - تعامل أفضل مع استثناءات Firestore وعرض رسالة مناسبة للمستخدم
/// - دعم السحب للتحديث (Pull to refresh)
/// - تحسين تنسيقات التاريخ والـ accessibility
class UserRatingsScreen extends StatefulWidget {
  final String userId;

  const UserRatingsScreen({super.key, required this.userId});

  @override
  State<UserRatingsScreen> createState() => _UserRatingsScreenState();
}

class _UserRatingsScreenState extends State<UserRatingsScreen> {
  // ألوان الهوية البصرية
  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _starColor = Color(0xFFFFB300);
  static const Color _backgroundColor = Color(0xFFF8FAFC);

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _ratings = [];

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fetched = await _fetchRatings();
      if (mounted) {
        setState(() {
          _ratings = fetched;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('UserRatingsScreen._fetchRatings FirebaseException: ${e.code} ${e.message}');
      setState(() {
        _errorMessage = 'تعذر جلب التقييمات. تحقق من صلاحيات الوصول أو اتصال الشبكة.';
      });
    } catch (e) {
      debugPrint('UserRatingsScreen._fetchRatings error: $e');
      setState(() {
        _errorMessage = 'حدث خطأ أثناء جلب التقييمات.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRatings() async {
    // جلب التقييمات من مجموعة 'ratings' حيث الحقل toUserId يطابق userId
    final snapshot = await FirebaseFirestore.instance
        .collection('ratings')
        .where('toUserId', isEqualTo: widget.userId)
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
        } catch (_) {
          // تجاهل خطأ جلب اسم المستخدم الفرعي، نستخدم الاسم الافتراضي
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

    // نستخدم Material حول المحتوى لتضمن ظهور تأثيرات الحبر إن أضفنا تفاعلات لاحقاً
    return Material(
      color: Colors.transparent,
      child: Container(
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
            // رأس البطاقة: اسم المراجع ووقت الإنشاء
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: _logoBlue.withValues(alpha: 0.06), shape: BoxShape.circle),
                      child: const Icon(Icons.person_outline_rounded, size: 16, color: _logoBlue),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rating['fromUserName'] ?? 'راكب/سائق',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                Text(createdAtText, style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade400, fontSize: 10)),
              ],
            ),

            const SizedBox(height: 8),

            // النجوم
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

            // الملاحظة أو النص الافتراضي
            Text(
              displayNote,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: note.isNotEmpty ? Colors.black87 : Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_ratings.isEmpty) {
      return const SizedBox.shrink();
    }

    final numericRatings = _ratings.map((r) {
      final raw = r['rating'];
      return (raw is num) ? raw.toDouble() : double.tryParse(raw?.toString() ?? '') ?? 0.0;
    }).toList();

    final average = numericRatings.isNotEmpty ? numericRatings.reduce((a, b) => a + b) / numericRatings.length : 0.0;

    return Container(
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
                    Text('إجمالي المراجعات: ${_ratings.length}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('يعكس هذا المتوسط سلوك وموثوقية العضو أثناء الرحلات المشتركة.', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    await _loadRatings();
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: _logoBlue,
          child: _isLoading
              ? ListView(
            // ListView فارغ مع مؤشر تحميل لتمكين السحب للتحديث أثناء التحميل
            children: const [
              SizedBox(height: 120),
              Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: _logoBlue)),
              SizedBox(height: 12),
              Center(child: Text('جاري مراجعة سجل التقييمات...', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey))),
            ],
          )
              : _errorMessage != null
              ? ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Icon(Icons.error_outline, size: 56, color: Colors.red.shade400)),
              const SizedBox(height: 12),
              Center(child: Text(_errorMessage!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black87))),
              const SizedBox(height: 12),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _loadRatings,
                  icon: const Icon(Icons.refresh),
                  label: const Text('حاول مرة أخرى', style: TextStyle(fontFamily: 'Cairo')),
                  style: ElevatedButton.styleFrom(backgroundColor: _logoBlue),
                ),
              ),
            ],
          )
              : _ratings.isEmpty
              ? ListView(
            children: const [
              SizedBox(height: 120),
              Center(child: Icon(Icons.star_outline_rounded, size: 54, color: Colors.grey)),
              SizedBox(height: 10),
              Center(child: Text('لا توجد تقييمات مسجلة لهذا الحساب حتى الآن.', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey))),
            ],
          )
              : ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _ratings.length + 1, // +1 للكرت الملخص
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildSummaryCard();
              }
              final rating = _ratings[index - 1];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildRatingCard(rating),
              );
            },
          ),
        ),
      ),
    );
  }
}
