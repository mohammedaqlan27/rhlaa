// lib/providers/booking_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/payment_service.dart';

class BookingProvider with ChangeNotifier {
  final BookingService _bookingService;
  final PaymentService _paymentService;

  BookingProvider({
    BookingService? bookingService,
    PaymentService? paymentService,
  })  : _bookingService = bookingService ?? BookingService(),
        _paymentService = paymentService ?? PaymentService();

  bool _isLoading = false;
  String? _errorMessage;

  // بيانات المستخدم (حجوزاته)
  List<Booking> _userBookings = [];

  // بيانات السائق (حجوزات مرتبطة برحلات السائق)
  List<Booking>? _driverBookings;

  // إشتراك بث مباشر (إذا رغبت)
  StreamSubscription<List<Booking>>? _userBookingsSub;
  StreamSubscription<List<Booking>>? _driverBookingsSub;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Booking> get userBookings => List.unmodifiable(_userBookings);
  List<Booking>? get driverBookings => _driverBookings == null ? null : List.unmodifiable(_driverBookings!);

  // حسابات مساعدة للسائق
  double? _totalEarnings;
  double? get totalEarnings => _totalEarnings;
  double? get averageRating {
    final rated = _userBookings.where((b) => b.paymentStatus != null).toList();
    if (rated.isEmpty) return 0.0;
    // لا يوجد حقل rating في Booking model الحالي، لذا نعيد 0.0 أو يمكن تعديل لاحقاً
    return 0.0;
  }

  int? get ratingCount => _userBookings.where((b) => b.paymentStatus != null).length;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // -------------------------
  // 1) إنشاء حجز (كما في الكود السابق)
  // -------------------------
  Future<String?> createNewBooking({
    required String tripId,
    required String passengerId,
    required int seatsCount,
    required double pricePerSeat,
    bool isFamily = false,
    int children = 0,
    String? notes,
    required String paymentMethod,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final result = await _bookingService.createBookingPending(
        tripId: tripId,
        passengerId: passengerId,
        seatsToBook: seatsCount,
        tripPricePerSeat: pricePerSeat,
        isFamilyBooking: isFamily,
        childrenCount: children,
        notes: notes,
      );

      if (result == null || result.length < 5) {
        _errorMessage = result ?? 'فشل إنشاء الحجز.';
        _setLoading(false);
        return null;
      }

      final bookingId = result;

      final totalAmount = pricePerSeat * seatsCount;
      final paymentResult = await _paymentService.processPayment(
        bookingId: bookingId,
        amount: totalAmount,
        paymentMethod: paymentMethod,
      );

      if (!paymentResult.success) {
        // إلغاء الحجز لتحرير المقاعد
        await _bookingService.cancelBooking(bookingId: bookingId, passengerId: passengerId);
        _errorMessage = paymentResult.message ?? 'فشل عملية الدفع.';
        _setLoading(false);
        return null;
      }

      final confirmError = await _bookingService.confirmBookingAfterPayment(
        bookingId: bookingId,
        paymentIntentId: paymentResult.transactionId ?? '',
        payerId: passengerId,
      );

      if (confirmError != null) {
        _errorMessage = confirmError;
        _setLoading(false);
        return null;
      }

      _setLoading(false);
      return bookingId;
    } catch (e, st) {
      if (kDebugMode) debugPrint('BookingProvider.createNewBooking error: $e\n$st');
      _errorMessage = 'حدث خطأ غير متوقع أثناء الحجز.';
      _setLoading(false);
      return null;
    }
  }

