import 'package:flutter/material.dart';
import 'package:rhlaa/theme/app_colors.dart'; // أو المسار النسبي الصحيح مثل import '../../theme/app_colors.dart';
class AdminHeader extends StatelessWidget {
  final String title;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;
  final int unreadNotificationsCount;

  const AdminHeader({
    super.key,
    required this.title,
    required this.onNotificationTap,
    required this.onProfileTap,
    this.unreadNotificationsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.gray700 : AppColors.gray200, // تم تصحيح اللون للوضع الداكن ليصبح متناسقاً
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // عنوان الصفحة الحالية
          Text(
            title,
            style: TextStyle(
              fontFamily: AppFonts.arabic,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const Spacer(),

          // زر الإشعارات مع مؤشر التنبيهات
          Stack(
            children: [
              IconButton(
                onPressed: onNotificationTap,
                icon: Icon(
                  Icons.notifications_outlined,
                  color: isDark ? AppColors.gray400 : AppColors.textSecondary,
                ),
                tooltip: 'الإشعارات',
              ),
              if (unreadNotificationsCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$unreadNotificationsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // ملف المدير الشخصي
          InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(30),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=admin'),
                ),
                const SizedBox(width: 10),
                Text(
                  'مدير النظام',
                  style: TextStyle(
                    fontFamily: AppFonts.arabic,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isDark ? AppColors.gray400 : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}