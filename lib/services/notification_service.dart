import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'notifications';

  NotificationService();

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final data = <String, dynamic>{
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'metadata': metadata,
      };

      await _firestore.collection(collectionName).add(data);
    } catch (e, st) {
      debugPrint('NotificationService.sendNotification error: $e\n$st');
      rethrow;
    }
  }

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
          return null;
        }
      }).whereType<AppNotification>().toList();
    } catch (e, st) {
      debugPrint('NotificationService.getNotificationsOnce error: $e\n$st');
      rethrow;
    }
  }

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
            return null;
          }
        }).whereType<AppNotification>().toList();

        controller.add(list);
      } catch (_) {}
    }, onError: (e) {
      debugPrint('NotificationService.stream error: $e');
    });

    controller.onCancel = () async {
      await sub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(collectionName).doc(notificationId).update({
        'isRead': true,
      });
    } catch (e, st) {
      debugPrint('NotificationService.markAsRead error: $e\n$st');
      rethrow;
    }
  }

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

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection(collectionName).doc(notificationId).delete();
    } catch (e, st) {
      debugPrint('NotificationService.deleteNotification error: $e\n$st');
      rethrow;
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final q = await _firestore
          .collection(collectionName)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return q.docs.length;
    } catch (e) {
      return 0;
    }
  }
}