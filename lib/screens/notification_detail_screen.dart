// lib/screens/notification_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../widgets/shared/custom_button.dart';
import '../widgets/Passenger/travel_prayer_card.dart'; // تم تفعيل استخدامه الآن
import 'package:timeago/timeago.dart' as timeago;

class NotificationDetailScreen extends StatelessWidget {
  final AppNotification notification;

  const NotificationDetailScreen({super.key, required this.notification, required String notificationId});

  // إعدادات التصميم الثابتة
  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _scaffoldBg = Color(0xFFF8FAFC);
  static const String _fontCairo = 'Cairo';

  // دالة ذكية لتحديد الأيقونة واللون بناءً على نوع الإشعار
  Map<String, dynamic> _getStyleByType(String type) {
    switch (type) {
      case 'safety':
        return {'icon': Icons.gpp_maybe_rounded, 'color': Colors.redAccent};
      case 'payment':
        return {'icon': Icons.account_balance_wallet_rounded, 'color': Colors.green};
      case 'booking':
        return {'icon': Icons.calendar_today_rounded, 'color': _primaryBlue};
      case 'promo':
        return {'icon': Icons.local_offer_rounded, 'color': Colors.orange};
      case 'trip_started': // حالة خاصة لبدء الرحلة
        return {'icon': Icons.map_rounded, 'color': _primaryBlue};
      default:
        return {'icon': Icons.notifications_active_rounded, 'color': _primaryBlue};
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _getStyleByType(notification.type);
    final Color themeColor = style['color'];

    // فحص ذكي: هل هذا الإشعار يخص بداية الرحلة؟
    // نتحقق من النوع أو وجود كلمات دلالية في العنوان
    final bool isTripStartNotification =
        notification.type == 'trip_started' ||
            notification.title.contains('انطلقت الرحلة') ||
            notification.body.contains('دعاء السفر');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'تفاصيل التنبيه',
            style: TextStyle(fontFamily: _fontCairo, color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // 1. أيقونة النوع مع أنيميشن دخول
                Center(
                  child: TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(style['icon'], size: 60, color: themeColor),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
                // 2. بطاقة المحتوى الرئيسية
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Text(
                            notification.createdAt != null
                                ? timeago.format(notification.createdAt!.toDate(), locale: 'ar')
                                : 'الآن',
                            style: TextStyle(fontFamily: _fontCairo, fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontFamily: _fontCairo,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const Divider(height: 32, thickness: 0.5),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          fontFamily: _fontCairo,
                          fontSize: 15,
                          color: Colors.black54,
                          height: 1.8,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- [إضافة احترافية] زر دعاء السفر يظهر فقط عند الحاجة ---
                if (isTripStartNotification) ...[
                  CustomButton(
                    text: 'قراءة دعاء السفر',
                    icon: Icons.auto_awesome_rounded,
                    backgroundColor: const Color(0xFFD4AF37), // لون ذهبي ملكي
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) => const TravelPrayerCard(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. قسم البيانات الإضافية (Metadata)
                if (notification.metadata != null && notification.metadata!.isNotEmpty)
                  _buildMetadataSection(notification.metadata!),

                const SizedBox(height: 32),

                // 4. أزرار الإجراءات النهائية
                if (notification.actionUrl != null)
                  CustomButton(
                    text: 'فتح الرابط أو الإجراء',
                    icon: Icons.launch_rounded,
                    onPressed: () {
                      // منطق التنقل بناءً على الرابط
                      Navigator.pop(context);
                    },
                  ),

                const SizedBox(height: 12),

                CustomButton(
                  text: 'إغلاق',
                  backgroundColor: Colors.transparent,
                  textColor: Colors.grey.shade600,
                  border: Border.all(color: Colors.grey.shade300),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataSection(Map<String, dynamic> metadata) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'معلومات إضافية',
            style: TextStyle(fontFamily: _fontCairo, fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey),
          ),
          const SizedBox(height: 12),
          ...metadata.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key, style: const TextStyle(fontFamily: _fontCairo, fontSize: 13, color: Colors.black45)),
                Text(entry.value.toString(), style: const TextStyle(fontFamily: _fontCairo, fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}