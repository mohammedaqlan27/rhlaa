// lib/services/notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../models/user_prefs_model.dart';

class NotificationResult {
  final bool success;
  final String? message;
  final dynamic raw;
  final String? notificationId;

  NotificationResult({required this.success, this.message, this.raw, this.notificationId});
}

class NotificationService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  // أسماء المجموعات (Collections)
  final String collectionName = 'notifications';
  final String scheduledCollection = 'scheduled_notifications';
  final String prefsCollection = 'user_notification_preferences';
  final String settingsCollection = 'app_settings';

  // ذاكرة مؤقتة للنصوص الديناميكية لتقليل القراءة من Firestore
  Map<String, dynamic>? _cachedRemoteContent;

  NotificationService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  // ---------------------------------------------------------
  // 1. إدارة التفضيلات والنصوص الديناميكية
  // ---------------------------------------------------------

  Future<Map<String, dynamic>> _getRemoteContent() async {
    if (_cachedRemoteContent != null) return _cachedRemoteContent!;
    try {
      final doc = await _firestore.collection(settingsCollection).doc('notifications_content').get();
      if (doc.exists) {
        _cachedRemoteContent = doc.data();
        return _cachedRemoteContent!;
      }
    } catch (e) {
      debugPrint('NotificationService._getRemoteContent error: $e');
    }
    return {
      'travel_prayer': 'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ، وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ',
      'mid_trip_msg': 'نأمل أنك تستمتع برحلتك الآن. نحن نتابع مسار الرحلة لضمان سلامتك.',
      'driver_motivation': 'طريق السلامة! تذكر أن سلامة الركاب هي أولويتنا، قد بحذر.',
    };
  }

  Future<UserNotificationPrefs> getPrefs(String userId) async {
    try {
      final doc = await _firestore.collection(prefsCollection).doc(userId).get();
      if (doc.exists) return UserNotificationPrefs.fromDocument(doc);
      return UserNotificationPrefs(userId: userId);
    } catch (e) {
      debugPrint('NotificationService.getPrefs error: $e');
      return UserNotificationPrefs(userId: userId);
    }
  }

  Future<void> savePrefs(UserNotificationPrefs prefs) async {
    await _firestore.collection(prefsCollection).doc(prefs.userId).set(
      prefs.toMap(),
      SetOptions(merge: true),
    );
  }

  // ---------------------------------------------------------
  // 2. المحرك الرئيسي للإرسال (Core Engine) - محسّن
  // ---------------------------------------------------------

  Future<NotificationResult> sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? metadata,
    String? actionUrl,
    String priority = 'normal',
    bool sendPush = true,
    String? transactionId,
    int maxRetries = 3,
  }) async {
    try {
      // تحقق من تفضيلات المستخدم
      final prefs = await getPrefs(userId);
      if (type == 'promo' && !prefs.marketing) {
        debugPrint('NotificationService.sendNotification: user $userId unsubscribed from promo');
        return NotificationResult(success: false, message: 'user_unsubscribed');
      }
      if (type == 'transactional' && !prefs.transactional) {
        debugPrint('NotificationService.sendNotification: user $userId unsubscribed from transactional');
        sendPush = false;
      }

      // 1) حفظ الإشعار في Firestore (حالة افتراضية: pushSent=false)
      final docRef = await _firestore.collection(collectionName).add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'metadata': metadata ?? {},
        'actionUrl': actionUrl,
        'priority': priority,
        'sendPush': sendPush,
        'transactionId': transactionId,
        'pushSent': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final notificationId = docRef.id;

      if (!sendPush) {
        debugPrint('NotificationService.sendNotification: saved notification without push for user $userId id=$notificationId');
        return NotificationResult(success: true, message: 'saved_no_push', notificationId: notificationId);
      }

      final payload = {
        'notificationId': notificationId,
        'userId': userId,
        'title': title,
        'body': body,
        'data': metadata ?? {},
        'priority': priority,
        'type': type,
        'transactionId': transactionId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        debugPrint('NotificationService.sendNotification payload: ${jsonEncode(payload)}');
      }

      int attempt = 0;
      int delayMs = 500;
      while (attempt < maxRetries) {
        attempt++;
        try {
          final callable = _functions.httpsCallable('sendNotificationToUser');
          final result = await callable.call(payload);

          await docRef.update({
            'pushSent': true,
            'pushResult': result.data,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (kDebugMode) {
            debugPrint('NotificationService.sendNotification success: attempt=$attempt notificationId=$notificationId result=${result.data}');
          }

          return NotificationResult(success: true, message: 'sent', raw: result.data, notificationId: notificationId);
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('NotificationService.sendNotification error: attempt=$attempt error=$e\n$st');
          }

          String errMsg = e.toString();
          try {
            if (e is FirebaseFunctionsException) {
              errMsg = '${e.code} - ${e.message}';
            }
          } catch (_) {}

          final isRetryable = _isRetryableError(e);

          if (!isRetryable || attempt >= maxRetries) {
            try {
              await docRef.update({
                'pushSent': false,
                'pushError': errMsg,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } catch (uErr) {
              debugPrint('NotificationService.sendNotification: failed to update doc after error: $uErr');
            }

            return NotificationResult(success: false, message: errMsg, raw: e, notificationId: notificationId);
          }

          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2;
          continue;
        }
      }

      return NotificationResult(success: false, message: 'failed_after_retries', notificationId: notificationId);
    } catch (e, st) {
      if (kDebugMode) debugPrint('NotificationService.sendNotification outer error: $e\n$st');
      return NotificationResult(success: false, message: e.toString());
    }
  }

  bool _isRetryableError(Object e) {
    try {
      if (e is FirebaseFunctionsException) {
        return e.code == 'internal' || e.code == 'unavailable' || e.code == 'deadline-exceeded' || e.code == 'resource-exhausted';
      }
    } catch (_) {}
    return true;
  }

  // ---------------------------------------------------------
  // 3. قوالب الخدمات المطورة (الركاب والسائقين) — تستخدم sendNotification المحسّن
  // ---------------------------------------------------------

  Future<NotificationResult> sendPassengerPaymentReminder({required String userId, required String bookingId, required String amount}) async {
    return await sendNotification(
      userId: userId,
      title: 'تذكير بسداد الحجز 💳',
      body: 'نود تذكيرك بضرورة دفع $amount ريال للحجز رقم $bookingId لضمان تأكيد مقعدك.',
      type: 'transactional',
      metadata: {'screen': 'booking', 'bookingId': bookingId},
    );
  }

  Future<NotificationResult> sendTripStartGreeting({required String userId, required String passengerName, required String destination}) async {
    final content = await _getRemoteContent();
    final prayer = content['travel_prayer'];
    return await sendNotification(
      userId: userId,
      title: 'انطلقت الرحلة! رافقتكم السلامة ✈️',
      body: 'أهلاً بك يا $passengerName في رحلتك إلى $destination.\n\n📌 $prayer',
      type: 'transactional',
      metadata: {'screen': 'trip_live'},
    );
  }

  Future<NotificationResult> sendMidTripReassurance({required String userId, required String passengerName}) async {
    final content = await _getRemoteContent();
    final msg = content['mid_trip_msg'];
    return await sendNotification(
      userId: userId,
      title: 'نحن معك في الطريق 🛣️',
      body: 'عزيزي $passengerName، $msg',
      type: 'transactional',
      metadata: {'screen': 'trip_live'},
    );
  }

  Future<NotificationResult> sendPassengerArrival({required String userId, required String destination}) async {
    return await sendNotification(
      userId: userId,
      title: 'الحمد لله على السلامة! 🏁',
      body: 'لقد وصلنا بحمد الله إلى $destination. نرجو منك تقييم تجربتك معنا.',
      type: 'transactional',
      metadata: {'screen': 'rating'},
    );
  }

  Future<NotificationResult> sendDriverMotivation({required String userId, required String driverName}) async {
    final content = await _getRemoteContent();
    final msg = content['driver_motivation'];
    return await sendNotification(
      userId: userId,
      title: 'رسالة تحفيزية 🌟',
      body: 'يا $driverName، $msg',
      type: 'driver_support',
      metadata: {'screen': 'driver_home'},
    );
  }

  Future<NotificationResult> sendDriverOnTheWay({required String userId, required String driverName, required String plate, required String tripId}) async {
    return await sendNotification(
      userId: userId,
      title: 'السائق في الطريق',
      body: 'السائق $driverName في الطريق إليك. رقم المركبة $plate.',
      type: 'transactional',
      metadata: {'screen': 'trip_live', 'tripId': tripId},
    );
  }

  Future<NotificationResult> sendSafetyAlert({required String userId, required String tripId, String? message}) async {
    return await sendNotification(
      userId: userId,
      title: 'تنبيه أمني هـام',
      body: message ?? 'تم استلام بلاغ أمني. فريقنا يتابع رحلتك الآن.',
      type: 'safety',
      priority: 'high',
      metadata: {'screen': 'support', 'tripId': tripId},
    );
  }

  // ---------------------------------------------------------
  // 4. الجدولة وإدارة البيانات (لشاشة الإشعارات)
  // ---------------------------------------------------------

  Future<void> scheduleTripReminders({required String userId, required String tripId, required DateTime tripStart}) async {
    final prefs = await getPrefs(userId);
    for (final h in prefs.reminderHours) {
      final sendAt = tripStart.subtract(Duration(hours: h));
      if (sendAt.isAfter(DateTime.now())) {
        await _firestore.collection(scheduledCollection).add({
          'userId': userId,
          'title': 'تذكير بموعد الرحلة',
          'body': 'رحلتك رقم $tripId تبدأ بعد $h ساعة.',
          'sendAt': Timestamp.fromDate(sendAt.toUtc()),
          'type': 'scheduled',
          'sent': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<List<AppNotification>> getNotificationsOnce({required String userId, int limit = 50}) async {
    try {
      final q = await _firestore
          .collection(collectionName)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return q.docs.map((d) => AppNotification.fromDocument(d)).toList();
    } catch (e) {
      debugPrint('NotificationService.getNotificationsOnce error: $e');
      return [];
    }
  }

  Stream<List<AppNotification>> streamNotifications(String userId, {int limit = 50}) {
    return _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AppNotification.fromDocument(d)).toList());
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection(collectionName).doc(notificationId).update({
      'isRead': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsReadBatch(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(_firestore.collection(collectionName).doc(id), {'isRead': true, 'updatedAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection(collectionName).doc(notificationId).delete();
  }

  Future<int> getUnreadCount(String userId) async {
    final q = await _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    return q.docs.length;
  }
}
