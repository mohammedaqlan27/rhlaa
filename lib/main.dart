import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// استيراد النماذج
import 'models/trip.dart';

// استيراد جميع الشاشات
import 'screens/auth_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/home_screen.dart';
import 'screens/passenger_home_screen.dart';
import 'screens/driver_home_screen.dart';
import 'screens/create_trip_screen.dart';
import 'screens/available_trips_screen.dart';
import 'screens/trip_details_screen.dart';
import 'screens/trip_details_view_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/driver_bookings_screen.dart';
import 'screens/driver_trips_screen.dart';
import 'screens/calendar_screen.dart' hide PassengerCalendarScreen;
import 'screens/driver_calendar_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/edit_trip_screen.dart';
import 'screens/manage_trip_screen.dart';
import 'screens/passenger_bookings_screen.dart';
import 'screens/passenger_calendar_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/trip_history_screen.dart';
import 'screens/trip_search_screen.dart';
import 'screens/user_ratings_screen.dart';
import 'screens/vehicle_selection_screen.dart';
import 'screens/auth_wrapper.dart';
import 'screens/payment_confirmation_screen.dart';
import 'screens/vehicle_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

/// هيكل بيانات صفحة للاختبار
class PageInfo {
  final String name;
  final WidgetBuilder builder;
  PageInfo({required this.name, required this.builder});
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentIndex = 0;

  // جميع الصفحات
  late final List<PageInfo> pages = [
    PageInfo(name: 'AuthScreen', builder: (_) => AuthScreen()),
    PageInfo(name: 'LoadingScreen', builder: (_) => LoadingScreen()),
    PageInfo(name: 'HomeScreen', builder: (_) => HomeScreen()),
    PageInfo(name: 'PassengerHomeScreen', builder: (_) => PassengerHomeScreen()),
    PageInfo(name: 'DriverHomeScreen', builder: (_) => DriverHomeScreen()),
    PageInfo(name: 'CreateTripScreen', builder: (_) => CreateTripScreen()),
    PageInfo(name: 'AvailableTripsScreen', builder: (_) => AvailableTripsScreen(destination: "TestDestination")),
    PageInfo(name: 'TripDetailsScreen', builder: (_) => TripDetailsScreen(trip: Trip(id: "1", title: "Mock Trip"))),
    PageInfo(name: 'TripDetailsViewScreen', builder: (_) => TripDetailsViewScreen(tripData: {"id": "1", "title": "Mock Trip"})),
    PageInfo(name: 'MyBookingsScreen', builder: (_) => MyBookingsScreen()),
    PageInfo(name: 'RatingScreen', builder: (_) => RatingScreen()),
    PageInfo(name: 'NotificationScreen', builder: (_) => NotificationScreen()),
    PageInfo(name: 'PaymentScreen', builder: (_) => PaymentScreen(tripId: "mock-trip-id", seatNumber: 1, bookingId: "mock-booking-id")),
    PageInfo(name: 'DriverBookingsScreen', builder: (_) => DriverBookingsScreen(tripId: "mock-trip-id")),
    PageInfo(name: 'DriverTripsScreen', builder: (_) => DriverTripsScreen()),
    PageInfo(name: 'DriverCalendarScreen', builder: (_) => DriverCalendarScreen()),
    PageInfo(name: 'EditProfileScreen', builder: (_) => EditProfileScreen()),
    PageInfo(name: 'EditTripScreen', builder: (_) => EditTripScreen(tripId: "mock-trip-id")),
    PageInfo(name: 'ManageTripScreen', builder: (_) => ManageTripScreen()),
    PageInfo(name: 'PassengerBookingsScreen', builder: (_) => PassengerBookingsScreen()),
    PageInfo(name: 'PassengerCalendarScreen', builder: (_) => PassengerCalendarScreen()),
    PageInfo(name: 'ProfileScreen', builder: (_) => ProfileScreen()),
    PageInfo(name: 'TripHistoryScreen', builder: (_) => TripHistoryScreen()),
    PageInfo(name: 'TripSearchScreen', builder: (_) => TripSearchScreen()),
    PageInfo(name: 'UserRatingsScreen', builder: (_) => UserRatingsScreen(userId: "mock-user-id")),
    PageInfo(name: 'VehicleSelectionScreen', builder: (_) => VehicleSelectionScreen()),
    PageInfo(name: 'AuthWrapper', builder: (_) => AuthWrapper()),
    PageInfo(name: 'PaymentConfirmationScreen', builder: (_) => PaymentConfirmationScreen(
      bookingId: "mock-booking-id",
      transactionId: "mock-transaction-id",
      amount: 100.0,
      paymentMethod: "MockMethod",
    )),
    PageInfo(name: 'VehicleScreen', builder: (_) => VehicleScreen()),
  ];

  void _nextPage() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % pages.length;
    });
  }

  void _previousPage() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + pages.length) % pages.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = pages[_currentIndex];
    return MaterialApp(
      title: 'Pages Tester',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: Scaffold(
        appBar: AppBar(
          title: Text('اختبار: ${currentPage.name}'),
          actions: [
            DropdownButton<int>(
              value: _currentIndex,
              underline: const SizedBox(),
              items: List.generate(
                pages.length,
                    (index) => DropdownMenuItem(
                  value: index,
                  child: Text(pages[index].name),
                ),
              ),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _currentIndex = value;
                  });
                }
              },
            ),
          ],
        ),
        body: currentPage.builder(context),
        bottomNavigationBar: BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(onPressed: _previousPage, icon: const Icon(Icons.navigate_before)),
              Text('${_currentIndex + 1} / ${pages.length}'),
              IconButton(onPressed: _nextPage, icon: const Icon(Icons.navigate_next)),
            ],
          ),
        ),
      ),
    );
  }
}
