// lib/models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // مثال: 'booking', 'payment', 'system', ...
  final Map<String, dynamic>? metadata; // بيانات إضافية قابلة للتوسع
  final bool isRead;
  final Timestamp? createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = 'general',
    this.metadata,
    this.isRead = false,
    this.createdAt,
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
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    }..removeWhere((key, value) => value == null);
  }

  /// إنشاء نموذج من مستند Firestore مع دعم camelCase و snake_case
  factory AppNotification.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String _s(List<String> keys, [String fallback = '']) {
      for (var k in keys) {
        final v = data[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    bool _b(List<String> keys, [bool fallback = false]) {
      for (var k in keys) {
        final v = data[k];
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) return v.toLowerCase() == 'true';
      }
      return fallback;
    }

    Map<String, dynamic>? _m(List<String> keys) {
      for (var k in keys) {
        final v = data[k];
        if (v is Map<String, dynamic>) return v;
        if (v is Map) return Map<String, dynamic>.from(v);
        if (v is String) {
          try {
            // محاولة تحويل JSON نصي إلى Map
            final parsed = Map<String, dynamic>.from(
                (v.isNotEmpty) ? (v.startsWith('{') ? (v as dynamic) : {}) : {});
            return parsed;
          } catch (_) {}
        }
      }
      return null;
    }

    Timestamp? _ts(List<String> keys) {
      for (var k in keys) {
        final v = data[k];
        if (v is Timestamp) return v;
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return Timestamp.fromDate(parsed);
        }
      }
      return null;
    }

    return AppNotification(
      id: doc.id,
      userId: _s(['userId', 'user_id']),
      title: _s(['title']),
      body: _s(['body', 'message']),
      type: _s(['type'], 'general'),
      metadata: _m(['metadata', 'meta', 'data']),
      isRead: _b(['isRead', 'is_read', 'read']),
      createdAt: _ts(['createdAt', 'created_at', 'timestamp']),
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
    Timestamp? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'AppNotification(id: $id, userId: $userId, title: $title, type: $type, isRead: $isRead)';
  }
}
