import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class NotificationBell extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const NotificationBell({super.key, this.count = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: onTap,
          tooltip: 'الإشعارات',
        ),
        if (count > 0)
          Positioned.directional(
            textDirection: Directionality.of(context),
            end: 6,
            top: 6,
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
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}