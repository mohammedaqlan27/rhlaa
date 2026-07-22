// lib/screens/trip_search_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/trip_provider.dart';
import '../models/trip.dart';
import '../widgets/trip_card.dart';
import '../widgets/app_card.dart';
import '../widgets/custom_button.dart';
import 'trip_details_screen.dart';

import '../theme/app_colors.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripProvider>(context, listen: false).fetchAvailableTrips();
    });
  }

  void _handleSearch() {
    // الآن أصبح الشرط الوحيد للبحث هو تحديد الوجهة فقط
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ يرجى تحديد الوجهة للبدء بالبحث', style: TextStyle(fontFamily: AppFonts.arabic)),
          backgroundColor: AppColors.alertYellow,
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
        title: const Text('ابحث عن رحلتك', style: TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textDark,
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
    // 1. استخراج جميع المدن الخارجية من الخريطة وتحويلها إلى قائمة واحدة
    final List<String> allExternalCities = AppConstants.externalDestinations.values.expand((e) => e).toList();

    // 2. دمج جميع الوجهات (الداخلية والخارجية) معاً
    final List<String> allDestinations = [...AppConstants.internalDestinations, ...allExternalCities];

    // 3. تحديد ما سيظهر في قائمة الوجهة بناءً على اختيار الفئة
    List<String> currentDestinations = allDestinations;
    if (_selectedTripCategory == 'داخلية') {
      currentDestinations = AppConstants.internalDestinations;
    } else if (_selectedTripCategory == 'خارجية') {
      currentDestinations = allExternalCities;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // حقل الفئة (أصبح اختيارياً)
              Expanded(
                child: _buildDropdown(
                  label: 'الفئة (اختياري)',
                  icon: Icons.category,
                  items: AppConstants.tripCategories,
                  value: _selectedTripCategory,
                  onChanged: (val) {
                    setState(() {
                      _selectedTripCategory = val;
                      _selectedDestination = null; // مسح الوجهة السابقة لمنع التعارض
                      _hasSearched = false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),

              // حقل الوجهة (يمكن اختياره مباشرة)
              Expanded(
                child: _buildDropdown(
                  label: 'الوجهة (مباشرة)',
                  icon: Icons.location_on,
                  items: currentDestinations,
                  value: _selectedDestination,
                  onChanged: (val) {
                    setState(() {
                      _selectedDestination = val;
                      _hasSearched = false;

                      // الذكاء البرمجي: التحديد التلقائي للفئة بناءً على الوجهة
                      if (val != null) {
                        if (AppConstants.internalDestinations.contains(val)) {
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
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: Text('اختر', style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 13)),
              // إزالة التكرارات إن وجدت وترتيب العناصر
              items: items.toSet().map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 13)))).toList(),
              onChanged: onChanged,
              iconEnabledColor: AppColors.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));

        final results = provider.availableTrips.where((trip) {
          // الشرط الأساسي الوحيد الآن هو مطابقة الوجهة
          final matchDest = trip.destination.trim() == _selectedDestination?.trim();

          // إذا كان قد تم تحديد الفئة، نقوم بمطابقتها أيضاً
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: results[index]))),
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
          Icon(Icons.travel_explore, size: 100, color: AppColors.primaryBlue.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('حدد الوجهة مباشرة وابدأ البحث', style: TextStyle(fontFamily: AppFonts.arabic, color: AppColors.muted, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sentiment_dissatisfied, size: 60, color: AppColors.alertYellow),
          const SizedBox(height: 16),
          const Text('لا توجد رحلات مطابقة حالياً', style: TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _hasSearched = false),
            child: const Text('تغيير خيارات البحث', style: TextStyle(fontFamily: AppFonts.arabic, color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }
}