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

  // مجموعة الوجهات المحذوفة محلياً (إخفاء من القوائم دون تعديل AppConstants)
  final Set<String> _removedDestinations = {};

  @override
  void initState() {
    super.initState();
    // جلب الرحلات عند فتح الشاشة لضمان تحديث البيانات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripProvider>(context, listen: false).fetchAvailableTrips();
    });
  }

  void _handleSearch() {
    // إذا أردت السماح بالبحث بدون وجهة (عرض كل الرحلات حسب الفئة) قم بإزالة هذا الشرط
    if (_selectedDestination == null && _selectedTripCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ يرجى تحديد الوجهة أو الفئة للبدء بالبحث',
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
    // استخراج جميع المدن الخارجية من الخريطة (Map) وتحويلها لقائمة (List)
    final List<String> allExternalCities = AppConstants.externalDestinations.values
        .expand((cities) => cities)
        .toList();

    // دمج جميع الوجهات
    final List<String> allDestinations = [
      ...AppConstants.yemenGovernorates,
      ...allExternalCities
    ];

    // استبعاد الوجهات التي حُذفت محلياً
    final List<String> visibleDestinations = allDestinations
        .where((d) => !_removedDestinations.contains(d))
        .toList();

    // تحديد ما سيظهر في القائمة بناءً على الفئة المختارة
    List<String> currentDestinations = visibleDestinations;
    if (_selectedTripCategory == 'داخلية') {
      currentDestinations = AppConstants.yemenGovernorates
          .where((d) => !_removedDestinations.contains(d))
          .toList();
    } else if (_selectedTripCategory == 'خارجية') {
      currentDestinations = allExternalCities
          .where((d) => !_removedDestinations.contains(d))
          .toList();
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

                      // تحديد الفئة تلقائياً بناءً على المدينة المختارة
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
              const SizedBox(width: 8),
              // زر إدارة الوجهات (حذف/استعادة محلي)
              IconButton(
                tooltip: 'إدارة الوجهات',
                icon: const Icon(Icons.edit_location, size: 22),
                color: AppColors.primary,
                onPressed: _showManageDestinationsDialog,
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
        final selected = _selectedDestination?.trim();
        final results = provider.availableTrips.where((trip) {
          // افتراض أن Trip يحتوي على حقلي origin و destination
          final tripOrigin = (trip.origin ?? '').trim();
          final tripDest = (trip.destination ?? '').trim();

          // إذا تم تحديد وجهة، نطابقها مع origin أو destination (يدعم داخل→خارج و خارج→داخل)
          final matchDest = selected == null
              ? true // إذا لم تُحدد الوجهة، لا نقيّد بالوجهة
              : (tripDest == selected || tripOrigin == selected);

          // الفئة: إذا لم تُحدد الفئة نسمح بكل الفئات
          final matchCat = _selectedTripCategory == null || trip.tripCategory == _selectedTripCategory;

          // استبعاد الرحلات التي تتضمن وجهات محذوفة محلياً (إن رغبت بذلك)
          final tripUsesRemoved = _removedDestinations.contains(tripOrigin) || _removedDestinations.contains(tripDest);
          // هنا نختار ألا نعرض الرحلات التي تحتوي على وجهات محذوفة
          if (tripUsesRemoved) return false;

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

  // حوار لإدارة الوجهات (حذف محلي / استعادة)
  void _showManageDestinationsDialog() {
    final List<String> allExternalCities = AppConstants.externalDestinations.values
        .expand((cities) => cities)
        .toList();
    final List<String> allDestinations = [
      ...AppConstants.yemenGovernorates,
      ...allExternalCities
    ]..sort((a, b) => a.compareTo(b));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('إدارة الوجهات', style: TextStyle(fontFamily: AppFonts.arabic)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allDestinations.length,
                itemBuilder: (context, index) {
                  final dest = allDestinations[index];
                  final removed = _removedDestinations.contains(dest);
                  return ListTile(
                    title: Text(dest, style: const TextStyle(fontFamily: AppFonts.arabic)),
                    trailing: IconButton(
                      icon: Icon(removed ? Icons.restore : Icons.delete,
                          color: removed ? AppColors.primary : AppColors.warning),
                      onPressed: () {
                        setState(() {
                          if (removed) {
                            _removedDestinations.remove(dest);
                          } else {
                            _removedDestinations.add(dest);
                            // إذا كانت الوجهة المحذوفة هي المختارة حالياً، نلغي الاختيار
                            if (_selectedDestination == dest) {
                              _selectedDestination = null;
                            }
                          }
                        });
                        // نعيد بناء الـ dialog محلياً
                        setStateDialog(() {});
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق', style: TextStyle(fontFamily: AppFonts.arabic)),
              ),
            ],
          );
        });
      },
    );
  }
}
