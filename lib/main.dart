// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'theme/app_colors.dart';
import 'state/auth_state.dart';
import 'screens/auth_wrapper.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/passenger_home_screen.dart' hide Trip;
import 'screens/driver_home_screen.dart';
import 'screens/create_trip_screen.dart';
import 'screens/available_trips_screen.dart';
import 'screens/trip_details_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/payment_confirmation_screen.dart';
import 'utils/app_localizations.dart';
import 'models/trip.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthState>(create: (_) => AuthState()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Stream<DocumentSnapshot<Map<String, dynamic>>> _uiSettingsStream() {
    return FirebaseFirestore.instance.collection('settings').doc('ui').snapshots();
  }

  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      '/auth': (_) => const AuthScreen(),
      '/home': (_) => const HomeScreen(),
      '/passenger_home': (_) => const PassengerHomeScreen(),
      '/driver_home': (_) => const DriverHomeScreen(),
      '/create_trip': (_) => const CreateTripScreen(),
      '/available_trips': (_) => const AvailableTripsScreen(destination: ''),
      '/trip_details': (_) => TripDetailsScreen(trip: Trip(id: 'mock', title: 'Mock Trip')),
      '/my_bookings': (_) => const MyBookingsScreen(),
      '/notifications': (_) => const NotificationScreen(),
      '/payment_confirmation': (_) => const PaymentConfirmationScreen(
        bookingId: 'mock-booking-id',
        transactionId: 'mock-transaction-id',
        amount: 0.0,
        paymentMethod: 'mock',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _uiSettingsStream(),
      builder: (context, snapshot) {
        // افتراضيات
        bool isRTL = true;
        Locale locale = const Locale('ar');

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() ?? {};
          debugPrint('UI settings from Firestore: $data'); // طباعة للتأكد
          if (data.containsKey('isRTL')) {
            isRTL = data['isRTL'] == true;
          }
          if (data.containsKey('locale')) {
            final loc = data['locale']?.toString();
            if (loc != null && loc.isNotEmpty) locale = Locale(loc);
          }
        } else {
          debugPrint('UI settings snapshot has no data or does not exist yet.');
        }

        return MaterialApp(
          title: 'Rhlaa App',
          debugShowCheckedModeBanner: false,
          theme: AppThemeFactory.light(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar'), Locale('en')],
          locale: locale,
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            // إذا أردت إجبار RTL عند locale عربي
            if (locale.languageCode == 'ar') return const Locale('ar');
            return deviceLocale;
          },
          routes: _buildRoutes(),
          home: const AuthWrapper(),
          // لا تضع Directionality يدوياً هنا — Flutter يحدد الاتجاه من الـ locale.
          builder: (context, child) {
            // طباعة حالة الاتجاه الفعلية بعد بناء الـ MaterialApp
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                final dir = Directionality.of(context);
                debugPrint('Effective Directionality after MaterialApp build: $dir');
              } catch (_) {}
            });
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}}
