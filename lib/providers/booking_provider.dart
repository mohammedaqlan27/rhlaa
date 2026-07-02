import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/payment_service.dart';

class BookingProvider with ChangeNotifier {
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();

  bool _isLoading = false;
  String? _errorMessage;
  List<Booking> _userBookings = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Booking> get userBookings => _userBookings;

  /// إنشاء حجز جديد
  Future<String?> createNewBooking({
    required String tripId,
    required String passengerId,
    required int seatsCount,
    required double pricePerSeat,
    bool isFamily = false,
    int children = 0,
    String? notes,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final result = await _bookingService.createBooking(
        tripId: tripId,
        passengerId: passengerId,
        seatsToBook: seatsCount,
        tripPricePerSeat: pricePerSeat,
        isFamilyBooking: isFamily,
        childrenCount: children,
        notes: notes,
      );

      // التحقق من النجاح: إذا كان الـ result هو معرف UUID (طوله عادة > 30)
      if (result != null && result.length > 20 && !result.contains(' ')) {
        await fetchUserBookings(passengerId); // تحديث القائمة
        _setLoading(false);
        return result;
      } else {
        // إذا كان الـ result نصاً عربياً فهو رسالة خطأ من السيرفر
        _errorMessage = result ?? 'فشلت عملية الحجز';
        _setLoading(false);
        return null;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع أثناء الحجز: $e';
      _setLoading(false);
      return null;
    }
  }

  /// معالجة عملية الدفع وتحديث الحالة
  Future<bool> payForBooking({
    required String bookingId,
    required double amount,
    required String method,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final result = await _paymentService.processPayment(
        bookingId: bookingId,
        amount: amount,
        paymentMethod: method,
      );

      if (result.success) {
        // تحديث الحالة محلياً فوراً (Optimistic UI)
        final index = _userBookings.indexWhere((b) => b.id == bookingId);
        if (index != -1) {
          _userBookings[index] = _userBookings[index].copyWith(
            paymentStatus: 'paid',
            bookingStatus: 'confirmed',
          );
          notifyListeners();
        }
        _setLoading(false);
        return true;
      } else {
        _errorMessage = result.message ?? 'فشلت عملية معالجة الدفع.';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع أثناء الدفع.';
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
    } catch (e) {
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
        // تحديث محلي سريع
        final index = _userBookings.indexWhere((b) => b.id == bookingId);
        if (index != -1) {
          _userBookings[index] = _userBookings[index].copyWith(
            bookingStatus: 'cancelled',
            updatedAt: null, // سيتم تحديثه من السيرفر لاحقاً
          );
          notifyListeners();
        }

        // مزامنة نهائية مع السيرفر
        _userBookings = await _bookingService.getBookingsForPassenger(userId);
        _setLoading(false);
        return true;
      } else {
        _errorMessage = error;
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'فشل إلغاء الحجز بسبب خطأ في السيرفر.';
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}