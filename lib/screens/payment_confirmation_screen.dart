// lib/screens/payment_confirmation_screen.dart
import 'package:flutter/material.dart';

class PaymentConfirmationScreen extends StatelessWidget {
  final String bookingId;
  final String transactionId;
  final double amount;
  final String paymentMethod;

  const PaymentConfirmationScreen({
    super.key,
    required this.bookingId,
    required this.transactionId,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد الدفع'), backgroundColor: theme.colorScheme.primary),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('تم تأكيد الدفع بنجاح', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('رقم الحجز: $bookingId', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text('رقم المعاملة: $transactionId', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text('المبلغ: ${amount.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text('طريقة الدفع: $paymentMethod', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عرض الفاتورة (تجريبي)')));
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('عرض الفاتورة'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('العودة إلى الصفحة الرئيسية'),
          ),
        ]),
      ),
    );
  }
}
