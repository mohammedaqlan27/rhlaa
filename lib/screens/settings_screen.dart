// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

/// شاشة الإعدادات لربط ThemeProvider (وضع الثيم، التباين العالي، لون seed)
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
        title: const Text('الإعدادات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('مظهر التطبيق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),

          // اختيار وضع الثيم (System / Light / Dark)
          Card(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: currentMode,
                  title: const Text('اتباع نظام الجهاز'),
                  onChanged: (v) {
                    if (v != null) themeProvider.setMode(v);
                  },
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: currentMode,
                  title: const Text('فاتح'),
                  onChanged: (v) {
                    if (v != null) themeProvider.setMode(v);
                  },
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: currentMode,
                  title: const Text('داكن'),
                  onChanged: (v) {
                    if (v != null) themeProvider.setMode(v);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // High Contrast toggle
          Card(
            child: SwitchListTile(
              title: const Text('وضع التباين العالي'),
              subtitle: const Text('يزيد أحجام النصوص ويعزز التباين لتحسين الوصول'),
              value: highContrast,
              onChanged: (val) => themeProvider.setHighContrast(val),
            ),
          ),

          const SizedBox(height: 16),

          // Seed color picker
          const Text('لون الهوية (Seed Color)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اللون الحالي:'),
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
                        child: const Text('تغيير اللون'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => themeProvider.setSeedColor(null),
                        child: const Text('إعادة الافتراضي'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // زر حفظ/معاينة
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حفظ الإعدادات'), behavior: SnackBarBehavior.floating),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text('حفظ الإعدادات'),
          ),

          const SizedBox(height: 12),

          // إعادة الإعدادات إلى الافتراضي
          OutlinedButton(
            onPressed: () async {
              await themeProvider.setMode(ThemeMode.system);
              await themeProvider.setHighContrast(false);
              await themeProvider.setSeedColor(null);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إعادة الإعدادات إلى الافتراضي')));
              }
            },
            child: const Text('إعادة الإعدادات إلى الافتراضي'),
          ),
        ],
      ),
    );
  }

  // نافذة اختيار لون بسيطة مع مجموعة ألوان مقترحة
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
          title: const Text('اختر لون الهوية'),
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
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ],
        );
      },
    );
  }
}
