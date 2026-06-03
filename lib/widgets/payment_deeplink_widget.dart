// lib/widgets/payment_deeplink_widget.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import '../services/payment_service.dart';

class PaymentDeepLinkWidget extends StatelessWidget {
  final String bookingId;
  final double amount;
  final String paymentMethod;
  final String callbackUrl; // مثال: myapp://payment-callback
  final String schemeHost; // مثال: 'yemenpay://pay'
  final PaymentService paymentService;

  const PaymentDeepLinkWidget({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.paymentMethod,
    required this.callbackUrl,
    required this.schemeHost,
    required this.paymentService,
  });

  @override
  Widget build(BuildContext context) {
    final payload = paymentService.buildDeepLinkPayload(
      bookingId: bookingId,
      amount: amount,
      paymentMethod: paymentMethod,
      callbackUrl: callbackUrl,
    );
    final uri = paymentService.buildDeepLinkUri(schemeHost: schemeHost, payload: payload);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ادفع عبر تطبيق تحويل خارجي', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('امسح الرمز أو افتح الرابط في تطبيق التحويل:', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data: uri,
                version: QrVersions.auto,
                size: 200.0,
                gapless: false,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(uri, maxLines: 3, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('نسخ الرابط'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: uri));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرابط')));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('فتح (إن وُجد)'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('افتح الرابط في تطبيق التحويل أو امسح QR')));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'تعليمات: افتح تطبيق التحويل، اختر مسح QR أو افتح الرابط، أدخل المبلغ إن طُلب، ثم أكّد الدفع. بعد الدفع سيعود المستخدم تلقائيًا أو يُرسل المزود webhook لتأكيد الدفع.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
