import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
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
  final bool canPop;
  final bool hideBackButton;

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

  void _openSettings(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.webBackground : AppColors.background;

    return PopScope(
      canPop: !isLoading && canPop,
      child: Scaffold(
        backgroundColor: backgroundColor,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        drawer: drawer,
        bottomNavigationBar: bottomNavigationBar,
        appBar: _buildAppBar(context, isDark),
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
            _buildLoadingOverlay(isDark),
          ],
        ),
        floatingActionButton: floatingActionButton,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      automaticallyImplyLeading: !hideBackButton,
      title: title != null
          ? Text(
        title!,
        style: TextStyle(
          fontFamily: AppFonts.arabic,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      )
          : null,
      centerTitle: true,
      elevation: 0,
      backgroundColor: appBarColor ?? (isDark ? AppColors.webBackground : AppColors.background),
      foregroundColor: isDark ? Colors.white : AppColors.primary,
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

  Widget _buildLoadingOverlay(bool isDark) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isLoading
          ? Container(
        key: const ValueKey('loading'),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.4),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'يرجى الانتظار...',
                    style: TextStyle(
                      fontFamily: AppFonts.arabic,
                      color: isDark ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
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