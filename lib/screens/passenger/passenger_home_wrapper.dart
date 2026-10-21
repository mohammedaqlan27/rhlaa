// lib/screens/passenger_home_wrapper.dart
import 'package:flutter/material.dart';
import '../../widgets/shared/app_scaffold.dart';
import 'passenger_home_screen.dart';

class PassengerHomeWrapper extends StatelessWidget {
  const PassengerHomeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'رحلة - راكب',
      showSettingsButton: true,
      isLoading: false, // يمكنك ربطها بحالة من Provider لاحقاً
      body: const PassengerHomeScreen(),
    );
  }
}
