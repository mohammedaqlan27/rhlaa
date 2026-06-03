// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import 'edit_profile_screen.dart';
import 'my_bookings_screen.dart';
import 'driver_trips_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<AppUser?> _fetchUserData(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return AppUser.fromDocument(doc);
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('❌ يجب تسجيل الدخول لعرض الملف الشخصي')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: FutureBuilder<AppUser?>(
        future: _fetchUserData(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('جاري تحميل البيانات...', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('❌ حدث خطأ أثناء تحميل البيانات: ${snapshot.error}'));
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('تعذر تحميل بيانات المستخدم أو المستخدم غير موجود.'));
          }

          final ratingText = (user.averageRating ?? 0.0).toStringAsFixed(1);
          final createdAt = user.createdAt != null
              ? DateFormat('yyyy-MM-dd – HH:mm').format(user.createdAt!.toDate())
              : 'غير متوفر';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                            ? NetworkImage(user.profilePictureUrl!)
                            : null,
                        child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text('مرحبًا ${user.nickname ?? ''} 👋',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: Text(user.email ?? '-'),
                    ),
                    if (user.mobileNumber != null && user.mobileNumber!.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.phone),
                        title: Text(user.mobileNumber!),
                      ),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text('الدور: ${user.userType ?? '-'}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.star),
                      title: Text('التقييم: $ratingText'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text('تاريخ التسجيل: $createdAt'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('تعديل الملف الشخصي'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (user.userType == 'Passenger')
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
                        },
                        icon: const Icon(Icons.list_alt),
                        label: const Text('رحلاتي'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade900,
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    if (user.userType == 'Driver')
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverTripsScreen()));
                        },
                        icon: const Icon(Icons.directions_car),
                        label: const Text('إدارة الرحلات'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('تسجيل الخروج'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
