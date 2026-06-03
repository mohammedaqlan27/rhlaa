// lib/screens/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/notification_service.dart';
import '../services/payment_service.dart';
import 'payment_confirmation_screen.dart'; // شاشة جديدة لعرض التأكيد/الفاتورة

class PaymentScreen extends StatefulWidget {
  final String tripId;
  final int seatNumber;
  final String bookingId;

  const PaymentScreen({
    super.key,
    required this.tripId,
    required this.seatNumber,
    required this.bookingId,
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

  final List<String> _methods = [
    'نقداً عند اللقاء',
    'بطاقة إلكترونية (غير مفعّل حالياً)',
    'تحويل عبر تطبيق خارجي (Deep Link / QR)',
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
    if (value % 1 == 0) {
      return '${value.toStringAsFixed(0)} ريال';
    }
    return '${value.toStringAsFixed(2)} ريال';
  }

  Future<void> _confirmPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ يجب تسجيل الدخول لإتمام الدفع')),
      );
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

        // استدعاء PaymentService الذي يعيد PaymentResult
        final PaymentResult result = await _paymentService.processPayment(
          bookingId: bookingId,
          amount: amount,
          paymentMethod: _selectedMethod,
        );

        if (!result.success) {
          // فشل الدفع — نعرض رسالة للمستخدم
          if (!mounted) return;
          setState(() {
            _errorMessage = result.message ?? 'فشل في معالجة الدفع';
            _isProcessing = false;
          });
          return;
        }

        // نجاح الدفع — ننتقل إلى شاشة التأكيد مع بيانات المعاملة
        if (!mounted) return;
        setState(() => _isProcessing = false);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentConfirmationScreen(
              bookingId: bookingId!,
              transactionId: result.transactionId ?? '',
              amount: result.amount ?? amount,
              paymentMethod: _selectedMethod,
            ),
          ),
        );
        return;
      } else {
        // لم نعثر على حجز سابق: أنشئ حجزًا مؤقتًا بصيغة camelCase فقط ثم اعتبره مدفوعًا
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

        // نستخدم confirmPayment لتحديث السجل (محاكاة)
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
        setState(() => _isProcessing = false);
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
    } catch (e, st) {
      debugPrint('PaymentScreen._confirmPayment error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'حدث خطأ أثناء معالجة الدفع. حاول مرة أخرى.';
      });
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
    } catch (e, st) {
      debugPrint('PaymentScreen._findLatestBookingId error: $e\n$st');
    }
    return null;
  }

  Future<void> _showConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('تأكيد الدفع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('طريقة الدفع: $_selectedMethod'),
              const SizedBox(height: 8),
              Text('المبلغ: ${_formatCurrency(_amount)}'),
              const SizedBox(height: 8),
              Text('رقم المقعد: ${widget.seatNumber}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _confirmPayment();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدفع وتأكيد الحجز'),
        backgroundColor: theme.colorScheme.primary,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('تفاصيل الحجز', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.confirmation_number, color: theme.colorScheme.secondary),
                    title: Text('رقم الرحلة: ${widget.tripId}', style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.event_seat, color: theme.colorScheme.secondary),
                    title: Text('رقم المقعد: ${widget.seatNumber}', style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.attach_money, color: theme.colorScheme.secondary),
                    title: Text('المبلغ المتوقع: ${_formatCurrency(_amount)}', style: theme.textTheme.bodyMedium),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 14),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('اختر طريقة الدفع', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._methods.map((m) {
                    return RadioListTile<String>(
                      value: m,
                      groupValue: _selectedMethod,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedMethod = v);
                      },
                      title: Text(m),
                      activeColor: theme.colorScheme.primary,
                      secondary: Icon(
                        m.contains('نقد') ? Icons.money : Icons.credit_card,
                        color: theme.colorScheme.secondary,
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ]),
              ),
            ),

            const SizedBox(height: 18),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
              ),

            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _showConfirmDialog,
              icon: _isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle),
              label: Text(_isProcessing ? 'جاري المعالجة...' : 'ادفع واحجز', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 10),

            TextButton.icon(
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.cancel),
              label: const Text('إلغاء'),
            ),

            const SizedBox(height: 12),

            Text(
              'ملاحظة: طريقة الدفع الإلكترونية غير مفعّلة حالياً. سيتم توجيهك لبوابة الدفع عند تفعيلها.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
