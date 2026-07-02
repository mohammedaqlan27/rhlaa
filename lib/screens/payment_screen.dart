// lib/screens/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/notification_service.dart';
import '../services/payment_service.dart';
import 'payment_confirmation_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String tripId;
  final int seatNumber;
  final String bookingId;

  const PaymentScreen({
    super.key,
    required this.tripId,
    required this.seatNumber,
    required this.bookingId, required String amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'نقداً عند اللقاء';
  bool _isProcessing = false;
  String? _errorMessage;
  double _amount = 0.0;

  final PaymentService _paymentService = PaymentService();

  // ألوان هوية رحلاء البصرية
  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _logoGreen = const Color(0xFF4EBF64);
  final Color _backgroundColor = const Color(0xFFF8FAFC);

  final List<Map<String, dynamic>> _methods = [
    {'title': 'نقداً عند اللقاء', 'subtitle': 'الدفع المباشر للكابتن فور الركوب', 'icon': Icons.money_rounded},
    {'title': 'محفظة جوال (كريمي/ام فلوس)', 'subtitle': 'عبر تحويل كود QR أو رقم الحساب', 'icon': Icons.account_balance_wallet_rounded},
    {'title': 'بطاقة إلكترونية كيرت', 'subtitle': 'قريباً - الدفع الآمن داخل التطبيق', 'icon': Icons.credit_card_rounded, 'disabled': true},
  ];

  @override
  void initState() {
    super.initState();
    _loadBookingAmountIfNeeded();
  }

  Future<void> _loadBookingAmountIfNeeded() async {
    try {
      final bookingId = widget.bookingId.isNotEmpty ? widget.bookingId : null;
      if (bookingId != null) {
        final snap = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>? ?? {};
          final tp = data['totalPrice'] ?? data['amountPaid'] ?? data['price'];
          if (tp is num) {
            setState(() => _amount = tp.toDouble());
          } else if (tp is String) {
            setState(() => _amount = double.tryParse(tp) ?? 0.0);
          }
        }
      }
    } catch (e, st) {
      debugPrint('PaymentScreen._loadBookingAmountIfNeeded error: $e\n$st');
    }
  }

  String _formatCurrency(double value) {
    if (value % 1 == 0) return '${value.toStringAsFixed(0)} ر.ي';
    return '${value.toStringAsFixed(2)} ر.ي';
  }

  void _showPaymentMethodsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('💳 اختر طريقة الدفع المفضلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              ..._methods.map((method) {
                final bool isDisabled = method['disabled'] == true;
                return ListTile(
                  enabled: !isDisabled,
                  leading: Icon(method['icon'] as IconData, color: isDisabled ? Colors.grey : _logoTeal),
                  title: Text(method['title'] as String, style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600, color: isDisabled ? Colors.grey : Colors.black87)),
                  subtitle: Text(method['subtitle'] as String, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                  trailing: _selectedMethod == method['title'] ? Icon(Icons.check_circle_rounded, color: _logoGreen) : null,
                  onTap: () {
                    setState(() => _selectedMethod = method['title'] as String);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ يجب تسجيل الدخول لإتمام الدفع', style: TextStyle(fontFamily: 'Cairo'))));
      return;
    }

    String? bookingId = widget.bookingId.isNotEmpty ? widget.bookingId : null;

    try {
      if (bookingId == null) {
        bookingId = await _findLatestBookingId(user.uid, widget.tripId);
      }

      if (bookingId != null) {
        double amount = _amount;
        if (amount <= 0) {
          final bookingSnap = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
          if (bookingSnap.exists) {
            final data = bookingSnap.data() as Map<String, dynamic>? ?? {};
            final tp = data['totalPrice'] ?? data['amountPaid'] ?? data['price'];
            if (tp is num) amount = tp.toDouble();
            else if (tp is String) amount = double.tryParse(tp) ?? 0.0;
          }
        }

        final PaymentResult result = await _paymentService.processPayment(
          bookingId: bookingId,
          amount: amount,
          paymentMethod: _selectedMethod,
        );

        if (!result.success) {
          if (!mounted) return;
          setState(() {
            _errorMessage = result.message ?? 'فشل في معالجة الدفع';
            _isProcessing = false;
          });
          return;
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentConfirmationScreen(
              bookingId: bookingId!,
              transactionId: result.transactionId ?? 'TRX-${DateTime.now().millisecondsSinceEpoch}',
              amount: result.amount ?? amount,
              paymentMethod: _selectedMethod,
            ),
          ),
        );
        return;
      } else {
        final newBookingRef = await FirebaseFirestore.instance.collection('bookings').add({
          'tripId': widget.tripId,
          'passengerId': user.uid,
          'seatNumber': widget.seatNumber,
          'bookedSeatsCount': 1,
          'bookingStatus': 'confirmed',
          'paymentStatus': 'paid',
          'paymentMethod': _selectedMethod,
          'paidAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        bookingId = newBookingRef.id;

        final confirmResult = await _paymentService.confirmPayment(
          bookingId: bookingId,
          transactionId: 'manual-${DateTime.now().millisecondsSinceEpoch}',
          amount: _amount,
          paymentMethod: _selectedMethod,
        );

        if (!confirmResult.success) {
          if (!mounted) return;
          setState(() {
            _errorMessage = confirmResult.message ?? 'فشل في تأكيد الدفع';
            _isProcessing = false;
          });
          return;
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentConfirmationScreen(
              bookingId: bookingId!,
              transactionId: confirmResult.transactionId ?? '',
              amount: confirmResult.amount ?? _amount,
              paymentMethod: _selectedMethod,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = 'حدث خطأ أثناء معالجة الدفع. حاول مرة أخرى.'; });
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<String?> _findLatestBookingId(String uid, String tripId) async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('bookings')
          .where('tripId', isEqualTo: tripId)
          .where('passengerId', isEqualTo: uid)
          .where('bookingStatus', whereIn: ['confirmed', 'مؤكد'])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) return q.docs.first.id;
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('تأكيد الحجز والدفع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long_rounded, color: _logoBlue, size: 20),
                              const SizedBox(width: 8),
                              const Text('ملخص بيانات الرحلة والمقعد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const Divider(height: 24),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.grid_3x3_rounded, color: _logoTeal),
                            title: const Text('رقم الرحلة المرجعي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                            subtitle: Text(widget.tripId, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.airline_seat_recline_normal_rounded, color: _logoTeal),
                                  title: const Text('المقعد المحجوز', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                                  subtitle: Text('مقعد رقم ${widget.seatNumber}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Expanded(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.payments_rounded, color: _logoGreen),
                                  title: const Text('المبلغ الإجمالي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                                  subtitle: Text(_formatCurrency(_amount), style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: _logoGreen)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // كرت تفعيل واختيار طرق الدفع عبر قائمة سفلية
                  InkWell(
                    onTap: _showPaymentMethodsBottomSheet,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _logoBlue.withOpacity(0.3), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.payment_rounded, color: _logoBlue),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('طريقة الدفع المحددة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                                  Text(_selectedMethod, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                ],
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_drop_down_circle_rounded, color: _logoBlue, size: 22),
                        ],
                      ),
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMessage!, style: const TextStyle(fontFamily: 'Cairo', color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),

            // حاوية ثابتة سفلية للأزرار التفاعلية الرئيسية لضمان عدم التداخل بصرياً
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _confirmPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _logoBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('تأكيد الحجز وإصدار السند', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                    child: const Text('إلغاء العملية والعودة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}