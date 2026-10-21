import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'app_card.dart';

enum TrendDirection { up, down, neutral }

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final String? subtitle;
  final String? percentageChange;
  final TrendDirection trend;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.subtitle,
    this.percentageChange,
    this.trend = TrendDirection.neutral,
    this.onTap,
  }); // تم حذف required Color color لأنه غير مستخدم

  Color _getTrendColor() {
    switch (trend) {
      case TrendDirection.up:
        return AppColors.success;
      case TrendDirection.down:
        return AppColors.error;
      case TrendDirection.neutral:
        return AppColors.gray500;
    }
  }

  IconData _getTrendIcon() {
    switch (trend) {
      case TrendDirection.up:
        return Icons.trending_up_rounded;
      case TrendDirection.down:
        return Icons.trending_down_rounded;
      case TrendDirection.neutral:
        return Icons.remove_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryIconColor = iconColor ?? AppColors.primary;
    final bgIconColor = iconBackgroundColor ?? primaryIconColor.withValues(alpha: 0.12);

    return AppCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Icon & Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgIconColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: primaryIconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.arabic,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.gray400 : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Main Value
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.arabic,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Subtitle or Percentage Indicator (Optional)
          if (percentageChange != null || subtitle != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (percentageChange != null) ...[
                  Icon(
                    _getTrendIcon(),
                    size: 16,
                    color: _getTrendColor(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    percentageChange!,
                    style: TextStyle(
                      fontFamily: AppFonts.arabic,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getTrendColor(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (subtitle != null)
                  Expanded(
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: AppFonts.arabic,
                        fontSize: 11,
                        color: isDark ? AppColors.gray500 : AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}