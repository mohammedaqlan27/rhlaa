// lib/screens/rating_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingScreen extends StatefulWidget {
  final String? tripId;
  final String? targetUserId;
  final String? userType;

  const RatingScreen({super.key, this.tripId, this.targetUserId, this.userType});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _rating = 5.0; // القيمة الافتراضية للتقييم الممتاز
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;
  String targetUserName = '';

  String? _tripId;
  String? _targetUserId;
  String? _userType;

  // ثيمات وألوان هوية "رحلاء"
  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _starColor = const Color(0xFFFFB300);
  final Color _backgroundColor = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _tripId = widget.tripId;
    _targetUserId = widget.targetUserId;
    _userType = widget.userType;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readRouteArgsIfNeeded();
      _loadTargetUserName();
    });
  }

  void _readRouteArgsIfNeeded() {
    if ((_tripId != null && _targetUserId != null && _userType != null) || ModalRoute.of(context) == null) {
      return;
    }
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() {
        _tripId ??= args['tripId']?.toString();
        _targetUserId ??= args['targetUserId']?.toString();
        _userType ??= args['userType']?.toString() ?? args['role']?.toString();
      });
    }
  }

  Future<void> _loadTargetUserName() async {
    if (_targetUserId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(_targetUserId).get();
      if (snapshot.exists) {
        final data = snapshot.data() ?? {};
        setState(() {
          targetUserName = (data['nickname'] as String?) ?? (data['displayName'] as String?) ?? (data['name'] as String?) ?? '';
        });
      }
    } catch (e, st) {
      debugPrint('RatingScreen._loadTargetUserName error: $e\n$st');
    }
  }

  // التحقق من وجود تقييم مسبق باستخدام fromUserId و toUserId
  Future<bool> _hasAlreadyRated(String fromUserId) async {
    if (_tripId == null || _targetUserId == null) return false;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: _targetUserId)
          .where('tripId', isEqualTo: _tripId)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // تحديث متوسط التقييم للمستخدم المستهدف (toUserId)
  Future<void> _updateUserAverageRating() async {
    if (_targetUserId == null) return;
    try {
      // استعلام فقط عن التقييمات الموجهة لهذا المستخدم
      final snapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('toUserId', isEqualTo: _targetUserId)
          .get();

      final List<double> ratings = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final raw = data['rating'];
        if (raw is num) {
          ratings.add(raw.toDouble());
        }
      }

      final double average = ratings.isEmpty ? _rating : ratings.reduce((a, b) => a + b) / ratings.length;

      await FirebaseFirestore.instance.collection('users').doc(_targetUserId).update({
        'averageRating': average,
        'ratingCount': ratings.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('RatingScreen._updateUserAverageRating error: $e');
    }
  }

  Future<void> _submitRating() async {
    if (_targetUserId == null || _tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ بيانات التقييم غير مكتملة', style: TextStyle(fontFamily: 'Cairo'))));
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final fromUserId = FirebaseAuth.instance.currentUser?.uid;
    if (fromUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ يجب تسجيل الدخول لإرسال التقييم', style: TextStyle(fontFamily: 'Cairo'))));
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final alreadyRated = await _hasAlreadyRated(fromUserId);
      if (alreadyRated) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❗ لقد قمت بتقييم هذا الشخص مسبقًا لهذه الرحلة', style: TextStyle(fontFamily: 'Cairo'))));
        setState(() => _isSubmitting = false);
        return;
      }

      // استخدام fromUserId بشكل صريح كما هو مطلوب
      final ratingPayload = <String, dynamic>{
        'tripId': _tripId,
        'fromUserId': fromUserId, // الشخص الذي قام بالتقييم
        'toUserId': _targetUserId, // الشخص الذي تم تقييمه
        'userType': _userType ?? 'غير محدد',
        'rating': _rating,
        'note': _noteController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('ratings').add(ratingPayload);
      await _updateUserAverageRating();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ شكرًا لك! تم حفظ تقييمك بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل في إرسال التقييم: $e', style: const TextStyle(fontFamily: 'Cairo'))));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildStarRatingBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1.0;
        return IconButton(
          onPressed: () => setState(() => _rating = starValue),
          icon: Icon(
            _rating >= starValue ? Icons.star_rounded : Icons.star_border_rounded,
            color: _rating >= starValue ? _starColor : Colors.grey.shade400,
            size: 48,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = targetUserName.isNotEmpty ? targetUserName : 'مستخدم رحلة';

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('تقييم تجربة الرحلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: _logoBlue.withValues(alpha: 0.1),
                    child: Icon(Icons.person_rounded, size: 45, color: _logoBlue),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'كيف كانت تجربتك مع $displayName؟',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'رأيك يساعدنا في الحفاظ على أمان وموثوقية مجتمع رحلة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(),
                  ),
                  _buildStarRatingBar(),
                  const SizedBox(height: 10),
                  Text(
                    '(${_rating.toStringAsFixed(0)} من 5)',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: _logoTeal),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _noteController,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'اكتب ملاحظاتك أو تجاربك الإيجابية هنا...',
                      hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      labelText: '📝 أضف تعليقاً (اختياري)',
                      labelStyle: TextStyle(fontFamily: 'Cairo', color: _logoTeal, fontSize: 14),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: _backgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: _logoBlue, width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _logoBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('إرسال التقييم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}