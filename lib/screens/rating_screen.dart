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
  double _rating = 3.0;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;
  String targetUserName = '';

  String? _tripId;
  String? _targetUserId;
  String? _userType;

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
          targetUserName = (data['nickname'] as String?) ?? (data['displayName'] as String?) ?? '';
        });
      }
    } catch (e, st) {
      debugPrint('RatingScreen._loadTargetUserName error: $e\n$st');
    }
  }

  /// يفحص محلياً إن كان المستخدم قد قيّم هذه الرحلة سابقاً
  Future<bool> _hasAlreadyRated(String fromUserId) async {
    if (_tripId == null || _targetUserId == null) return false;
    try {
      // نجلب التقييمات التي أرسلها fromUserId لنفس الرحلة (بأي تسمية للحقل tripId/fromUserId)
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

      // fallback: في حال لم تُرجع الاستعلامات أعلاه شيئاً (اختلاف أسماء الحقول)، نبحث محلياً في مجموعة التقييمات للرحلة
      final fallbackSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('tripId', isEqualTo: _tripId)
          .get();

      for (final doc in fallbackSnapshot.docs) {
        final data = doc.data();
        final from = (data['fromUserId'] ?? data['from_user_id'] ?? data['from'])?.toString();
        final to = (data['toUserId'] ?? data['to_user_id'] ?? data['to'])?.toString();
        if (from == fromUserId && to == _targetUserId) return true;
      }
    } catch (e, st) {
      debugPrint('RatingScreen._hasAlreadyRated error: $e\n$st');
    }
    return false;
  }

  /// يجمع كل التقييمات الموجّهة للمستخدم (يدعم تسميات متعددة) ثم يحسب المتوسط
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

      // إذا لم توجد تقييمات بعد، لا نكتب صفر بل نترك القيمة كما هي أو نكتب التقييم الحالي
      final double average = ratings.isEmpty ? _rating : ratings.reduce((a, b) => a + b) / ratings.length;

      // حدّث الحقول بصيغ متعددة لزيادة التوافق
      final userRef = FirebaseFirestore.instance.collection('users').doc(_targetUserId);
      await userRef.update({
        'averageRating': average,
        'average_rating': average,
        'ratingCount': ratings.length,
        'rating_count': ratings.length,
      });
    } catch (e, st) {
      debugPrint('RatingScreen._updateUserAverageRating error: $e\n$st');
    }
  }

  Future<void> _submitRating() async {
    if (_targetUserId == null || _tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ بيانات التقييم ناقصة')));
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final fromUserId = FirebaseAuth.instance.currentUser?.uid;
    if (fromUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ يجب تسجيل الدخول لإرسال التقييم')));
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final alreadyRated = await _hasAlreadyRated(fromUserId);
      if (alreadyRated) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❗ لقد قمت بتقييم هذا المستخدم مسبقًا')));
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

      // اكتب التقييم
      await FirebaseFirestore.instance.collection('ratings').add(ratingPayload);

      // حدّث متوسط التقييم للمستخدم
      await _updateUserAverageRating();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إرسال التقييم بنجاح')));
      Navigator.pop(context);
    } catch (e, st) {
      debugPrint('RatingScreen._submitRating error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل في إرسال التقييم: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget buildRatingForm() {
    final displayName = targetUserName.isNotEmpty ? targetUserName : (_targetUserId ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🧑‍💼 تقييم لـ: $displayName',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        const Text('⭐ اختر تقييمك للطرف الآخر:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        Slider(
          value: _rating,
          min: 1,
          max: 5,
          divisions: 4,
          label: _rating.toStringAsFixed(1),
          onChanged: (val) => setState(() => _rating = val),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '📝 ملاحظة (اختياري)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitRating,
          icon: _isSubmitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
          label: Text(_isSubmitting ? 'جاري الإرسال...' : 'إرسال التقييم'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _readRouteArgsIfNeeded();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقييم الرحلة'),
        backgroundColor: Colors.orange.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: buildRatingForm(),
          ),
        ),
      ),
    );
  }
}
