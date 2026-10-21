import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trip_provider.dart';
import '../state/auth_state.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import 'create_trip_screen.dart';
import 'edit_trip_screen.dart';
import 'trip_details_screen.dart';
import 'user_ratings_screen.dart';

class DriverTripsScreen extends StatefulWidget {
  final String? targetDriverId;

  const DriverTripsScreen({super.key, this.targetDriverId});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  final Color _goldMedal = const Color(0xFFFFB300);

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    Future.microtask(() {
      final authState = context.read<AuthState>();
      final effectiveId = widget.targetDriverId ?? authState.currentUser?.uid ?? '';
      if (effectiveId.isNotEmpty) {
        context.read<TripProvider>().fetchDriverTrips(effectiveId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final tripProvider = context.watch<TripProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentUserId = authState.currentUser?.uid ?? '';
    final bool isOwner = widget.targetDriverId == null || widget.targetDriverId == currentUserId;
    final List<Trip> trips = tripProvider.driverTrips;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
        floatingActionButton: isOwner
            ? FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTripScreen()),
          ).then((_) => _refreshData()),
          label: const Text(
            'إضافة رحلة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          icon: const Icon(Icons.add),
          backgroundColor: AppColors.primary,
        )
            : null,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildModernAppBar(isOwner),
            SliverToBoxAdapter(
              child: _buildDriverProfileHeader(isOwner, widget.targetDriverId ?? currentUserId),
            ),
            tripProvider.isLoading
                ? const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
                : trips.isEmpty
                ? _buildEmptyState()
                : SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildTripCard(trips[index], isOwner),
                  childCount: trips.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar(bool isOwner) {
    return SliverAppBar(
      expandedHeight: 100.0,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      centerTitle: true,
      title: Text(
        isOwner ? 'رحلاتي المجدولة' : 'رحلات الكابتن',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _refreshData,
        )
      ],
    );
  }

  Widget _buildDriverProfileHeader(bool isOwner, String driverId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.webCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Hero(
                tag: 'driver_avatar_$driverId',
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_rounded, size: 40, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'كابتن رحلاء المتميز',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => UserRatingsScreen(userId: driverId)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star_rounded, color: _goldMedal, size: 18),
                          const SizedBox(width: 4),
                          const Text('4.9', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Text(
                            ' (عرض التقييمات)',
                            style: TextStyle(color: AppColors.primary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_goldMedal, Colors.orange.shade700]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.workspace_premium, color: Colors.white, size: 20),
          Text(
            'سائق الشهر',
            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Trip trip, bool isOwner) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedTime = trip.departureTime != null
        ? DateFormat('yyyy-MM-dd | hh:mm a', 'ar').format(trip.departureTime!)
        : '--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.webCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip))),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip(trip.status ?? 'مجدولة'),
                  Text(
                    '${trip.price} ر.ي',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Column(
                    children: [
                      const Icon(Icons.radio_button_checked, size: 18, color: AppColors.primary),
                      Container(width: 2, height: 20, color: AppColors.gray500.withValues(alpha: 0.3)),
                      const Icon(Icons.location_on, size: 18, color: AppColors.error),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.origin,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          trip.destination,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: AppColors.gray500),
                      const SizedBox(width: 6),
                      Text(
                        formattedTime,
                        style: const TextStyle(color: AppColors.gray500, fontSize: 12),
                      ),
                    ],
                  ),
                  if (isOwner)
                    ElevatedButton.icon(
                      onPressed: () => _navigateToEdit(trip),
                      icon: const Icon(Icons.edit_square, size: 16),
                      label: const Text('تعديل', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _navigateToEdit(Trip trip) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditTripScreen(tripId: trip.id))).then((_) => _refreshData());
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_filled_outlined, size: 80, color: AppColors.gray500.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text(
              'لا توجد رحلات مجدولة حالياً',
              style: TextStyle(color: AppColors.gray500),
            ),
          ],
        ),
      ),
    );
  }
}

extension on AuthState {
  get currentUser => null;
}