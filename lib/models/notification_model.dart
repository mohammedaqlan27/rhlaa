// lib/models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final Timestamp? createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.createdAt,
    this.isRead = false,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'isRead': isRead,
      'metadata': metadata,
      // snake_case duplicates
      'user_id': userId,
      'created_at': createdAt ?? FieldValue.serverTimestamp(),
      'is_read': isRead,
    };
  }

  factory AppNotification.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String? _getString(List<String> keys, [String? fallback]) {
      for (final k in keys) {
        if (data.containsKey(k) && data[k] != null) return data[k].toString();
      }
      return fallback;
    }

    bool _getBool(List<String> keys, [bool fallback = false]) {
      for (final k in keys) {
        final v = data[k];
        if (v is bool) return v;
        if (v is int) return v != 0;
        if (v is String) return v.toLowerCase() == 'true';
      }
      return fallback;
    }

    Timestamp? _getTimestamp(List<String> keys) {
      for (final k in keys) {
        final v = data[k];
        if (v is Timestamp) return v;
        if (v is DateTime) return Timestamp.fromDate(v);
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return Timestamp.fromDate(parsed);
        }
      }
      return null;
    }

    final userId = _getString(['userId', 'user_id']) ?? '';
    final title = _getString(['title']) ?? '';
    final body = _getString(['body']) ?? '';
    final type = _getString(['type']) ?? '';
    final createdAt = _getTimestamp(['createdAt', 'created_at']);
    final isRead = _getBool(['isRead', 'is_read'], false);

    final metadata = (() {
      final m = data['metadata'] ?? data['meta'];
      if (m is Map) return Map<String, dynamic>.from(m as Map);
      return null;
    })();

    return AppNotification(
      id: doc.id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      createdAt: createdAt,
      isRead: isRead,
      metadata: metadata,
    );
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    Timestamp? createdAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'AppNotification(id: $id, userId: $userId, title: $title, type: $type, createdAt: $createdAt, isRead: $isRead)';
  }
}
