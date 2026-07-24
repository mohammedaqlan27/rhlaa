import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

class NotificationService {
  // حقن الاعتمادات
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  final String collectionName = 'notifications';
  final String scheduledCollection = 'scheduled_notifications';

  // Constructor مع قيم افتراضية لسهولة الاستخدام والقدرة على عمل Mocks
  NotificationService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  // -----------------------
  // Low-level: write notification doc
  // -----------------------
  Future<DocumentReference> _createNotificationDoc({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? metadata,
    String? actionUrl,
    String priority = 'normal',
    bool sendNotification = true,
    String? transactionId,
  }) async {
    final now = Timestamp.now();
    final data = <String, dynamic>{
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'metadata': metadata,
      'actionUrl': actionUrl,
      'priority': priority,
      'sendNotification': sendNotification,
      'transactionId': transactionId,
      'isRead': false,
      'createdAt': now,
      'updatedAt': now,
    }..removeWhere((k, v) => v == null);

    return await _firestore.collection(collectionName).add(data);
  }

  // -----------------------
  // Callable Cloud Function wrapper
  // -----------------------
  Future<void> _callSendNotificationFunction({
    required String notificationId,
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendNotificationToUser');
      await callable.call(<String, dynamic>{
        'notificationId': notificationId,
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
      });
    } catch (e, st) {
      debugPrint('NotificationService._callSendNotificationFunction error: $e\n$st');
    }
  }

