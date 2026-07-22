// lib/screens/notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool marketing = false;
  bool transactional = true;
  List<int> reminderHours = [24, 3, 1];

  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    if (_uid == null) return;
    final doc = await _db.collection('user_notification_preferences').doc(_uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        marketing = data['marketing'] ?? false;
        transactional = data['transactional'] ?? true;
        reminderHours = List<int>.from(data['reminder_hours'] ?? [24, 3, 1]);
      });
    }
  }

  Future<void> _savePrefs() async {
    if (_uid == null) return;
    await _db.collection('user_notification_preferences').doc(_uid).set({
      'marketing': marketing,
      'transactional': transactional,
      'reminder_hours': reminderHours,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الإعدادات بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات الإشعارات', style: TextStyle(fontFamily: 'Cairo')),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('إشعارات تسويقية (عروض وكوبونات)', style: TextStyle(fontFamily: 'Cairo')),
              value: marketing,
              onChanged: (v) => setState(() => marketing = v),
            ),
            SwitchListTile(
              title: const Text('إشعارات أساسية (حجوزات، دفع، أمان)', style: TextStyle(fontFamily: 'Cairo')),
              value: transactional,
              onChanged: (v) => setState(() => transactional = v),
            ),
            const SizedBox(height: 16),
            const Text('ساعات التذكير قبل الرحلة:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 12,
              children: [24, 3, 1].map((h) {
                final selected = reminderHours.contains(h);
                return ChoiceChip(
                  label: Text('$h ساعة', style: const TextStyle(fontFamily: 'Cairo')),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        reminderHours.add(h);
                      } else {
                        reminderHours.remove(h);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _savePrefs,
              child: const Text('حفظ الإعدادات', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }
}
