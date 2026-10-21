// lib/screens/agency_settings_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/agency/agency_settings_widget.dart';

class AgencySettingsScreen extends StatelessWidget {
  const AgencySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إعدادات المكتب')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: const [
              // الودجت المستقل يعالج تحميل المكتب الحالي أو استخدام agencyId إن مررته
              AgencySettingsWidget(),
              SizedBox(height: 20),
              // يمكن إضافة بطاقات أو روابط إضافية هنا لاحقًا
            ],
          ),
        ),
      ),
    );
  }
}
