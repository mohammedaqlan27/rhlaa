import 'dart:ui';
import 'package:flutter/material.dart';
import 'custom_button.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  static const Color _logoBlue = Color(0xFF1E70B8);

  Widget _buildSettingOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _logoBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: _logoBlue, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.settings_suggest_outlined, size: 54, color: _logoBlue),
            const SizedBox(height: 16),
            const Text(
              'الإعدادات والروابط السريعة',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.bold, color: _logoBlue),
            ),
            const SizedBox(height: 12),
            const Text(
              'تحكم في حسابك، تواصل مع الدعم، واكتشف المزيد عن رحلاء.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 24),
            _buildSettingOption(Icons.person_outline, 'تعديل الملف الشخصي', () {}),
            _buildSettingOption(Icons.security_outlined, 'الأمان والخصوصية', () {}),
            _buildSettingOption(Icons.help_outline, 'مركز المساعدة', () {}),
            const SizedBox(height: 32),
            CustomButton(
              onPressed: () => Navigator.of(context).pop(),
              text: 'إغلاق',
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}
