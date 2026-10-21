import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_localizations.dart';
import '../../state/auth_state.dart';
import '../../providers/theme_provider.dart';
import '../../providers/agencies_provider.dart';
import '../../screens/profile_screen.dart';
import '../../screens/privacy_screen.dart';
import '../../screens/notification_screen.dart';
import '../../screens/help_center_screen.dart';
import '../../screens/auth_screen.dart';
import '../../theme/app_colors.dart';
import 'custom_button.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  Widget _buildSettingOption(
      BuildContext context,
      IconData icon,
      String titleKey,
      VoidCallback onTap, {
        Color? iconBg,
      }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconBg ?? AppColors.primary).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconBg ?? AppColors.primary, size: 22),
        ),
        title: Text(
          context.t(titleKey),
          style: const TextStyle(
            fontFamily: AppFonts.arabic,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            context.t('language'),
            style: const TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('العربية', style: TextStyle(fontFamily: AppFonts.arabic)),
                onTap: () {
                  Navigator.pop(ctx);
                  AppLocalizations.load(const Locale('ar'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('English', style: TextStyle(fontFamily: AppFonts.arabic)),
                onTap: () {
                  Navigator.pop(ctx);
                  AppLocalizations.load(const Locale('en'));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthState>(context, listen: false);
    final role = auth.userRole?.toLowerCase() ?? '';
    final themeProv = Provider.of<ThemeProvider>(context);
    final agenciesProv = Provider.of<AgenciesProvider>(context, listen: false);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: isDark ? AppColors.webCardBackground.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.t(L10nKeys.settings),
                          style: const TextStyle(
                            fontFamily: AppFonts.arabic,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),

                  // Options
                  _buildSettingOption(context, Icons.person_outline, L10nKeys.profile, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  }),

                  _buildSettingOption(context, Icons.lock_outline, 'privacy', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()));
                  }),

                  _buildSettingOption(context, Icons.language, 'language', () {
                    _showLanguageDialog(context);
                  }),

                  // Theme Switcher
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.brightness_6_outlined, color: AppColors.primary),
                      title: Text(
                        isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
                        style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      value: isDark,
                      onChanged: (val) {
                        final mode = val ? ThemeMode.dark : ThemeMode.light;
                        themeProv.setThemeMode(mode);
                      },
                    ),
                  ),

                  _buildSettingOption(context, Icons.notifications_outlined, L10nKeys.notifications, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                  }),

                  _buildSettingOption(context, Icons.support_agent, 'help_center', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen()));
                  }),

                  const SizedBox(height: 8),

                  // Agency Options
                  if (role == 'agency' || role == 'office' || role == 'admin') ...[
                    const Divider(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Text(
                          'خيارات المكتب',
                          style: TextStyle(
                            fontFamily: AppFonts.arabic,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                    _buildSettingOption(context, Icons.business, 'agency_settings', () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/agency_settings');
                    }),
                    _buildSettingOption(context, Icons.account_balance_wallet, 'agency_wallet', () {
                      Navigator.pop(context);
                      final id = agenciesProv.currentAgency?.id;
                      if (id != null) {
                        Navigator.pushNamed(context, '/agency_wallet', arguments: {'agencyId': id});
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد مكتب محدد')));
                      }
                    }),
                    _buildSettingOption(context, Icons.list_alt, 'agency_transactions', () {
                      Navigator.pop(context);
                      final id = agenciesProv.currentAgency?.id;
                      if (id != null) {
                        Navigator.pushNamed(context, '/agency_transactions', arguments: {'agencyId': id});
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد مكتب محدد')));
                      }
                    }),
                  ],

                  const SizedBox(height: 8),

                  _buildSettingOption(context, Icons.logout, L10nKeys.logout, () async {
                    Navigator.pop(context);
                    await context.read<AuthState>().logout();
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                  }),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: context.t(L10nKeys.cancel),
                          compact: true,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}