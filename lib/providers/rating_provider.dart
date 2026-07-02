// lib/providers/rating_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/rating_model.dart';
import '../services/rating_service.dart';

class RatingProvider with ChangeNotifier {
  final RatingService _ratingService = RatingService();

  bool _isLoading = false;
  String? _errorMessage;
  double _averageRating = 0.0;
  List<Rating> _userRatings = [];

  StreamSubscription<List<Rating>>? _ratingsSubscription;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get averageRating => _averageRating;
  List<Rating> get userRatings => _userRatings;

  /// إضافة تقييم جديد أو تحديث تقييم سابق لرحلة محددة
  Future<bool> submitOrUpdateRating({
    required String tripId,
    required String bookingId,
    required String passengerId,
    required String driverId,
    required int score,
    String? comment,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final success = await _ratingService.addOrUpdateRating(
        tripId: tripId,
        bookingId: bookingId,
        passengerId: passengerId,
        driverId: driverId,
        score: score,
        comment: comment,
      );

      if (success) {
        // تحديث المتوسط الحسابي محلياً فور النجاح
        await fetchAverageRating(driverId);
        _setLoading(false);
        return true;
      } else {
        _errorMessage = 'فشل حفظ التقييم، يرجى المحاولة مرة أخرى.';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع: $e';
      _setLoading(false);
      return false;
    }
  }

  /// الاستماع الحي (Real-time Stream) لتقييمات مستخدم معين (سائق أو راكب)
  void listenToUserRatings(String userId) {
    _setLoading(true);
    _errorMessage = null;

    // إلغاء الاشتراك القديم إن وجد لمنع تسريب الذاكرة (Memory Leaks)
    _ratingsSubscription?.cancel();

    _ratingsSubscription = _ratingService.getRatingsForUser(userId).listen(
          (ratingsList) {
        _userRatings = ratingsList;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'خطأ أثناء جلب بث التقييمات المباشر.';
        _setLoading(false);
      },
    );
  }

  /// جلب المتوسط الحسابي لتقييمات السائق لتحديث الـ Profile
  Future<void> fetchAverageRating(String userId) async {
    try {
      _averageRating = await _ratingService.getAverageRatingFromUserDoc(userId);      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching average rating: $e');
    }
  }

  // ميثود داخلي لتغيير حالة التحميل وإشعار الواجهات
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// تنظيف وإغلاق الـ Streams عند التدمير (Dispose) أو مغادرة الصفحة
  @override
  void dispose() {
    _ratingsSubscription?.cancel();
    super.dispose();
  }

  /// تصفير البيانات يدويًا عند الحاجة لتنظيف الذاكرة
  void clear() {
    _ratingsSubscription?.cancel();
    _userRatings = [];
    _averageRating = 0.0;
    _errorMessage = null;
    notifyListeners();
  }
}