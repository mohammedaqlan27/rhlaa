import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../state/auth_state.dart'; // استيراد حالة تسجيل الدخول لجلب رقم السائق
import '../models/trip.dart';
import 'edit_trip_screen.dart';

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  @override
  void initState() {
    super.initState();
    // جلب الرحلات عند فتح الشاشة مع تمرير رقم السائق الحالي
    Future.microtask(() {
      final authState = context.read<AuthState>();
      final driverId = authState.userId; // جلب رقم السائق من الـ AuthState

      if (driverId != null) {
        context.read<TripProvider>().fetchDriverTrips(driverId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();

    // ملاحظة: إذا كان اسم القائمة في TripProvider ليس driverTrips
    // تأكد من تغييره للاسم الصحيح الموجود في ملف الـ Provider لديك
    final List<Trip> tripsList = tripProvider.driverTrips;

    return Scaffold(
      appBar: AppBar(
        title: const Text('رحلاتي المجدولة'),
        centerTitle: true,
      ),
      body: tripProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : tripsList.isEmpty
          ? const Center(child: Text('لا توجد رحلات مجدولة حالياً'))
          : ListView.builder(
        itemCount: tripsList.length,
        itemBuilder: (context, index) {
          final trip = tripsList[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              title: Text(trip.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${trip.origin} ➔ ${trip.destination}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${trip.price} ر.ي', style: const TextStyle(color: Colors.green)),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditTripScreen(
                            tripId: trip.id,
                            trip: trip,
                          ),
                        ),
                      ).then((_) {
                        // إعادة تحديث القائمة بعد العودة من شاشة التعديل
                        final driverId = context.read<AuthState>().userId;
                        if (driverId != null) {
                          context.read<TripProvider>().fetchDriverTrips(driverId);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}