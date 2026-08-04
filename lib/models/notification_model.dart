// lib/models/notification_model.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final String? actionUrl;
  final String priority; // 'high', 'normal', 'low'
  final bool sendNotification;
  final String? transactionId;
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

  /// تحويل الكائن إلى Map للحفظ في Firestore
  /// يراعي قواعد الأمان بعدم إرسال حقول فارغة
  Map<String, dynamic> toMap() {
    return {
      'userId':userId,
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

  /// إنشاء نموذج من مستند Firestore مع معالجة ذكية لجميع أنواع البيانات
  factory AppNotification.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // دالة مساعدة لجلب النصوص (تتعامل مع camelCase و snake_case)
    String s(List<String> keys, [String fallback = '']) {
      for (var k in keys) {
        final v = data[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    // دالة مساعدة لجلب القيم المنطقية (تتعامل مع bool, int, String)
    bool b(List<String> keys, [bool fallback = false]) {
      for (var k in keys) {
        final v = data[k];
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) {
          final low = v.toLowerCase().trim();
          if (low == 'true' || low == '1') return true;
          if (low == 'false' || low == '0' || low == '') return false;
        }
      }
      return fallback;
    }

    // دالة مساعدة لمعالجة الـ Metadata (سواء كانت Map أو JSON String)
    Map<String, dynamic>? parseMeta(dynamic v) {
      if (v == null) return null;
      if (v is Map<String, dynamic>) return v;
      if (v is String && v.trim().isNotEmpty) {
        try { return json.decode(v); } catch (_) {}
      }
      return null;
    }

    // دالة مساعدة لمعالجة التوقيت (Timestamp)
    Timestamp? ts(List<String> keys) {
      for (var k in keys) {
        final v = data[k];
        if (v is Timestamp) return v;
        if (v is String) {
          final p = DateTime.tryParse(v);
          if (p != null) return Timestamp.fromDate(p);
        }
      }
      return null;
    }

    return AppNotification(
      id: doc.id,
      userId: s(['userId','user_id']),
      title: s(['title']),
      body: s(['body', 'message']),
      type: s(['type'], 'general'),
      metadata: parseMeta(data['metadata'] ?? data['meta'] ?? data['data']),
      isRead: b(['isRead', 'is_read', 'read'], false),
      actionUrl: s(['actionUrl', 'action_url', 'url']).isEmpty ? null : s(['actionUrl', 'action_url', 'url']),
      priority: s(['priority'], 'normal'),
      sendNotification: b(['sendNotification', 'send_notification'], true),
      transactionId: s(['transactionId', 'transaction_id']).isEmpty ? null : s(['transactionId', 'transaction_id']),
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
}