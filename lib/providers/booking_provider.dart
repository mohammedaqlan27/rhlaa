// lib/providers/booking_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/payment_service.dart';

class BookingProvider with ChangeNotifier {
  // تهيئة الخدمات (تستخدم النسخ الافتراضية تلقائياً)
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();

  bool _isLoading = false;
  String? _errorMessage;
  List<Booking> _userBookings = [];

  // اشتراك للبث المباشر
  StreamSubscription<List<Booking>>? _bookingsSubscription;

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

  // ---------------------------------------------------------
  // 1. إدارة الحجوزات (العمليات)
  // ---------------------------------------------------------

  /// إنشاء حجز جديد (Pending -> Payment -> Confirm)
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
      // 1) إنشاء الحجز كـ pending (حجز المقاعد مؤقتاً)
      final result = await _bookingService.createBookingPending(
        tripId: tripId,
        passengerId: passengerId,
        seatsToBook: seatsCount,
        tripPricePerSeat: pricePerSeat,
        isFamilyBooking: isFamily,
        childrenCount: children,
        notes: notes,
      );

      // التحقق مما إذا كان الرد رسالة خطأ أو معرف حجز
      if (result == null || result.length < 5) {
        _errorMessage = result ?? 'فشل إنشاء الحجز.';
        _setLoading(false);
        return null;
      }

      final bookingId = result;

      // 2) معالجة الدفع
      final totalAmount = pricePerSeat * seatsCount;
      final paymentResult = await _paymentService.processPayment(
        bookingId: bookingId,
        amount: totalAmount,
        paymentMethod: paymentMethod,
      );

      if (!paymentResult.success) {
        // فشل الدفع -> إلغاء الحجز فوراً لتحرير المقاعد
        await _bookingService.cancelBooking(bookingId: bookingId, passengerId: passengerId);
        _errorMessage = paymentResult.message ?? 'فشل عملية الدفع.';
        _setLoading(false);
        return null;
      }

      // 3) نجاح الدفع -> تأكيد الحجز
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
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع أثناء الحجز.';
      _setLoading(false);
      return null;
    }
  }

  /// إلغاء حجز (مع دعم منطق الاسترداد التلقائي في الخدمة)
  Future<bool> cancelUserBooking(String bookingId, String userId) async {
    _setLoading(true);
    try {
      final error = await _bookingService.cancelBooking(
        bookingId: bookingId,
        passengerId: userId,
      );

      if (error == null) {
        _setLoading(false);
        return true;
      } else {
        _errorMessage = error;
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'فشل إلغاء الحجز.';
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------
  // 2. جلب البيانات والبث المباشر (Real-time)
  // ---------------------------------------------------------

  /// الاستماع لحجوزات المستخدم وتحديث الواجهة تلقائياً (أفضل من fetch)
  void listenToUserBookings(String userId) {
    _bookingsSubscription?.cancel(); // إلغاء أي اشتراك قديم
    _setLoading(true);

    _bookingsSubscription = _bookingService
        .streamBookingsForPassenger(userId)
        .listen((bookings) {
      _userBookings = bookings;
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      _errorMessage = 'خطأ في تحديث البيانات المباشرة.';
      _setLoading(false);
    });
  }

  /// جلب تفاصيل حجز واحد (مفيد لصفحة النجاح أو التفاصيل)
  Future<Booking?> getBookingDetails(String bookingId) async {
    return await _bookingService.getBookingById(bookingId);
  }

  /// عرض السائق: الحصول على بث مباشر لركاب رحلة معينة
  Stream<List<Booking>> getTripBookingsStream(String tripId) {
    return _bookingService.streamConfirmedBookingsForTrip(tripId);
  }

  // ---------------------------------------------------------
  // 3. خدمات إضافية
  // ---------------------------------------------------------

  /// الانضمام لقائمة الانتظار
  Future<void> joinWaitlist(String tripId, String userId) async {
    try {
      await _bookingService.addToWaitlist(tripId, userId);
    } catch (e) {
      _errorMessage = 'تعذر الانضمام لقائمة الانتظار.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel(); // تنظيف الذاكرة عند إغلاق الـ Provider
    super.dispose();
  }
}