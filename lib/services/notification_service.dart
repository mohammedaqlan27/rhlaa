// lib/services/notification_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'notifications';

  NotificationService();

  /// إرسال إشعار وكتابة المستند في Firestore
  /// يكتب الحقول بصيغة camelCase فقط
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final now = FieldValue.serverTimestamp();
      final data = <String, dynamic>{
        // camelCase only
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'createdAt': now,
        'isRead': false,
        'metadata': metadata,
      };

      await _firestore.collection(collectionName).add(data);
    } catch (e, st) {
      debugPrint('NotificationService.sendNotification error: $e\n$st');
      rethrow;
    }
  }

  /// جلب إشعارات لمرة واحدة (غير متدفقة)
  /// يستخدم camelCase فقط
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

  /// تيار موحّد يجلب إشعارات للمستخدم (camelCase)
  /// يعيد Stream<List<AppNotification>> مدمجًا ومُرتبًا حسب createdAt (الأحدث أولاً)
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
            debugPrint('NotificationService.parse doc error: $err');
            return null;
          }
        }).whereType<AppNotification>().toList();

        // already ordered by createdAt descending from query
        controller.add(list);
      } catch (e) {
        debugPrint('NotificationService.controller.add error: $e');
      }
    }, onError: (e, st) {
      debugPrint('NotificationService.stream error: $e\n$st');
    });

    controller.onCancel = () async {
      try {
        await sub?.cancel();
      } catch (e) {
        debugPrint('NotificationService.cancel sub error: $e');
      }
      try {
        await controller.close();
      } catch (e) {
        debugPrint('NotificationService.controller.close error: $e');
      }
    };

    return controller.stream;
  }

  /// تعليم إشعار كمقروء (camelCase only)
  Future<void> markAsRead(String notificationId) async {
    final docRef = _firestore.collection(collectionName).doc(notificationId);
    try {
      await docRef.update({
        'isRead': true,
      });
    } catch (e, st) {
      debugPrint('NotificationService.markAsRead error: $e\n$st');
      rethrow;
    }
  }

  /// تعليم مجموعة إشعارات كمقروءة في عملية واحدة (batch) - camelCase only
  Future<void> markAsReadBatch(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    final batch = _firestore.batch();
    try {
      for (final id in notificationIds) {
        final ref = _firestore.collection(collectionName).doc(id);
        batch.update(ref, {'isRead': true});
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

  /// عدّ الإشعارات غير المقروءة للمستخدم (camelCase queries only)
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
