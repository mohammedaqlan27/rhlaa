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
  final Color _logoGreen = const Color(0xFF4EBF64);
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
      _tripId ??= args['tripId']?.toString();
      _targetUserId ??= args['targetUserId']?.toString();
      _userType ??= args['userType']?.toString() ?? args['role']?.toString();
    }
  }

  Future<void> _loadTargetUserName() async {
    if (_targetUserId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(_targetUserId).get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        setState(() {
          targetUserName = (data['nickname'] as String?) ?? (data['displayName'] as String?) ?? (data['name'] as String?) ?? '';
        });
      }
    } catch (e, st) {
      debugPrint('RatingScreen._loadTargetUserName error: $e\n$st');
    }
  }

  Future<bool> _hasAlreadyRated(String fromUserId) async {
    if (_tripId == null || _targetUserId == null) return false;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('tripId', isEqualTo: _tripId)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final toUser = (data['toUserId'] ?? data['to_user_id'] ?? data['to'] ?? data['targetUserId'])?.toString();
        if (toUser == _targetUserId) return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _updateUserAverageRating() async {
    if (_targetUserId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('ratings').get();
      final List<double> ratings = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final toUser = (data['toUserId'] ?? data['to_user_id'] ?? data['to'] ?? data['targetUserId'])?.toString();
        if (toUser == _targetUserId) {
          final raw = data['rating'] ?? data['score'];
          double? val;
          if (raw is num) val = raw.toDouble();
          else if (raw is String) val = double.tryParse(raw);
          if (val != null) ratings.add(val);
        }
      }

      final double average = ratings.isEmpty ? _rating : ratings.reduce((a, b) => a + b) / ratings.length;
      final userRef = FirebaseFirestore.instance.collection('users').doc(_targetUserId);
      await userRef.update({
        'averageRating': average,
        'average_rating': average,
        'ratingCount': ratings.length,
        'rating_count': ratings.length,
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❗ لقد قمت بتقييم هذا الكابتن/الراكب مسبقًا لهذه الرحلة', style: TextStyle(fontFamily: 'Cairo'))));
        setState(() => _isSubmitting = false);
        return;
      }

      final ratingPayload = <String, dynamic>{
        'tripId': _tripId,
        'fromUserId': fromUserId,
        'toUserId': _targetUserId,
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
            size: 42,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    _readRouteArgsIfNeeded();
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.person_rounded, size: 36, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'كيف كانت تجربتك مع $displayName؟',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Text(
                    'رأيك يساعدنا في الحفاظ على أمان وموثوقية مجتمع رحلة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  const Text('اضغط على النجوم لتحديد التقييم:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  _buildStarRatingBar(),
                  Text(
                    '(${_rating.toStringAsFixed(0)} من 5)',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: _logoTeal),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'اكتب ملاحظاتك أو تجاربك الإيجابية هنا...',
                      hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                      labelText: '📝 أضف تعليقاً (اختياري)',
                      labelStyle: TextStyle(fontFamily: 'Cairo', color: _logoTeal, fontSize: 13),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _logoBlue, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitRating,
                    icon: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: const Text('إرسال التقييم والملاحظة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _logoBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
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