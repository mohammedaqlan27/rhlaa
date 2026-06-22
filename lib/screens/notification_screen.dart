// lib/screens/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import '../widgets/app_card.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _baseBg = Color(0xFFF1F5F9);

  String? _currentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUserId();
    final service = NotificationService();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _baseBg,
        appBar: AppBar(
          title: const Text('مركز الإشعارات', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: _baseBg,
          foregroundColor: _logoBlue,
          elevation: 0,
          centerTitle: true,
        ),
        body: userId == null
            ? const Center(child: Text('يرجى تسجيل الدخول لعرض الإشعارات', style: TextStyle(fontFamily: 'Cairo')))
            : StreamBuilder<List<AppNotification>>(
          stream: service.streamNotificationsForUser(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_logoBlue)));
            }
            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ أثناء تحميل الإشعارات', style: const TextStyle(fontFamily: 'Cairo')));
            }
            final notifications = snapshot.data ?? [];
            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 64, color: _logoBlue.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    const Text('صندوق الإشعارات فارغ حالياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.black54)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _baseBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: n.isRead
                        ? [
                      BoxShadow(color: const Color(0xFFCBD5E1).withOpacity(0.5), blurRadius: 6, offset: const Offset(3, 3)),
                      const BoxShadow(color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
                    ]
                        : [
                      // تمييز الإشعار غير المقروء بظلال اللوجو الزرقاء الناعمة
                      BoxShadow(color: _logoBlue.withOpacity(0.15), blurRadius: 8, offset: const Offset(2, 4)),
                      const BoxShadow(color: Colors.white, blurRadius: 8, offset: Offset(-2, -4)),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                        n.title,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold, color: n.isRead ? Colors.black87 : _logoBlue)
                    ),
                    subtitle: Text(n.body, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54)),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.black45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) async {
                        try {
                          if (value == 'read') {
                            await service.markAsRead(n.id);
                          } else if (value == 'delete') {
                            await service.deleteNotification(n.id);
                          }
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))));
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'read', child: Text('وضع كمقروء', style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
                        const PopupMenuItem(value: 'delete', child: Text('حذف الإشعار', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.redAccent))),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}