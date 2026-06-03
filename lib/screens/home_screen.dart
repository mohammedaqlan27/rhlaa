// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import 'driver_home_screen.dart';
import 'passenger_home_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState?>(context);

    if (authState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final firebaseUser = authState.firebaseUser;
    if (firebaseUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final rawRole = (authState.userType ?? authState.userRole ?? '').trim();
    if (rawRole.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final role = rawRole.toLowerCase();

    if (role == 'driver' || role == 'سائق') {
      return const DriverHomeScreen();
    } else {
      return const PassengerHomeScreen();
    }
  }
}
