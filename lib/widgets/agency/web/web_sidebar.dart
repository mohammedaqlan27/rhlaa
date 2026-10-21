// lib/widgets/web_sidebar.dart
import 'package:flutter/material.dart';

class WebSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const WebSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: const Color(0xFF121418),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus_filled_rounded, color: const Color(0xFF17A5A3), size: 30),
              const SizedBox(width: 10),
              const Text('رحلاء Web', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(height: 40),
          _buildNavItem(0, Icons.dashboard_rounded, 'لوحة التحكم الرئيسية'),
          _buildNavItem(1, Icons.gavel_rounded, 'الرقابة الحكومية'),
          _buildNavItem(2, Icons.confirmation_number_rounded, 'إدارة الحجوزات'),
          _buildNavItem(3, Icons.directions_bus_rounded, 'إدارة الرحلات'),
          _buildNavItem(4, Icons.people_alt_rounded, 'المستخدمين والسائقين'),
          const Spacer(),
          _buildNavItem(5, Icons.settings_rounded, 'الإعدادات'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title) {
    final isSelected = selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF17A5A3) : Colors.grey, size: 20),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
          fontFamily: 'Cairo',
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF1E70B8).withOpacity(0.15),
      onTap: () => onDestinationSelected(index),
    );
  }
}