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
  final EdgeInsetsGeometry padding;
  final bool extendBodyBehindAppBar;

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
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.extendBodyBehindAppBar = false,
  }) : super(key: key);

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _baseBg = Color(0xFFF1F5F9);

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: _baseBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 20),
              Text(
                'الإعدادات والروابط السريعة',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: _logoBlue),
              ),
              const SizedBox(height: 12),
              const Text(
                'من هنا يمكنك تعديل ملفك الشخصي، الوصول إلى الدعم الفني، أو معرفة المزيد حول تطبيق رحلاء ومهمتنا لتسهيل تنقلك.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 24),
              CustomButton(
                onPressed: () => Navigator.of(ctx).pop(),
                text: 'إغلاق النافذة',
                compact: true,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: title != null
          ? Text(title!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold))
          : null,
      centerTitle: true,
      elevation: 0,
      backgroundColor: _baseBg,
      foregroundColor: _logoBlue,
      scrolledUnderElevation: 0,
      actions: [
        if (actions != null) ...actions!,
        if (showSettingsButton)
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_suggest_rounded, color: _logoBlue),
            onPressed: () => _openSettings(context),
          ),
      ],
      bottom: bottom,
    );

    final content = SafeArea(
      child: Padding(
        padding: padding,
        child: isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_logoBlue)))
            : body,
      ),
    );

    return Scaffold(
      backgroundColor: _baseBg,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      drawer: drawer,
      body: content,
      floatingActionButton: floatingActionButton,
    );
  }
}
