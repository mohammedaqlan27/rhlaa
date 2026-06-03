// lib/screens/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  String? _currentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUserId();
    final service = NotificationService();

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الإشعارات')),
        body: const Center(child: Text('يرجى تسجيل الدخول لعرض الإشعارات')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: StreamBuilder<List<AppNotification>>(
        stream: service.streamNotificationsForUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('NotificationScreen stream error: ${snapshot.error}');
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(child: Text('لا توجد إشعارات'));
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return ListTile(
                tileColor: n.isRead ? null : Colors.blue.withOpacity(0.05),
                title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text(n.body),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    try {
                      if (value == 'read') {
                        await service.markAsRead(n.id);
                      } else if (value == 'delete') {
                        await service.deleteNotification(n.id);
                      }
                    } catch (e) {
                      debugPrint('NotificationScreen.action error: $e');
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'read', child: Text('وضع كمقروء')),
                    PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
                onTap: () async {
                  if (!n.isRead) {
                    try {
                      await service.markAsRead(n.id);
                    } catch (e) {
                      debugPrint('NotificationScreen.markAsRead error: $e');
                    }
                  }
                  // يمكن إضافة تنقّل حسب نوع الإشعار هنا
                },
              );
            },
          );
        },
      ),
    );
  }
}