  // -----------------------
  // Public: send notification
  // -----------------------
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? metadata,
    String? actionUrl,
    String priority = 'normal',
    bool sendPush = true,
    String? transactionId,
  }) async {
    try {
      final docRef = await _createNotificationDoc(
        userId: userId,
        title: title,
        body: body,
        type: type,
        metadata: metadata,
        actionUrl: actionUrl,
        priority: priority,
        sendNotification: sendPush,
        transactionId: transactionId,
      );

      if (sendPush) {
        await _callSendNotificationFunction(
          notificationId: docRef.id,
          userId: userId,
          title: title,
          body: body,
          data: metadata,
        );
      }
    } catch (e, st) {
      debugPrint('NotificationService.sendNotification error: $e\n$st');
      rethrow;
    }
  }

  // -----------------------
  // Schedule a notification
  // -----------------------
  Future<void> scheduleNotification({
    required String userId,
    required String title,
    required String body,
    required DateTime sendAt,
    String type = 'scheduled',
    Map<String, dynamic>? metadata,
    bool sendPush = true,
  }) async {
    final doc = <String, dynamic>{
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'metadata': metadata,
      'sendAt': Timestamp.fromDate(sendAt.toUtc()),
      'sendNotification': sendPush,
      'sent': false,
      'createdAt': Timestamp.now(),
    };
    await _firestore.collection(scheduledCollection).add(doc);
  }

  // -----------------------
  // Templates / helpers
  // -----------------------
  Future<void> sendBookingPendingPaymentReminder({
    required String userId,
    required String bookingId,
    bool sendPush = true,
  }) async {
    final title = 'تذكير بالدفع';
    final body = 'حجزك رقم $bookingId لم يتم دفعه بعد. أكمل الدفع لتأكيد مقعدك.';
    final metadata = {'screen': 'booking', 'bookingId': bookingId, 'action': 'pay'};
    await sendNotification(
      userId: userId,
      title: title,
      body: body,
      type: 'pending_payment',
      metadata: metadata,
      sendPush: sendPush,
    );
  }

  Future<void> schedulePreTripReminders({
    required String userId,
    required String tripId,
    required DateTime tripStart,
    List<int> hoursBefore = const [24, 3, 1],
  }) async {
    for (final h in hoursBefore) {
      final sendAt = tripStart.subtract(Duration(hours: h));
      if (sendAt.isAfter(DateTime.now())) {
        final title = 'تذكير بالرحلة';
        final body = 'رحلتك رقم $tripId تبدأ بعد $h ساعة. تأكد من الحضور.';
        final metadata = {'screen': 'trip', 'tripId': tripId};
        await scheduleNotification(
          userId: userId,
          title: title,
          body: body,
          sendAt: sendAt,
          type: 'pre_trip_reminder',
          metadata: metadata,
        );
      }
    }
  }

  Future<void> sendDriverOnTheWay({
    required String userId,
    required String driverName,
    required String plate,
    required String tripId,
  }) async {
    final title = 'السائق في الطريق';
    final body = 'السائق $driverName في الطريق. رقم المركبة $plate.';
    final metadata = {'screen': 'trip_live', 'tripId': tripId};
    await sendNotification(userId: userId, title: title, body: body, type: 'driver_on_the_way', metadata: metadata);
  }

  Future<void> sendDriverArrived({
    required String userId,
    required String tripId,
  }) async {
    final title = 'السائق وصل';
    final body = 'السائق وصل إلى نقطة الانطلاق. يرجى التوجه الآن.';
    final metadata = {'screen': 'trip_live', 'tripId': tripId};
    await sendNotification(userId: userId, title: title, body: body, type: 'driver_arrived', metadata: metadata);
  }

  Future<void> sendDriverDelayed({
    required String userId,
    required String tripId,
    required int minutes,
  }) async {
    final title = 'السائق متأخر';
    final body = 'السائق متوقع الوصول بعد $minutes دقيقة. نعتذر عن التأخير.';
    final metadata = {'screen': 'trip_live', 'tripId': tripId};
    await sendNotification(userId: userId, title: title, body: body, type: 'driver_delayed', metadata: metadata);
  }

  Future<void> sendTripStarted({
    required String userId,
    required String tripId,
    String? personalizedMessage,
  }) async {
    final title = 'بداية الرحلة';
    final body = personalizedMessage ?? 'انطلقت الرحلة الآن. نتمنى لكم رحلة آمنة ومريحة.';
    final metadata = {'screen': 'trip_live', 'tripId': tripId};
    await sendNotification(userId: userId, title: title, body: body, type: 'trip_started', metadata: metadata);
  }

  Future<void> sendMidTripEncouragement({
    required String userId,
    required String tripId,
  }) async {
    final title = 'نأمل أن تكون الرحلة مريحة';
    final body = 'نأمل أن تكون الرحلة مريحة — استمتع بالرحلة!';
    final metadata = {'screen': 'trip_live', 'tripId': tripId};
    await sendNotification(userId: userId, title: title, body: body, type: 'trip_mid_encourage', metadata: metadata);
  }

  Future<void> sendArrivedAndRequestRating({
    required String userId,
    required String tripId,
    String? bookingId,
  }) async {
    final title = 'تم الوصول';
    final body = 'وصلت إلى وجهتك. شكرًا لاستخدامك خدمتنا. نرجو تقييم السائق.';
    final metadata = {'screen': 'rating', 'tripId': tripId, 'bookingId': bookingId};
    await sendNotification(userId: userId, title: title, body: body, type: 'arrived', metadata: metadata);
    final sendAt = DateTime.now().add(Duration(minutes: 1));
    await scheduleNotification(
      userId: userId,
      title: 'كيف كانت رحلتك؟',
      body: 'ساعدنا بتحسين الخدمة — قيّم سائقك الآن.',
      sendAt: sendAt,
      type: 'request_rating',
      metadata: {'screen': 'rating', 'tripId': tripId, 'bookingId': bookingId},
    );
  }

  Future<void> sendSafetyAlert({
    required String userId,
    required String tripId,
    String? short,
  }) async {
    final title = 'تنبيه أمني';
    final body = short ?? 'تم استلام بلاغ أمني متعلق برحلتك. سنتواصل معك فورًا.';
    final metadata = {'screen': 'support', 'tripId': tripId};
    await sendNotification(userId: userId, title: title, body: body, type: 'safety_alert', metadata: metadata, priority: 'high');
  }

  Future<void> sendPromo({
    required String userId,
    required String code,
    required int percent,
  }) async {
    final title = 'عرض خاص لك';
    final body = 'خصم $percent% على رحلتك القادمة. استخدم الكود $code.';
    final metadata = {'screen': 'wallet', 'coupon': code};
    await sendNotification(userId: userId, title: title, body: body, type: 'promo', metadata: metadata);
  }

  Future<void> sendWalletUpdate({
    required String userId,
    required double amount,
    required double balance,
  }) async {
    final title = 'تحديث المحفظة';
    final body = 'تم إضافة ${amount.toStringAsFixed(2)} إلى محفظتك. الرصيد الآن ${balance.toStringAsFixed(2)}.';
    final metadata = {'screen': 'wallet'};
    await sendNotification(userId: userId, title: title, body: body, type: 'wallet_update', metadata: metadata);
  }

  // -----------------------
  // Existing helper methods
  // -----------------------
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
    } catch (e, st) {
      debugPrint('NotificationService.getUnreadCount error: $e\n$st');
      return 0;
    }
  }
}