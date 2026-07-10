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
    final theme = Theme.of(context);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                const Text(
                  'يجب تسجيل الدخول لعرض الملف الشخصي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
      body: FutureBuilder<AppUser?>(
        future: _fetchUserData(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('جاري تحميل بياناتك...', style: theme.textTheme.bodyLarge),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  '❌ حدث خطأ أثناء تحميل البيانات: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('تعذر تحميل بيانات المستخدم.'));
          }

          final ratingText = (user.averageRating ?? 0.0).toStringAsFixed(1);
          final createdAt = user.createdAt != null
              ? DateFormat('yyyy-MM-dd').format(user.createdAt!.toDate())
              : 'غير متوفر';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Header Section (Avatar & Name)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.primary, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          backgroundImage: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                              ? NetworkImage(user.profilePictureUrl!)
                              : null,
                          child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                              ? Icon(Icons.person, size: 55, color: theme.colorScheme.onSurfaceVariant)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.nickname ?? 'مستخدم جديد',
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 18, color: Colors.amber.shade700),
                            const SizedBox(width: 4),
                            Text(
                              ratingText,
                              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Details & Actions Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Icon(Icons.email_outlined, color: theme.colorScheme.primary),
                                title: const Text('البريد الإلكتروني'),
                                subtitle: Text(user.email ?? '-'),
                              ),
                              if (user.mobileNumber != null && user.mobileNumber!.isNotEmpty) ...[
                                const Divider(indent: 16, endIndent: 16),
                                ListTile(
                                  leading: Icon(Icons.phone_android_outlined, color: theme.colorScheme.primary),
                                  title: const Text('رقم الهاتف'),
                                  subtitle: Text(user.mobileNumber!, style: const TextStyle(letterSpacing: 1)),
                                ),
                              ],
                              const Divider(indent: 16, endIndent: 16),
                              ListTile(
                                leading: Icon(Icons.badge_outlined, color: theme.colorScheme.primary),
                                title: const Text('نوع الحساب'),
                                subtitle: Text(user.userType == 'Driver' ? 'سائق' : 'راكب'),
                              ),
                              const Divider(indent: 16, endIndent: 16),
                              ListTile(
                                leading: Icon(Icons.calendar_today_outlined, color: theme.colorScheme.primary),
                                title: const Text('تاريخ الانضمام'),
                                subtitle: Text(createdAt),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('تعديل الملف الشخصي'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (user.userType == 'Passenger')
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
                          },
                          icon: const Icon(Icons.local_mall_outlined),
                          label: const Text('حجوزاتي ورحلاتي'),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.secondary,
                            foregroundColor: theme.colorScheme.onSecondary,
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),

                      if (user.userType == 'Driver')
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverTripsScreen()));
                          },
                          icon: const Icon(Icons.local_taxi_outlined),
                          label: const Text('إدارة الرحلات الخاصة بي'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),

                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('تسجيل الخروج'),
                              content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                                  child: const Text('خروج'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          }
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('تسجيل الخروج'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}