// lib/services/notification_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'notifications';

  NotificationService();

  /// إرسال إشعار جديد للمستخدم
  /// الحقول المحفوظة في Firestore تتطابق مع AppNotification.toMap()
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final data = <String, dynamic>{
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'metadata': metadata,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(collectionName).add(data);
    } catch (e, st) {
      debugPrint('NotificationService.sendNotification error: $e\n$st');
      rethrow;
    }
  }

  /// جلب إشعارات المستخدم لمرة واحدة (غير متدفقة)
  Future<List<AppNotification>> getNotificationsOnce({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final q = await _firestore
          .collection(collectionName)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return q.docs.map((d) {
        try {
          return AppNotification.fromDocument(d);
        } catch (e) {
          debugPrint('NotificationService.getNotificationsOnce parse error: $e');
          return null;
        }
      }).whereType<AppNotification>().toList();
    } catch (e, st) {
      debugPrint('NotificationService.getNotificationsOnce error: $e\n$st');
      rethrow;
    }
  }

  /// بث إشعارات المستخدم (Stream) مع دعم الإلغاء الآمن للاشتراك
  Stream<List<AppNotification>> streamNotificationsForUser(String userId, {int limit = 100}) {
    final stream = _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();

    final controller = StreamController<List<AppNotification>>.broadcast();
    StreamSubscription<QuerySnapshot>? sub;

    sub = stream.listen((snap) {
      try {
        final list = snap.docs.map((d) {
          try {
            return AppNotification.fromDocument(d);
          } catch (err) {
            debugPrint('NotificationService.stream parse error: $err');
            return null;
          }
        }).whereType<AppNotification>().toList();

        controller.add(list);
      } catch (e) {
        debugPrint('NotificationService.stream processing error: $e');
      }
    }, onError: (e) {
      debugPrint('NotificationService.stream error: $e');
      controller.addError(e);
    });

    controller.onCancel = () async {
      await sub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// وضع علامة مقروء على إشعار واحد وتحديث updatedAt
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(collectionName).doc(notificationId).update({
        'isRead': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('NotificationService.markAsRead error: $e\n$st');
      rethrow;
    }
  }

  /// وضع علامة مقروء على مجموعة إشعارات دفعة واحدة
  Future<void> markAsReadBatch(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    final batch = _firestore.batch();
    try {
      for (final id in notificationIds) {
        final ref = _firestore.collection(collectionName).doc(id);
        batch.update(ref, {'isRead': true, 'updatedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
    } catch (e, st) {
      debugPrint('NotificationService.markAsReadBatch error: $e\n$st');
      rethrow;
    }
  }

  /// حذف إشعار
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection(collectionName).doc(notificationId).delete();
    } catch (e, st) {
      debugPrint('NotificationService.deleteNotification error: $e\n$st');
      rethrow;
    }
  }

  /// عدّ الإشعارات غير المقروءة للمستخدم
  Future<int> getUnreadCount(String userId) async {
    try {
      final q = await _firestore
          .collection(collectionName)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return q.docs.length;
    } catch (e, st) {
      debugPrint('NotificationService.getUnreadCount error: $e\n$st');
      return 0;
    }
  }
}
