// lib/providers/booking_provider.dart
import 'package:flutter/material.dart';
import '../models/booking_model.dart'; // تم توحيد مسار الاستيراد للموديل الصحيح
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
    _errorMessage = null; // تصفير الخطأ عند بدء عملية جديدة

    try {
      final result = await _bookingService.createBooking(
        tripId: tripId,
        passengerId: passengerId,
        seatsToBook: seatsCount,
        tripPricePerSeat: pricePerSeat,
        isFamilyBooking: isFamily,
        childrenCount: children,
      );

      // التحقق من النجاح: إذا كان الـ result ليس خطأ نصياً ومعرفاً طويلًا (UUID)
      if (result != null && !result.contains(' ') && result.length > 20) {
        await fetchUserBookings(passengerId); // تحديث القائمة من السيرفر
        _setLoading(false);
        return result; // نجاح العملية وإرجاع معرّف الحجز
      } else {
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

  /// معالجة عملية الدفع لحجز معين وتحديث الحالة فورياً
  Future<bool> payForBooking({
    required String bookingId,
    required double amount,
    required String method,
  }) async {
    _setLoading(true);
    _errorMessage = null; // تصفير الخطأ قبل العملية

    try {
      final result = await _paymentService.processPayment(
        bookingId: bookingId,
        amount: amount,
        paymentMethod: method,
      );

      if (result.success) {
        // تحديث الحقل الموحد 'id' بدلاً من 'bookingId' المسبب للخطأ
        final index = _userBookings.indexWhere((b) => b.id == bookingId);
        if (index != -1) {
          // تحديث الحالة محلياً للتفاعل الفوري فائق السرعة في الواجهة (Optimistic UI)
          _userBookings[index] = _userBookings[index].copyWith(
            paymentStatus: 'paid',
            bookingStatus: 'confirmed', // الدفع يؤكد الحجز تلقائياً
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

  /// جلب حجوزات المستخدم (الراكب) من السيرفر
  Future<void> fetchUserBookings(String userId) async {
    _setLoading(true);
    _errorMessage = null; // تصفير الخطأ لتحديث حالة الواجهة

    try {
      _userBookings = await _bookingService.getBookingsForPassenger(userId);
      _setLoading(false);
    } catch (e) {
      _errorMessage = 'تعذر جلب الحجوزات، تأكد من الاتصال بالشبكة.';
      _setLoading(false);
    }
  }

  /// إلغاء حجز وتحديث الواجهة برمجياً ومحلياً
  Future<bool> cancelUserBooking(String bookingId, String userId) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final error = await _bookingService.cancelBooking(
        bookingId: bookingId,
        passengerId: userId,
      );

      if (error == null) {
        // تحديث محلي سريع للحجز المستهدف دون انتظار رد الشبكة بالكامل لإعطاء تجربة سلسة
        final index = _userBookings.indexWhere((b) => b.id == bookingId);
        if (index != -1) {
          _userBookings[index] = _userBookings[index].copyWith(
            bookingStatus: 'cancelled',
            paymentStatus: _userBookings[index].paymentStatus == 'paid' ? 'refund_pending' : 'unpaid',
          );
        }

        // إعادة جلب خفيفة للتأكيد والمزامنة النهائية مع السيرفر
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

  // ميثود داخلي موحد لإدارة حالة التحميل وإشعار الواجهات
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // تنظيف يدوي للأخطاء عند مغادرة الشاشات
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

extension on Booking {
  get id => null;
}