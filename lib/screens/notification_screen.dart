// lib/screens/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'notification_settings_screen.dart'; // إضافة هذا المسار
import'notification_detail_screen.dart';
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationSettings {
  static const Color primaryBlue = Color(0xFF1E70B8);
  static const Color background = Color(0xFFF8FAFC);
  static const Color unreadBg = Color(0xFFEFF6FF);
  static const String font = 'Cairo';
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _service = NotificationService();

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  IconData _getIconByType(String type) {
    switch (type) {
      case 'booking': return Icons.calendar_today_rounded;
      case 'payment': return Icons.account_balance_wallet_rounded;
      case 'safety': return Icons.gpp_maybe_rounded;
      case 'promo': return Icons.local_offer_rounded;
      case 'arrived': return Icons.location_on_rounded;
      default: return Icons.notifications_active_rounded;
    }
  }

  Color _getColorByType(String type) {
    switch (type) {
      case 'safety': return Colors.redAccent;
      case 'payment': return Colors.green;
      case 'promo': return Colors.orange;
      default: return _NotificationSettings.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _NotificationSettings.background,
        appBar: _buildAppBar(context),
        body: _userId == null ? _buildLoginRequired() : _buildNotificationList(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        'مركز الإشعارات',
        style: TextStyle(
          fontFamily: _NotificationSettings.font,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0.5,
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.done_all_rounded, color: _NotificationSettings.primaryBlue),
          tooltip: 'تحديد الكل كمقروء',
          onPressed: () async {
            if (_userId == null) return;
            try {
              final notifications = await _service.getNotificationsOnce(userId: _userId!);
              final unreadIds = notifications.where((n) => !n.isRead).map((n) => n.id).toList();
              if (unreadIds.isNotEmpty) {
                await _service.markAsReadBatch(unreadIds);
              }
            } catch (e) {
              debugPrint('Error marking all as read: $e');
            }
          },
        ),
      ],
    );
  }

  Widget _buildLoginRequired() {
    return const Center(
      child: Text('يرجى تسجيل الدخول لعرض الإشعارات',
          style: TextStyle(fontFamily: _NotificationSettings.font)),
    );
  }

  Widget _buildNotificationList() {
    return StreamBuilder<List<AppNotification>>(
      stream: _service.streamNotifications(_userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _NotificationSettings.primaryBlue));
        }

        if (snapshot.hasError) {
          return const Center(child: Text('حدث خطأ أثناء تحميل البيانات'));
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            return _buildNotificationItem(notifications[index]);
          },
        );
      },
    );
  }

  Widget _buildNotificationItem(AppNotification n) {
    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 30),
      ),
      onDismissed: (_) => _service.deleteNotification(n.id),
      child: InkWell(
        onTap: () {
          if (!n.isRead) _service.markAsRead(n.id);
          // هنا يمكنك إضافة Navigator بناءً على n.type أو n.metadata
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: n.isRead ? Colors.white : _NotificationSettings.unreadBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: n.isRead ? Colors.black12 : _NotificationSettings.primaryBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getColorByType(n.type).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getIconByType(n.type), color: _getColorByType(n.type), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            n.title,
                            style: TextStyle(
                              fontFamily: _NotificationSettings.font,
                              fontSize: 14,
                              fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                              color: n.isRead ? Colors.black87 : _NotificationSettings.primaryBlue,
                            ),
                          ),
                          if (!n.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: _NotificationSettings.primaryBlue, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.body,
                        style: const TextStyle(
                          fontFamily: _NotificationSettings.font,
                          fontSize: 13,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        n.createdAt != null ? timeago.format(n.createdAt!.toDate(), locale: 'ar') : '',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'لا توجد إشعارات حالياً',
            style: TextStyle(
              fontFamily: _NotificationSettings.font,
              fontSize: 18,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}