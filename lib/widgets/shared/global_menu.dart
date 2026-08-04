// lib/widgets/shared/global_menu.dart
import 'package:flutter/material.dart';
import 'custom_button.dart';

class GlobalMenu {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('القائمة الرئيسية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('الملف الشخصي'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('الدعم الفني'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('تسجيل الخروج'),
                onTap: () {},
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'إغلاق',
                compact: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
