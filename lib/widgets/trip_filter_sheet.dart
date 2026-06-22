// lib/widgets/trip_filter_sheet.dart
import 'package:flutter/material.dart';
import 'app_card.dart';

class TripFilterSheet extends StatelessWidget {
  const TripFilterSheet({super.key});

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoTeal = Color(0xFF17A5A3);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9), // نفس لون الخلفية النيومورفية الأساسية للتطبيق
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // مقبض السحب العلوي الأنيق
          Center(
            child: Container(
              width: 45,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'خيارات تصفية الرحلات',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: _logoBlue),
          ),
          const SizedBox(height: 16),

          // خيار الفلترة الأول بداخل كرت نيومورفي متناسق
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.amber.shade700),
                    const SizedBox(width: 12),
                    const Text('عرض الرحلات النشطة فقط', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                Switch.adaptive(
                  value: true,
                  activeColor: _logoTeal,
                  onChanged: (bool value) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // زر التطبيق السفلي الموحد لرحلاء
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _logoBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'تأكيد الفلترة والمشاهدة',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}