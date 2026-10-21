// lib/widgets/agency/agency_support_widget.dart
import 'package:flutter/material.dart';
import '/theme/app_colors.dart';
import '/widgets/shared/app_card.dart';

class AgencySupportWidget extends StatelessWidget {
  const AgencySupportWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('مركز الدعم الفني والمساندة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          const Text('تواجه مشكلة في إدارة رحلاتك أو حجوزات العملاء؟ تواصل مع فريق الإدارة فوراً.', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.headset_mic, color: AppColors.primary, size: 28),
            title: const Text('التواصل المباشر مع الدعم', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('متاحون طوال أيام الأسبوع لخدمتكم', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {},
              child: const Text('مراسلة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
