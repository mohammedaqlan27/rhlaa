// lib/models/user_prefs_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserNotificationPrefs {
  final String userId;
  final bool marketing;
  final bool transactional;
  final List<int> reminderHours;
  final String locale;

  UserNotificationPrefs({
    required this.userId,
    this.marketing = true,
    this.transactional = true,
    this.reminderHours = const [24, 1],
    this.locale = 'ar',
  });

  // هذه هي الدالة التي كانت تنقصك وتسببت في الخطأ
  UserNotificationPrefs copyWith({
    String? userId,
    bool? marketing,
    bool? transactional,
    List<int>? reminderHours,
    String? locale,
  }) {
    return UserNotificationPrefs(
      userId: userId ?? this.userId,
      marketing: marketing ?? this.marketing,
      transactional: transactional ?? this.transactional,
      reminderHours: reminderHours ?? this.reminderHours,
      locale: locale ?? this.locale,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'marketing': marketing,
      'transactional': transactional,
      'reminderHours': reminderHours,
      'locale': locale,
    };
  }

  factory UserNotificationPrefs.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserNotificationPrefs(
      userId: doc.id,
      marketing: data['marketing'] ?? true,
      transactional: data['transactional'] ?? true,
      reminderHours: List<int>.from(data['reminderHours'] ?? [24, 1]),
      locale: data['locale'] ?? 'ar',
    );
  }
}