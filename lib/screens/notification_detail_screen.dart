// lib/screens/notification_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/notification_model.dart';

class NotificationDetailScreen extends StatelessWidget {
  final AppNotification notification;
  const NotificationDetailScreen({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الإشعار', style: TextStyle(fontFamily: 'Cairo')),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(notification.body, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
              const SizedBox(height: 16),
              if (notification.metadata != null)
                Text('بيانات إضافية: ${notification.metadata}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54)),
              if (notification.actionUrl != null)
                TextButton(
                  onPressed: () {
                    // هنا يمكنك تنفيذ التنقل إلى شاشة معينة أو فتح رابط
                    Navigator.pop(context);
                  },
                  child: const Text('فتح الرابط', style: TextStyle(fontFamily: 'Cairo')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
