// lib/widgets/app_scaffold.dart
import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_indicator.dart';

/// AppScaffold
/// غلاف شاشة موحّد يستخدم في معظم شاشات التطبيق.
/// يوفر AppBar موحّد، زر إعدادات اختياري، drawer اختياري، وحالات تحميل/خطأ بسيطة.
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

  void _openSettings(BuildContext context) {
    // افتراضي: افتح bottom sheet إعدادات بسيطة
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              Text('الإعدادات', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              const Text('يمكنك إضافة روابط سريعة هنا: تعديل الملف الشخصي، المساعدة، حول التطبيق.'),
              const SizedBox(height: 16),
              CustomButton(
                onPressed: () => Navigator.of(ctx).pop(),
                text: 'إغلاق',
                compact: true,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: title != null ? Text(title!) : null,
      centerTitle: true,
      elevation: 2,
      actions: [
        if (actions != null) ...actions!,
        if (showSettingsButton)
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(context),
          ),
      ],
      bottom: bottom,
    );

    final content = SafeArea(
      child: Padding(
        padding: padding,
        child: isLoading
            ? Center(child: LoadingIndicator())
            : body,
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        appBar: appBar,
        drawer: drawer,
        body: content,
        floatingActionButton: floatingActionButton,
      ),
    );
  }

  Widget? LoadingIndicator() {}
}
