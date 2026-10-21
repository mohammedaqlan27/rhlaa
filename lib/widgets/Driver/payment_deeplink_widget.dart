// lib/widgets/payment_deeplink_widget.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart'; // تأكد من إضافة الحزمة في pubspec.yaml
import '../../services/payment_service.dart';
import '../../theme/app_colors.dart';
import '../shared/app_card.dart';
import '../shared/custom_button.dart';

class PaymentDeepLinkWidget extends StatelessWidget {
  final String bookingId;
  final double amount;
  final String paymentMethod;
  final String callbackUrl;
  final String schemeHost;
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

  // دالة لفتح الرابط في التطبيق الخارجي
  Future<void> _launchPaymentApp(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على تطبيق دفع متوافق')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final payload = paymentService.buildDeepLinkPayload(
      bookingId: bookingId,
      amount: amount,
      paymentMethod: paymentMethod,
      callbackUrl: callbackUrl,
    );
    final uri = paymentService.buildDeepLinkUri(schemeHost: schemeHost, payload: payload);

    return AppCard(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // الرأس: عنوان الدفع وشعار الأمان
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الدفع السريع',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'عبر تطبيقات التحويل',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.security_rounded, color: AppColors.success, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // منطقة الـ QR Code بتصميم عصري
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: QrImageView(
              data: uri,
              version: QrVersions.auto,
              size: 180.0,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.primary,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'امسح الكود للدفع الفوري',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),

          const SizedBox(height: 24),

          // أزرار الأكشن
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: uri));
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(behavior: SnackBarBehavior.floating, content: Text('تم نسخ رابط الدفع')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('نسخ الرابط'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchPaymentApp(context, uri),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('فتح التطبيق'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // تعليمات الدفع بشكل أيقونات (UX Steps)
          _buildStep(Icons.qr_code_scanner_rounded, 'افتح تطبيق التحويل وامسح الرمز'),
          const SizedBox(height: 12),
          _buildStep(Icons.account_balance_wallet_rounded, 'أكد المبلغ وبيانات المستلم'),
          const SizedBox(height: 12),
          _buildStep(Icons.verified_user_rounded, 'سيتم تحديث حالة الحجز تلقائياً بعد الدفع'),
        ],
      ),
    );
  }

  Widget _buildStep(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }
}