  // -------------------------
  // 2) إلغاء حجز من الواجهة (راكب أو سائق)
  // -------------------------
  Future<bool> cancelUserBooking(String bookingId, String userId) async {
    _setLoading(true);
    try {
      final error = await _bookingService.cancelBooking(bookingId: bookingId, passengerId: userId);
      if (error == null) {
        _setLoading(false);
        return true;
      } else {
        _errorMessage = error;
        _setLoading(false);
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BookingProvider.cancelUserBooking error: $e');
      _errorMessage = 'فشل إلغاء الحجز.';
      _setLoading(false);
      return false;
    }
  }

  // -------------------------
  // 3) بث مباشر لحجوزات الراكب
  // -------------------------
  void listenToUserBookings(String userId) {
    _userBookingsSub?.cancel();
    _setLoading(true);
    _userBookingsSub = _bookingService.streamBookingsForPassenger(userId).listen((bookings) {
      _userBookings = bookings;
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      _errorMessage = 'خطأ في تحديث البيانات المباشرة.';
      _setLoading(false);
    });
  }

  Future<Booking?> getBookingDetails(String bookingId) async {
    return await _bookingService.getBookingById(bookingId);
  }

  Stream<List<Booking>> getTripBookingsStream(String tripId) {
    return _bookingService.streamConfirmedBookingsForTrip(tripId);
  }

  // -------------------------
  // 4) دوال للسائق (مطلوبة من الشاشات)
  // -------------------------

  /// جلب حجوزات السائق (مرة واحدة) — تُستخدم مع Future.wait
  Future<void> fetchDriverBookings(String driverId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      // نأخذ أول قيمة من البث الخاص بالسائق
      final list = await _bookingService.streamBookingsForDriver(driverId).first;
      _driverBookings = list;
      notifyListeners();
    } catch (e, st) {
      if (kDebugMode) debugPrint('BookingProvider.fetchDriverBookings error: $e\n$st');
      _errorMessage = 'فشل جلب حجوزات السائق.';
    } finally {
      _setLoading(false);
    }
  }

  /// قبول حجز مخصص لشاشة driver_bookings_screen
  Future<bool> acceptBooking(String bookingId, String tripId) async {
    _setLoading(true);
    try {
      final err = await _bookingService.confirmBookingByDriverSafe(bookingId);
      if (err == null) {
        _setLoading(false);
        return true;
      } else {
        _errorMessage = err;
        _setLoading(false);
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BookingProvider.acceptBooking error: $e');
      _errorMessage = 'فشل قبول الحجز.';
      _setLoading(false);
      return false;
    }
  }

  /// رفض حجز مخصص لشاشة driver_bookings_screen
  Future<bool> rejectBooking(String bookingId, String tripId, {String? reason}) async {
    _setLoading(true);
    try {
      final err = await _bookingService.rejectBookingByDriverSafe(bookingId, reason: reason ?? 'رفض من السائق');
      if (err == null) {
        _setLoading(false);
        return true;
      } else {
        _errorMessage = err;
        _setLoading(false);
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BookingProvider.rejectBooking error: $e');
      _errorMessage = 'فشل رفض الحجز.';
      _setLoading(false);
      return false;
    }
  }

  /// قبول حجز من قبل السائق
  Future<bool> confirmBooking(String bookingId) async {
    _setLoading(true);
    try {
      final err = await _bookingService.confirmBookingByDriverSafe(bookingId);
      if (err == null) {
        _setLoading(false);
        return true;
      } else {
        _errorMessage = err;
        _setLoading(false);
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BookingProvider.confirmBooking error: $e');
      _errorMessage = 'فشل قبول الحجز.';
      _setLoading(false);
      return false;
    }
  }

  /// رفض/إلغاء حجز من قبل السائق (مع سبب اختياري)
  Future<bool> cancelBooking(String bookingId, {bool byDriver = false, String? reason}) async {
    _setLoading(true);
    try {
      if (byDriver) {
        final err = await _bookingService.rejectBookingByDriverSafe(bookingId, reason: reason ?? 'رفض من السائق');
        if (err == null) {
          _setLoading(false);
          return true;
        } else {
          _errorMessage = err;
          _setLoading(false);
          return false;
        }
      } else {
        // إلغاء من الراكب (نحتاج passengerId) — هنا نعيد false لأن الواجهة عادةً تستدعي cancelUserBooking
        _setLoading(false);
        _errorMessage = 'استخدم cancelUserBooking لإلغاء من الراكب.';
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BookingProvider.cancelBooking error: $e');
      _errorMessage = 'فشل رفض/إلغاء الحجز.';
      _setLoading(false);
      return false;
    }
  }

  // -------------------------
  // 5) Refund wrapper (نداء إلى PaymentService.refundPayment)
  // -------------------------
  Future<PaymentResult> refund({String? transactionId, String? bookingId, required String reason}) async {
    try {
      final res = await _paymentService.refundPayment(transactionId: transactionId, bookingId: bookingId, reason: reason);
      if (!res.success) _errorMessage = res.message;
      return res;
    } catch (e) {
      if (kDebugMode) debugPrint('BookingProvider.refund error: $e');
      return PaymentResult(success: false, message: 'فشل محاولة الاسترجاع');
    }
  }

  @override
  void dispose() {
    _userBookingsSub?.cancel();
    _driverBookingsSub?.cancel();
    super.dispose();
  }
}