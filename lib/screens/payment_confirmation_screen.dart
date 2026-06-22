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
    // ألوان وثيمات رحلاء الموحدة
    final Color logoBlue = const Color(0xFF1E70B8);
    final Color logoTeal = const Color(0xFF17A5A3);
    final Color logoGreen = const Color(0xFF4EBF64);
    final Color backgroundColor = const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('سند الدفع الرقمي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: logoBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // بطاقة السند المالي الرقمي الشبيهة بالتذكرة
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          width: double.infinity,
                          color: logoGreen.withOpacity(0.08),
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 54, color: logoGreen),
                              const SizedBox(height: 10),
                              Text('تم تأكيد الدفع والطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: logoGreen)),
                              const SizedBox(height: 4),
                              Text('تطبيق رحلاء - رحلتك أصبحت مضمونة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              _buildReceiptRow('رقم الحجز الآلي', bookingId, Icons.bookmark_border_rounded, logoBlue),
                              _buildReceiptRow('رقم عملية التحويل', transactionId, Icons.receipt_long_rounded, logoTeal),
                              _buildReceiptRow('طريقة السداد', paymentMethod, Icons.payment_rounded, logoTeal),
                              const Divider(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('المبلغ الإجمالي المدفوع:', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text('${amount.toStringAsFixed(0)} ر.ي', style: TextStyle(fontFamily: 'Cairo', color: logoGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'يرجى إبراز هذا السند الرقمي للكابتن عند الطلب أو اللقاء.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // أزرار التحكم والرجوع الثابتة في الأسفل
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري إعداد نسخة PDF وتجهيز الحفظ...', style: TextStyle(fontFamily: 'Cairo'))));
                },
                icon: const Icon(Icons.file_download_rounded),
                label: const Text('حفظ السند كصورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: logoBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: Text('العودة للرئيسية وتصفح التطبيق', style: TextStyle(fontFamily: 'Cairo', color: logoBlue, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}