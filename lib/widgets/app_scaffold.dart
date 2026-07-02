// lib/widgets/app_scaffold.dart
import 'package:flutter/material.dart';
import 'custom_button.dart';

class AppScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showSettingsButton;
  final bool isLoading;
  final PreferredSizeWidget? bottom;
  final Widget? drawer;
  final Widget? bottomNavigationBar; // أضفنا خيار القائمة السفلية
  final EdgeInsetsGeometry? padding; // جعلناه اختياري للتحكم الكامل
  final bool extendBodyBehindAppBar;
  final Color? appBarColor;

  const AppScaffold({
    Key? key,
    this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showSettingsButton = false,
    this.isLoading = false,
    this.bottom,
    this.drawer,
    this.bottomNavigationBar,
    this.padding,
    this.extendBodyBehindAppBar = false,
    this.appBarColor,
  }) : super(key: key);

  // ألوان الهوية البصرية لـ "رحلاء"
  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _baseBg = Color(0xFFF8FAFC); // لون خلفية أفتح وأكثر راحة

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مقبض السحب العلوي
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.settings_suggest_outlined, size: 50, color: _logoBlue),
              const SizedBox(height: 16),
              const Text(
                'الإعدادات والروابط السريعة',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: _logoBlue),
              ),
              const SizedBox(height: 12),
              const Text(
                'من هنا يمكنك تعديل ملفك الشخصي، الوصول إلى الدعم الفني، أو معرفة المزيد حول تطبيق رحلاء.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black54, height: 1.6),
              ),
              const SizedBox(height: 32),
              // خيارات سريعة داخل الإعدادات
              _buildSettingOption(Icons.person_outline, 'تعديل الملف الشخصي', () {}),
              _buildSettingOption(Icons.help_outline, 'مركز المساعدة', () {}),
              _buildSettingOption(Icons.info_outline, 'عن رحلاء', () {}),
              const SizedBox(height: 24),
              CustomButton(
                onPressed: () => Navigator.of(ctx).pop(),
                text: 'إغلاق',
                compact: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: _logoBlue),
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _baseBg,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawer: drawer,
      bottomNavigationBar: bottomNavigationBar,
      appBar: AppBar(
        title: title != null
            ? Text(
          title!,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        )
            : null,
        centerTitle: true,
        elevation: 0,
        backgroundColor: appBarColor ?? _baseBg,
        foregroundColor: _logoBlue,
        surfaceTintColor: Colors.transparent, // يمنع تغير اللون عند التمرير في Material 3
        actions: [
          if (actions != null) ...actions!,
          if (showSettingsButton)
            IconButton(
              tooltip: 'الإعدادات',
              icon: const Icon(Icons.settings_outlined, color: _logoBlue),
              onPressed: () => _openSettings(context),
            ),
          const SizedBox(width: 8),
        ],
        bottom: bottom,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              // إذا لم يتم تمرير padding، نستخدم القيمة الافتراضية
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: body,
            ),
          ),
          // شاشة التحميل الشفافة
          if (isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_logoBlue),
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}