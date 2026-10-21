import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final VoidCallback onThemeTapped;
  final bool isDarkMode;
  final Color accentTeal;
  final Color textColor;
  final Color subtitleColor;
  final Color surfaceColor;
  final Color scaffoldBg;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.onThemeTapped,
    required this.isDarkMode,
    required this.accentTeal,
    required this.textColor,
    required this.subtitleColor,
    required this.surfaceColor,
    required this.scaffoldBg,
  }); // تم تنظيف الحقل المكرر هنا

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      color: surfaceColor,
      child: Column(
        children: [
          DrawerHeader(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.admin_panel_settings_rounded, color: accentTeal, size: 45),
                const SizedBox(height: 10),
                Text('لوحة تحكم رحلاء', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                Text('إدارة المنظومة', style: TextStyle(color: subtitleColor, fontSize: 12, fontFamily: 'Cairo')),
              ],
            ),
          ),
          _buildSidebarItem(Icons.dashboard_rounded, 'نظرة عامة', 0),
          _buildSidebarItem(Icons.business_rounded, 'الوكالات', 1),
          _buildSidebarItem(Icons.pending_actions_rounded, 'الطلبات المعلقة', 2),
          _buildSidebarItem(Icons.map_rounded, 'مراقبة الرحلات', 3),
          _buildSidebarItem(Icons.settings_rounded, 'إعدادات النظام', 4),
          const Spacer(),
          // زر تبديل الثيم
          ListTile(
            leading: Icon(isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: accentTeal),
            title: Text(isDarkMode ? 'الوضع الفاتح' : 'الوضع الداكن', style: TextStyle(color: textColor, fontFamily: 'Cairo')),
            onTap: onThemeTapped,
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent, fontFamily: 'Cairo')),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  ListTile _buildSidebarItem(IconData icon, String title, int index) {
    final isSelected = selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? accentTeal : subtitleColor),
      title: Text(title, style: TextStyle(color: isSelected ? textColor : subtitleColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontFamily: 'Cairo')),
      tileColor: isSelected ? accentTeal.withOpacity(0.1) : Colors.transparent,
      onTap: () => onItemTapped(index),
    );
  }
}