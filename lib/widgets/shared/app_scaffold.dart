import 'dart:ui'; // ضروري لتأثير التمويه (Blur)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ضروري للاهتزاز اللمسي والتحكم في الـ System UI
import 'custom_button.dart';
import 'settings_sheet.dart';

class AppScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showSettingsButton;
  final bool isLoading;
  final PreferredSizeWidget? bottom;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry? padding;
  final bool extendBodyBehindAppBar;
  final Color? appBarColor;
  final bool canPop; // خيار للتحكم في إمكانية الرجوع للخلف
  final bool hideBackButton; // تم إضافة تعريف المتغير هنا لإصلاح الخطأ

  const AppScaffold({
    super.key,
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
    this.canPop = true,
    this.hideBackButton = false,
  });

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _baseBg = Color(0xFFF8FAFC);

  void _openSettings(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isLoading && canPop,
      child: Scaffold(
        backgroundColor: _baseBg,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        drawer: drawer,
        bottomNavigationBar: bottomNavigationBar,
        appBar: _buildAppBar(context),
        body: Stack(
          children: [
            IgnorePointer(
              ignoring: isLoading,
              child: SafeArea(
                child: Padding(
                  padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: body,
                ),
              ),
            ),
            _buildLoadingOverlay(),
          ],
        ),
        floatingActionButton: floatingActionButton,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      automaticallyImplyLeading: !hideBackButton,
      title: title != null
          ? Text(
        title!,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold),
      )
          : null,
      centerTitle: true,
      elevation: 0,
      backgroundColor: appBarColor ?? _baseBg,
      foregroundColor: _logoBlue,
      surfaceTintColor: Colors.transparent,
      actions: [
        if (actions != null) ...actions!,
        if (showSettingsButton)
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context),
          ),
        const SizedBox(width: 8),
      ],
      bottom: bottom,
    );
  }

  Widget _buildLoadingOverlay() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isLoading
          ? Container(
        key: const ValueKey('loading'),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.white.withOpacity(0.4)),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_logoBlue),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'يرجى الانتظار...',
                    style: TextStyle(fontFamily: 'Cairo', color: _logoBlue.withOpacity(0.8), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          : const SizedBox.shrink(),
    );
  }
}
