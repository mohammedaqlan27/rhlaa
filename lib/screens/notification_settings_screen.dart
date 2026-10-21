// lib/screens/notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../models/user_prefs_model.dart';
import '../widgets/shared/custom_button.dart'; // استيراد الزر المطور

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _service = NotificationService();
  UserNotificationPrefs? _prefs;
  bool _isLoading = true;
  bool _isSaving = false; // حالة للحفظ

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final data = await _service.getPrefs(uid);
      setState(() {
        _prefs = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveData() async {
    if (_prefs == null) return;
    setState(() => _isSaving = true);
    try {
      await _service.savePrefs(_prefs!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الإعدادات بنجاح', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء الحفظ')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1E70B8))),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'إعدادات الإشعارات',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // قسم اللغة
            _buildSectionTitle('تفضيلات اللغة'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: const Text('لغة الإشعارات', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                trailing: DropdownButton<String>(
                  value: _prefs!.locale,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'ar', child: Text('العربية', style: TextStyle(fontFamily: 'Cairo'))),
                    DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(fontFamily: 'Cairo'))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _prefs = _prefs!.copyWith(locale: val));
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('أنواع التنبيهات'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('إشعارات تسويقية', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                    subtitle: const Text('عروض، كوبونات خصم، وأخبار الرحلات', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                    value: _prefs!.marketing,
                    activeThumbColor: const Color(0xFF1E70B8),
                    onChanged: (v) => setState(() => _prefs = _prefs!.copyWith(marketing: v)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('إشعارات العمليات', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                    subtitle: const Text('تأكيد الحجز، الدفع، وتنبيهات الأمان', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                    value: _prefs!.transactional,
                    activeThumbColor: const Color(0xFF1E70B8),
                    onChanged: (v) => setState(() => _prefs = _prefs!.copyWith(transactional: v)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('تذكير موعد الرحلة'),
            const Text(
              'اختر متى نذكرك قبل انطلاق رحلتك:',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [24, 8, 3, 2, 1].map((h) {
                final selected = _prefs!.reminderHours.contains(h);
                return ChoiceChip(
                  label: Text('$h ساعة', style: const TextStyle(fontFamily: 'Cairo')),
                  selected: selected,
                  selectedColor: const Color(0xFF1E70B8).withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: selected ? const Color(0xFF1E70B8) : Colors.black87,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (v) {
                    List<int> newList = List.from(_prefs!.reminderHours);
                    if (v) {
                      newList.add(h);
                    } else {
                      newList.remove(h);
                    }
                    setState(() => _prefs = _prefs!.copyWith(reminderHours: newList));
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 40),

            // استخدام الزر المطور
            CustomButton(
              text: 'حفظ التغييرات',
              icon: Icons.save_rounded,
              isLoading: _isSaving,
              onPressed: _saveData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: Color(0xFF1E70B8),
        ),
      ),
    );
  }
}