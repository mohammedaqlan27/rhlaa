// lib/screens/trip_search_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/trip_provider.dart';
import '../models/trip.dart';
import '../utils/constants.dart';
import '../widgets/Passenger/trip_card.dart';
import '../widgets/shared/app_card.dart';
import '../widgets/shared/custom_button.dart';
import 'trip_details_screen.dart';
import '../theme/app_colors.dart' hide AppConstants;

class TripSearchScreen extends StatefulWidget {
  const TripSearchScreen({super.key});

  @override
  State<TripSearchScreen> createState() => _TripSearchScreenState();
}

class _TripSearchScreenState extends State<TripSearchScreen> {
  String? _selectedTripCategory;
  String? _selectedDestination;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    // جلب الرحلات عند فتح الشاشة لضمان تحديث البيانات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripProvider>(context, listen: false).fetchAvailableTrips();
    });
  }

  void _handleSearch() {
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ يرجى تحديد الوجهة للبدء بالبحث',
            style: TextStyle(fontFamily: AppFonts.arabic),
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() => _hasSearched = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'ابحث عن رحلتك',
          style: TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          _buildSearchForm(),
          Expanded(
            child: _hasSearched ? _buildSearchResults() : _buildSearchPlaceholder(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchForm() {
    // 1. استخراج جميع المدن الخارجية من الخريطة (Map) وتحويلها لقائمة (List)
    final List<String> allExternalCities = AppConstants.externalDestinations.values
        .expand((cities) => cities)
        .toList();

    // 2. دمج جميع الوجهات (استخدام yemenGovernorates بدلاً من internalDestinations)
    final List<String> allDestinations = [
      ...AppConstants.yemenGovernorates,
      ...allExternalCities
    ];

    // 3. تحديد ما سيظهر في القائمة بناءً على الفئة المختارة
    List<String> currentDestinations = allDestinations;
    if (_selectedTripCategory == 'داخلية') {
      currentDestinations = AppConstants.yemenGovernorates;
    } else if (_selectedTripCategory == 'خارجية') {
      currentDestinations = allExternalCities;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // اختيار الفئة
              Expanded(
                child: _buildDropdown(
                  label: 'الفئة (اختياري)',
                  icon: Icons.category,
                  items: AppConstants.tripCategories,
                  value: _selectedTripCategory,
                  onChanged: (val) {
                    setState(() {
                      _selectedTripCategory = val;
                      _selectedDestination = null; // إعادة تعيين الوجهة عند تغيير الفئة
                      _hasSearched = false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              // اختيار الوجهة
              Expanded(
                child: _buildDropdown(
                  label: 'الوجهة',
                  icon: Icons.location_on,
                  items: currentDestinations,
                  value: _selectedDestination,
                  onChanged: (val) {
                    setState(() {
                      _selectedDestination = val;
                      _hasSearched = false;

                      // ذكاء اصطناعي بسيط: تحديد الفئة تلقائياً بناءً على المدينة المختارة
                      if (val != null) {
                        if (AppConstants.yemenGovernorates.contains(val)) {
                          _selectedTripCategory = 'داخلية';
                        } else if (allExternalCities.contains(val)) {
                          _selectedTripCategory = 'خارجية';
                        }
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CustomButton(
            onPressed: _handleSearch,
            text: 'بحث عن الرحلات المتاحة',
            icon: Icons.search,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    // التأكد من أن العناصر فريدة ومرتبة أبجدياً
    final List<String> uniqueSorted = items.toSet().toList()..sort((a, b) => a.compareTo(b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.arabic,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: uniqueSorted.contains(value) ? value : null,
              hint: const Text('اختر', style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 13)),
              items: uniqueSorted
                  .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 13)),
              ))
                  .toList(),
              onChanged: onChanged,
              icon: Icon(icon, size: 18, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        // فلترة النتائج بناءً على المدخلات
        final results = provider.availableTrips.where((trip) {
          final matchDest = trip.destination.trim() == _selectedDestination?.trim();
          final matchCat = _selectedTripCategory == null || trip.tripCategory == _selectedTripCategory;
          return matchCat && matchDest;
        }).toList();

        if (results.isEmpty) {
          return _buildNoResults();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => TripCard(
            trip: results[index],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: results[index])),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.travel_explore, size: 100, color: AppColors.primary.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          const Text(
            'حدد الوجهة مباشرة وابدأ البحث',
            style: TextStyle(
              fontFamily: AppFonts.arabic,
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sentiment_dissatisfied, size: 60, color: AppColors.warning),
          const SizedBox(height: 16),
          const Text(
            'لا توجد رحلات مطابقة حالياً',
            style: TextStyle(
              fontFamily: AppFonts.arabic,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _hasSearched = false),
            child: const Text(
              'تغيير خيارات البحث',
              style: TextStyle(fontFamily: AppFonts.arabic, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}