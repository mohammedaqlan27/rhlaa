import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart'; // استدعاء الألوان والخطوط من AppColors

/// 🕌 TravelPrayerCard: بطاقة دعاء السفر متكاملة مع AppColors والثيم
class TravelPrayerCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double maxWidth;

  const TravelPrayerCard({
    super.key,
    required this.title,
    required this.content,
    this.icon = Icons.auto_stories,
    this.color = AppColors.warning, // الافتراضي من AppColors
    this.onTap,
    this.maxWidth = 320,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ألوان ديناميكية من AppColors
    final primaryColor = isDark ? AppColors.backgroundDark : AppColors.primary;
    final textColor = isDark ? AppColors.textPrimary : Colors.white;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor,
                    primaryColor.withOpacity(0.85),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(
                        Icons.mosque_rounded,
                        size: 140,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, color: color, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppFonts.arabic,
                                      color: textColor.withOpacity(0.95),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(icon, color: color, size: 20),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              content,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: AppFonts.arabic,
                                color: textColor,
                                fontSize: 15,
                                height: 1.7,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _ActionButton(
                                  tooltip: 'نسخ النص',
                                  icon: Icons.copy_rounded,
                                  label: 'نسخ',
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: content));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('تم نسخ الدعاء')),
                                    );
                                  },
                                ),
                                _ActionButton(
                                  tooltip: 'مشاركة النص',
                                  icon: Icons.share_outlined,
                                  label: 'مشاركة',
                                  onPressed: () {
                                    Share.share(content, subject: title);
                                  },
                                ),
                                _ActionButton(
                                  tooltip: 'آمين',
                                  icon: Icons.check_circle_outline,
                                  label: 'آمين',
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('آمين')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 🔘 زر تفاعل داخلي
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = isDark ? AppColors.surfaceDark.withOpacity(0.18) : Colors.white.withOpacity(0.12);

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: tooltip.isEmpty ? label : tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: buttonColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.arabic,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
