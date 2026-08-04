// lib/services/notification_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../models/user_prefs_model.dart';

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

  /// جلب النصوص المخصصة من Firestore (مثل دعاء السفر أو رسائل التحفيز)
  Future<Map<String, dynamic>> _getRemoteContent() async {
    if (_cachedRemoteContent != null) return _cachedRemoteContent!;
    try {
      final doc = await _firestore.collection(settingsCollection).doc('notifications_content').get();
      if (doc.exists) {
        _cachedRemoteContent = doc.data();
        return _cachedRemoteContent!;
      }
    } catch (e) {
      debugPrint('Error fetching remote content: $e');
    }
    // نصوص احتياطية في حال فشل الجلب
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
      debugPrint('Error fetching prefs: $e');
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
  // 2. المحرك الرئيسي للإرسال (Core Engine)
  // ---------------------------------------------------------

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
      // التحقق من التفضيلات (هل المستخدم مفعل هذا النوع من الإشعارات؟)
      final prefs = await getPrefs(userId);
      if (type == 'promo' && !prefs.marketing) return;
      if (type == 'transactional' && !prefs.transactional) return;

      // 1. إضافة الإشعار لقاعدة البيانات (ليظهر في مركز الإشعارات داخل التطبيق)
      final docRef = await _firestore.collection(collectionName).add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'metadata': metadata,
        'actionUrl': actionUrl,
        'priority': priority,
        'sendNotification': sendPush,
        'transactionId': transactionId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. استدعاء Cloud Function لإرسال Push Notification حقيقي للهاتف
      if (sendPush) {
        await _functions.httpsCallable('sendNotificationToUser').call({
          'notificationId': docRef.id,
          'userId': userId,
          'title': title,
          'body': body,
          'data': metadata ?? {},
        });
      }
    } catch (e, st) {
      debugPrint('NotificationService.sendNotification error: $e\n$st');
    }
  }

  // ---------------------------------------------------------
  // 3. قوالب الخدمات المطورة (الركاب والسائقين)
  // ---------------------------------------------------------

  // --- إشعارات الركاب ---

  Future<void> sendPassengerPaymentReminder({required String userId, required String bookingId, required String amount}) async {
    await sendNotification(
      userId: userId,
      title: 'تذكير بسداد الحجز 💳',
      body: 'نود تذكيرك بضرورة دفع $amount ريال للحجز رقم $bookingId لضمان تأكيد مقعدك.',
      type: 'transactional',
      metadata: {'screen': 'booking', 'bookingId': bookingId},
    );
  }

  Future<void> sendTripStartGreeting({required String userId, required String passengerName, required String destination}) async {
    final content = await _getRemoteContent();
    final prayer = content['travel_prayer'];
    await sendNotification(
      userId: userId,
      title: 'انطلقت الرحلة! رافقتكم السلامة ✈️',
      body: 'أهلاً بك يا $passengerName في رحلتك إلى $destination.\n\n📌 $prayer',
      type: 'transactional',
      metadata: {'screen': 'trip_live'},
    );
  }

  Future<void> sendMidTripReassurance({required String userId, required String passengerName}) async {
    final content = await _getRemoteContent();
    final msg = content['mid_trip_msg'];
    await sendNotification(
      userId: userId,
      title: 'نحن معك في الطريق 🛣️',
      body: 'عزيزي $passengerName، $msg',
      type: 'transactional',
      metadata: {'screen': 'trip_live'},
    );
  }

  Future<void> sendPassengerArrival({required String userId, required String destination}) async {
    await sendNotification(
      userId: userId,
      title: 'الحمد لله على السلامة! 🏁',
      body: 'لقد وصلنا بحمد الله إلى $destination. نرجو منك تقييم تجربتك معنا.',
      type: 'transactional',
      metadata: {'screen': 'rating'},
    );
  }

  // --- إشعارات السائقين ---

  Future<void> sendDriverMotivation({required String userId, required String driverName}) async {
    final content = await _getRemoteContent();
    final msg = content['driver_motivation'];
    await sendNotification(
      userId: userId,
      title: 'رسالة تحفيزية 🌟',
      body: 'يا $driverName، $msg',
      type: 'driver_support',
      metadata: {'screen': 'driver_home'},
    );
  }

  // --- إشعارات الحالة العامة (السائق في الطريق، تأخر، إلخ) ---

  Future<void> sendDriverOnTheWay({required String userId, required String driverName, required String plate, required String tripId}) async {
    await sendNotification(
      userId: userId,
      title: 'السائق في الطريق',
      body: 'السائق $driverName في الطريق إليك. رقم المركبة $plate.',
      type: 'transactional',
      metadata: {'screen': 'trip_live', 'tripId': tripId},
    );
  }

  Future<void> sendSafetyAlert({required String userId, required String tripId, String? message}) async {
    await sendNotification(
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
      debugPrint('Error getNotificationsOnce: $e');
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