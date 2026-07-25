// lib/models/notification_model.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج إشعار التطبيق (AppNotification)
/// يدعم حقول إضافية: actionUrl, priority, sendNotification, transactionId
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // مثال: 'booking', 'payment', 'system', ...
  final Map<String, dynamic>? metadata; // بيانات إضافية قابلة للتوسع
  final bool isRead;
  final String? actionUrl; // رابط ينقل المستخدم مباشرةً إلى شاشة معينة
  final String priority; // 'high', 'normal', 'low'
  final bool sendNotification; // هل نرسل push أم لا
  final String? transactionId; // معرف عملية إن وُجد
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = 'general',
    this.metadata,
    this.isRead = false,
    this.actionUrl,
    this.priority = 'normal',
    this.sendNotification = true,
    this.transactionId,
    this.createdAt,
    this.updatedAt,
  });

  /// تحويل الكائن إلى Map لحفظه في Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'metadata': metadata,
      'isRead': isRead,
      'actionUrl': actionUrl,
      'priority': priority,
      'sendNotification': sendNotification,
      'transactionId': transactionId,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    }..removeWhere((key, value) => value == null);
  }

  /// مساعدة لتحويل قيمة قد تكون JSON نصي إلى Map
  static Map<String, dynamic>? _tryParseMetadata(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      try {
        final decoded = json.decode(s);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // ليس JSON صالحًا — تجاهل
      }
    }
    return null;
  }

  /// إنشاء نموذج من مستند Firestore مع دعم camelCase و snake_case
  factory AppNotification.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String s(List<String> keys, [String fallback = '']) {
      for (var k in keys) {
        final v = data[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    bool b(List<String> keys, [bool fallback = false]) {
      for (var k in keys) {
        final v = data[k];
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) {
          final low = v.toLowerCase();
          if (low == 'true' || low == '1') return true;
          if (low == 'false' || low == '0') return false;
        }
      }
      return fallback;
    }

    Map<String, dynamic>? m(List<String> keys) {
      for (var k in keys) {
        final v = data[k];
        final parsed = _tryParseMetadata(v);
        if (parsed != null) return parsed;
      }
      return null;
    }

    Timestamp? ts(List<String> keys) {
      for (var k in keys) {
        final v = data[k];
        if (v is Timestamp) return v;
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return Timestamp.fromDate(parsed);
        }
        if (v is int) {
          try {
            return Timestamp.fromMillisecondsSinceEpoch(v);
          } catch (_) {}
        }
      }
      return null;
    }

    return AppNotification(
      id: doc.id,
      userId: s(['userId', 'user_id']),
      title: s(['title']),
      body: s(['body', 'message']),
      type: s(['type'], 'general'),
      metadata: m(['metadata', 'meta', 'data']),
      isRead: b(['isRead', 'is_read', 'read'], false),
      actionUrl: s(['actionUrl', 'action_url', 'url']).isNotEmpty ? s(['actionUrl', 'action_url', 'url']) : null,
      priority: s(['priority'], 'normal'),
      sendNotification: b(['sendNotification', 'send_notification'], true),
      transactionId: s(['transactionId', 'transaction_id']).isNotEmpty ? s(['transactionId', 'transaction_id']) : null,
      createdAt: ts(['createdAt', 'created_at', 'timestamp']),
      updatedAt: ts(['updatedAt', 'updated_at']),
    );
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? metadata,
    bool? isRead,
    String? actionUrl,
    String? priority,
    bool? sendNotification,
    String? transactionId,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
      priority: priority ?? this.priority,
      sendNotification: sendNotification ?? this.sendNotification,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'AppNotification(id: $id, userId: $userId, title: $title, type: $type, isRead: $isRead, priority: $priority, sendNotification: $sendNotification, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
