// lib/screens/auth_wrapper.dart
import 'package:flutter/material.dart';
import '../models/trip.dart';

// استيراد الشاشات المستخدمة للاختبار
import 'auth_screen.dart';
import 'loading_screen.dart';
import 'home_screen.dart';
import 'passenger_home_screen.dart' hide Trip;
import 'driver_home_screen.dart';
import 'create_trip_screen.dart';
import 'available_trips_screen.dart';
import 'trip_details_screen.dart';
import 'trip_details_view_screen.dart';
import 'my_bookings_screen.dart';
import 'rating_screen.dart';
import 'notification_screen.dart';
import 'payment_screen.dart';
import 'driver_bookings_screen.dart';
import 'driver_trips_screen.dart';
import 'driver_calendar_screen.dart';
import 'edit_profile_screen.dart';
import 'edit_trip_screen.dart';
import 'manage_trip_screen.dart';
import 'passenger_bookings_screen.dart';
import 'passenger_calendar_screen.dart';
import 'profile_screen.dart';
import 'trip_history_screen.dart';
import 'trip_search_screen.dart';
import 'user_ratings_screen.dart';
import 'vehicle_selection_screen.dart';
import 'payment_confirmation_screen.dart';
import 'vehicle_screen.dart';

/// AuthWrapper مخصص للاختبار: يعرض قائمة شاشات يمكن فتحها للتأكد من عمل كل شاشة.
/// ملاحظة: هذا الملف للاختبار فقط — لا تتركه بهذا الشكل في بيئة الإنتاج.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const TestAllScreens();
  }
}

class TestAllScreens extends StatelessWidget {
  const TestAllScreens({super.key});

  @override
  Widget build(BuildContext context) {
    // بيانات Mock لاستخدامها في الشاشات التي تتطلب معطيات
    final mockTrip = Trip(
      id: 'mock-trip-id',
      title: 'رحلة تجريبية',
      origin: 'صنعاء',
      destination: 'عدن',
      departureTime: DateTime.now(),
      availableSeats: 3,
      totalSeats: 4,
      price: 25.0,
      status: 'مفعّلة',
      driverName: 'سائق تجريبي',
      vehicleType: 'سيارة سيدان',
      carPlateNumber: 'ABC-123',
      carOwnerOfficialName: 'معرض تجريبي',
    );

    return Scaffold(
      appBar: AppBar(title: const Text("اختبار جميع الصفحات")),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildTile(context, "Auth Screen", const AuthScreen()),
          _buildTile(context, "Loading Screen", const LoadingScreen()),
          _buildTile(context, "Home Screen", const HomeScreen()),
          _buildTile(context, "Passenger Home Screen", const PassengerHomeScreen()),
          _buildTile(context, "Driver Home Screen", const DriverHomeScreen()),
          _buildTile(context, "Create Trip Screen", const CreateTripScreen()),
          _buildTile(context, "Available Trips Screen", const AvailableTripsScreen(destination: 'TestDestination')),
          _buildTile(context, "Trip Details Screen", TripDetailsScreen(trip: mockTrip)),
          _buildTile(context, "Trip Details View Screen", TripDetailsViewScreen(tripData: {'id': mockTrip.id, 'title': mockTrip.title})),
          _buildTile(context, "My Bookings Screen", const MyBookingsScreen()),
          _buildTile(context, "Rating Screen", const RatingScreen()),
          _buildTile(context, "Notification Screen", const NotificationScreen()),
          _buildTile(context, "Payment Screen", const PaymentScreen(tripId: 'mock-trip-id', seatNumber: 1, bookingId: 'mock-booking-id')),
          _buildTile(context, "Driver Bookings Screen", const DriverBookingsScreen(tripId: 'mock-trip-id')),
          _buildTile(context, "Driver Trips Screen", const DriverTripsScreen()),
          // ملاحظة: بعض الشاشات قد لا تكون Widgets مباشرة أو قد تحتاج بيانات إضافية.
          // لتجنب استثناءات النوع، نفتح شاشة التقويم عبر مسار أو نعرض صفحة بديلة.
          _buildTile(context, "Calendar Screen (via route)", _routeLauncher('/calendar', context)),
          _buildTile(context, "Driver Calendar Screen", const DriverCalendarScreen()),
          _buildTile(context, "Edit Profile Screen", const EditProfileScreen()),
          _buildTile(context, "Edit Trip Screen", const EditTripScreen(tripId: 'mock-trip-id')),
          _buildTile(context, "Manage Trip Screen", const ManageTripScreen()),
          _buildTile(context, "Passenger Bookings Screen", const PassengerBookingsScreen()),
          _buildTile(context, "Passenger Calendar Screen", const PassengerCalendarScreen()),
          _buildTile(context, "Profile Screen", const ProfileScreen()),
          _buildTile(context, "Trip History Screen", const TripHistoryScreen()),
          _buildTile(context, "Trip Search Screen", const TripSearchScreen()),
          _buildTile(context, "User Ratings Screen", const UserRatingsScreen(userId: 'mock-user-id')),
          _buildTile(context, "Vehicle Selection Screen", const VehicleSelectionScreen()),
          _buildTile(
            context,
            "Payment Confirmation Screen",
            const PaymentConfirmationScreen(
              bookingId: 'mock-booking-id',
              transactionId: 'mock-transaction-id',
              amount: 100.0,
              paymentMethod: 'MockMethod',
            ),
          ),
          _buildTile(context, "Vehicle Screen", const VehicleScreen()),
        ],
      ),
    );
  }

  /// يبني ListTile يفتح الصفحة المعطاة عند الضغط.
  ListTile _buildTile(BuildContext context, String title, Widget page) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }

  /// في حال كانت الشاشة المطلوبة تُفتح عبر مسار (route) وليس ويدجت مباشرة،
  /// نستخدم هذه الدالة لبناء ويدجت وسيطة تقوم بالتوجيه عند الضغط.
  Widget _routeLauncher(String routeName, BuildContext context) {
    return Builder(
      builder: (ctx) {
        return ListTile(
          title: Text('افتح: $routeName'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () {
            // إذا كان المسار معرفًا في التطبيق، ننتقل إليه، وإلا نعرض رسالة.
            if (Navigator.canPop(ctx)) {
              // لا نريد pop هنا، فقط محاولة فتح المسار
            }
            try {
              Navigator.pushNamed(ctx, routeName);
            } catch (_) {
              // إذا لم يكن المسار معرفًا، نعرض صفحة بديلة بسيطة
              Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text('مسار: $routeName')),
                    body: Center(
                      child: Text('المسار "$routeName" غير معرف أو يحتاج بيانات إضافية.'),
                    ),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
