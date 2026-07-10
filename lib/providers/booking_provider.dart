// lib/providers/booking_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/payment_service.dart';

class BookingProvider with ChangeNotifier {
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _errorMessage;
  List<Booking> _userBookings = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Booking> get userBookings => _userBookings;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// سير العمل الجديد:
  /// 1) إنشاء حجز pending (يحجز المقاعد مؤقتًا)
  /// 2) معالجة الدفع عبر PaymentService
  /// 3) عند نجاح الدفع: تأكيد الحجز (confirmBookingAfterPayment)
  /// 4) عند فشل الدفع: إلغاء الحجز وإرجاع المقاعد
  Future<String?> createNewBooking({
    required String tripId,
    required String passengerId,
    required int seatsCount,
    required double pricePerSeat,
    bool isFamily = false,
    int children = 0,
    String? notes,
    required String paymentMethod, // مثال: 'card'
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // 1) إنشاء الحجز كـ pending
      final bookingIdOrError = await _bookingService.createBookingPending(
        tripId: tripId,
        passengerId: passengerId,
        seatsToBook: seatsCount,
        tripPricePerSeat: pricePerSeat,
        isFamilyBooking: isFamily,
        childrenCount: children,
        notes: notes,
      );

      if (bookingIdOrError == null) {
        _errorMessage = 'فشل إنشاء الحجز.';
        _setLoading(false);
        return null;
      }

      // إذا كانت القيمة عبارة عن رسالة خطأ نصية
      // createBookingPending يعيد bookingId عند النجاح أو رسالة خطأ
      // نتحقق إن كانت صيغة UUID تقريبًا (طويلة) أو رسالة قصيرة
      final bookingId = bookingIdOrError;
      if (bookingId.length < 8) {
        _errorMessage = bookingIdOrError;
        _setLoading(false);
        return null;
      }

      // 2) معالجة الدفع
      final totalAmount = pricePerSeat * seatsCount;
      final paymentResult = await _paymentService.processPayment(
        bookingId: bookingId,
        amount: totalAmount,
        paymentMethod: paymentMethod,
      );

      if (!paymentResult.success) {
        // فشل الدفع -> إلغاء الحجز وإرجاع المقاعد
        await _bookingService.cancelBooking(bookingId: bookingId, passengerId: passengerId);
        _errorMessage = paymentResult.message ?? 'فشل الدفع.';
        _setLoading(false);
        // تحديث قائمة الحجوزات المحلية
        await fetchUserBookings(passengerId);
        return null;
      }

      // 3) نجاح الدفع -> تأكيد الحجز
      final confirmError = await _bookingService.confirmBookingAfterPayment(
        bookingId: bookingId,
        paymentIntentId: paymentResult.transactionId ?? '',
        payerId: passengerId,
      );

      if (confirmError != null) {
        // إذا فشل التأكيد، نحاول إلغاء الحجز
        await _bookingService.cancelBooking(bookingId: bookingId, passengerId: passengerId);
        _errorMessage = confirmError;
        _setLoading(false);
        await fetchUserBookings(passengerId);
        return null;
      }

      // 4) تحديث القائمة المحلية وإرجاع المعرف
      await fetchUserBookings(passengerId);
      _setLoading(false);
      return bookingId;
    } catch (e, st) {
      debugPrint('BookingProvider.createNewBooking error: $e\n$st');
      _errorMessage = 'حدث خطأ أثناء إنشاء الحجز أو الدفع.';
      _setLoading(false);
      return null;
    }
  }

  /// معالجة عملية الدفع منفصلة (إذا أردت تنفيذ الدفع في شاشة مستقلة)
  Future<bool> payForExistingBooking({
    required String bookingId,
    required String passengerId,
    required double amount,
    required String paymentMethod,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final paymentResult = await _paymentService.processPayment(
        bookingId: bookingId,
        amount: amount,
        paymentMethod: paymentMethod,
      );

      if (!paymentResult.success) {
        _errorMessage = paymentResult.message ?? 'فشل الدفع.';
        _setLoading(false);
        return false;
      }

      final confirmError = await _bookingService.confirmBookingAfterPayment(
        bookingId: bookingId,
        paymentIntentId: paymentResult.paymentIntentId ?? '',
        payerId: passengerId,
      );

      if (confirmError != null) {
        _errorMessage = confirmError;
        _setLoading(false);
        return false;
      }

      await fetchUserBookings(passengerId);
      _setLoading(false);
      return true;
    } catch (e, st) {
      debugPrint('BookingProvider.payForExistingBooking error: $e\n$st');
      _errorMessage = 'حدث خطأ أثناء الدفع.';
      _setLoading(false);
      return false;
    }
  }

  /// جلب حجوزات المستخدم (الراكب)
  Future<void> fetchUserBookings(String userId) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _userBookings = await _bookingService.getBookingsForPassenger(userId);
      _setLoading(false);
      notifyListeners();
    } catch (e, st) {
      debugPrint('BookingProvider.fetchUserBookings error: $e\n$st');
      _errorMessage = 'تعذر جلب الحجوزات، تأكد من الاتصال بالشبكة.';
      _setLoading(false);
    }
  }

  /// إلغاء حجز وتحديث الواجهة
  Future<bool> cancelUserBooking(String bookingId, String userId) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final error = await _bookingService.cancelBooking(
        bookingId: bookingId,
        passengerId: userId,
      );

      if (error == null) {
        await fetchUserBookings(userId);
        _setLoading(false);
        return true;
      } else {
        _errorMessage = error;
        _setLoading(false);
        return false;
      }
    } catch (e, st) {
      debugPrint('BookingProvider.cancelUserBooking error: $e\n$st');
      _errorMessage = 'فشل إلغاء الحجز بسبب خطأ في السيرفر.';
      _setLoading(false);
      return false;
    }
  }
}
