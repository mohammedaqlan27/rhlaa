// lib/providers/booking_provider.dart
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
      );

      // إذا كان الـ result يحتوي على معرف (UUID) فهو نجاح، وإلا فهو رسالة خطأ
      if (result != null && result.length > 20) {
        await fetchUserBookings(passengerId); // تحديث القائمة محلياً
        _setLoading(false);
        return result; // نجاح
      } else {
        _errorMessage = result ?? 'فشلت عملية الحجز';
        _setLoading(false);
        return null;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع: $e';
      _setLoading(false);
      return null;
    }
  }

  /// معالجة عملية الدفع لحجز معين
  Future<bool> payForBooking({
    required String bookingId,
    required double amount,
    required String method,
  }) async {
    _setLoading(true);
    try {
      final result = await _paymentService.processPayment(
        bookingId: bookingId,
        amount: amount,
        paymentMethod: method,
      );

      if (result.success) {
        // تحديث حالة الحجز في القائمة المحلية دون الحاجة لإعادة الجلب من السيرفر
        final index = _userBookings.indexWhere((b) => b.bookingId == bookingId);
        if (index != -1) {
          // تحديث الحالة محلياً للتفاعل الفوري في الواجهة
          _userBookings[index] = _userBookings[index].copyWith(paymentStatus: 'paid');
          notifyListeners();
        }
        _setLoading(false);
        return true;
      } else {
        _errorMessage = result.message;
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'فشلت عملية الدفع';
      _setLoading(false);
      return false;
    }
  }

  /// جلب حجوزات المستخدم
  Future<void> fetchUserBookings(String userId) async {
    _setLoading(true);
    try {
      _userBookings = await _bookingService.getBookingsForPassenger(userId);
      _setLoading(false);
    } catch (e) {
      _errorMessage = 'تعذر جلب الحجوزات';
      _setLoading(false);
    }
  }

  /// إلغاء حجز
  Future<bool> cancelUserBooking(String bookingId, String userId) async {
    _setLoading(true);
    try {
      final error = await _bookingService.cancelBooking(
        bookingId: bookingId,
        passengerId: userId,
      );

      if (error == null) {
        await fetchUserBookings(userId);
        return true;
      } else {
        _errorMessage = error;
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'فشل إلغاء الحجز';
      _setLoading(false);
      return false;
    }
  }

  // Helper لإدارة حالة التحميل
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // تنظيف الأخطاء
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}