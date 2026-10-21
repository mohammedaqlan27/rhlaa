import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentMode = themeProvider.mode;
    final highContrast = themeProvider.highContrast;
    final seed = themeProvider.seedColor ?? AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------------- مظهر التطبيق ----------------
          const Text('مظهر التطبيق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: currentMode,
                  title: const Text('اتباع نظام الجهاز', style: TextStyle(fontFamily: 'Cairo')),
                  onChanged: (v) {
                    if (v != null) themeProvider.setMode(v);
                  },
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: currentMode,
                  title: const Text('فاتح', style: TextStyle(fontFamily: 'Cairo')),
                  onChanged: (v) {
                    if (v != null) themeProvider.setMode(v);
                  },
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: currentMode,
                  title: const Text('داكن', style: TextStyle(fontFamily: 'Cairo')),
                  onChanged: (v) {
                    if (v != null) themeProvider.setMode(v);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: SwitchListTile(
              title: const Text('وضع التباين العالي', style: TextStyle(fontFamily: 'Cairo')),
              subtitle: const Text('يزيد أحجام النصوص ويعزز التباين لتحسين الوصول', style: TextStyle(fontFamily: 'Cairo')),
              value: highContrast,
              onChanged: (val) => themeProvider.setHighContrast(val),
            ),
          ),

          const SizedBox(height: 16),

          const Text('لون الهوية (Seed Color)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اللون الحالي:', style: TextStyle(fontFamily: 'Cairo')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: seed,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _showColorPicker(context, themeProvider),
                        child: const Text('تغيير اللون', style: TextStyle(fontFamily: 'Cairo')),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => themeProvider.setSeedColor(null),
                        child: const Text('إعادة الافتراضي', style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ---------------- إدارة الحساب ----------------
          const Text('إدارة الحساب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Card(
            child: Column(
              children: [
                ListTile(title: Text('ربط الحساب', style: TextStyle(fontFamily: 'Cairo')), leading: Icon(Icons.link)),
                ListTile(title: Text('الـ UID', style: TextStyle(fontFamily: 'Cairo')), leading: Icon(Icons.perm_identity)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ---------------- التخصيص ----------------
          const Text('التخصيص', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Card(
            child: Column(
              children: [
                ListTile(title: Text('اللغة', style: TextStyle(fontFamily: 'Cairo')), leading: Icon(Icons.language)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ---------------- المساعدة والملاحظات ----------------
          const Text('المساعدة والملاحظات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Card(
            child: Column(
              children: [
                ListTile(title: Text('دليل المساعدة', style: TextStyle(fontFamily: 'Cairo')), leading: Icon(Icons.help_outline)),
                ListTile(title: Text('خدمة العملاء', style: TextStyle(fontFamily: 'Cairo')), leading: Icon(Icons.support_agent)),
                ListTile(title: Text('ملاحظات المستخدم', style: TextStyle(fontFamily: 'Cairo')), leading: Icon(Icons.feedback)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ---------------- قانوني ----------------
          const Text('قانوني', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Card(
            child: Column(
              children: [
                ListTile(title: Text('معلومات', style: TextStyle(fontFamily: 'Cairo')), leading: Icon(Icons.info)),
                ListTile(title: Text('سياسة الخصوصية', style: TextStyle(fontFamily: 'Cairo')), leading: Icon(Icons.privacy_tip)),
                ListTile(title: Text('ملفات تعريف الارتباط', style: TextStyle(fontFamily: 'Cairo')), leading: Icon(Icons.cookie)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ---------------- تفضيلات البيانات ----------------
          const Text('تفضيلات البيانات الخاصة بك', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Card(
            child: Column(
              children: [
                ListTile(title: Text('إدارة التفضيلات', style: TextStyle(fontFamily: 'Cairo')), leading: Icon(Icons.settings)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ---------------- إعدادات متقدمة ----------------
          const Text('إعدادات متقدمة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Card(
            child: Column(
              children: [
                ListTile(title: Text('بيانات فريق العمل', style: TextStyle(fontFamily: 'Cairo')), leading: Icon(Icons.group)),
                ListTile(title: Text('حذف الحساب', style: TextStyle(fontFamily: 'Cairo')), leading: Icon(Icons.delete_forever)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // زر حفظ/معاينة
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حفظ الإعدادات', style: TextStyle(fontFamily: 'Cairo')), behavior: SnackBarBehavior.floating),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text('حفظ الإعدادات', style: TextStyle(fontFamily: 'Cairo')),
          ),

          const SizedBox(height: 12),

          // إعادة الإعدادات إلى الافتراضي
          OutlinedButton(
            onPressed: () async {
              await themeProvider.setMode(ThemeMode.system);
              await themeProvider.setHighContrast(false);
              await themeProvider.setSeedColor(null);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إعادة الإعدادات إلى الافتراضي', style: TextStyle(fontFamily: 'Cairo'))));
              }
            },
            child: const Text('إعادة الإعدادات إلى الافتراضي', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, ThemeProvider themeProvider) {
    final colors = <Color>[
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      const Color(0xFF0D47A1),
      const Color(0xFF00695C),
      const Color(0xFF2E7D32),
      Colors.deepPurple,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
    ];

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('اختر لون الهوية', style: TextStyle(fontFamily: 'Cairo')),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: colors.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final c = colors[index];
                return GestureDetector(
                  onTap: () {
                    themeProvider.setSeedColor(c);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          ],
        );
      },
    );
  }
}