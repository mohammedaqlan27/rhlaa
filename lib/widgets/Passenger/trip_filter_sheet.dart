// lib/widgets/trip_filter_sheet.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../shared/app_card.dart';
import '../shared/custom_button.dart';

class TripFilterSheet extends StatefulWidget {
  const TripFilterSheet({super.key});

  @override
  State<TripFilterSheet> createState() => _TripFilterSheetState();
}

class _TripFilterSheetState extends State<TripFilterSheet> {
  // متغيرات الحالة للفلترة
  bool _showActiveOnly = true;
  RangeValues _priceRange = const RangeValues(1000, 50000);
  String _selectedVehicle = 'الكل';

  final List<String> _vehicles = ['الكل', 'سيدان', 'دفع رباعي', 'باص'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark.withOpacity(0.9) : Colors.white.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // مقبض السحب
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // الرأس: العنوان وزر إعادة الضبط
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'تصفية النتائج',
                  style: TextStyle(
                    fontFamily: AppFonts.arabic,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _showActiveOnly = false;
                      _priceRange = const RangeValues(1000, 50000);
                      _selectedVehicle = 'الكل';
                    });
                  },
                  child: const Text('إعادة ضبط', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 1. خيار الرحلات النشطة
            _buildFilterSection(
              'الحالة',
              AppCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('عرض الرحلات النشطة فقط', style: TextStyle(fontSize: 14)),
                    Switch.adaptive(
                      value: _showActiveOnly,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _showActiveOnly = val);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 2. نطاق السعر (Slider)
            _buildFilterSection(
              'نطاق السعر (ريال يمني)',
              Column(
                children: [
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 100000,
                    divisions: 20,
                    activeColor: AppColors.primary,
                    labels: RangeLabels(
                      _priceRange.start.round().toString(),
                      _priceRange.end.round().toString(),
                    ),
                    onChanged: (values) {
                      setState(() => _priceRange = values);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_priceRange.start.round()} ر.ي', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text('${_priceRange.end.round()} ر.ي', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. نوع المركبة (Chips)
            _buildFilterSection(
              'نوع المركبة',
              Wrap(
                spacing: 8,
                children: _vehicles.map((v) {
                  final isSelected = _selectedVehicle == v;
                  return ChoiceChip(
                    label: Text(v),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedVehicle = v);
                      }
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontFamily: AppFonts.arabic,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            // زر التأكيد
            CustomButton(
              text: 'تطبيق الفلاتر',
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, {
                  'activeOnly': _showActiveOnly,
                  'priceRange': _priceRange,
                  'vehicle': _selectedVehicle,
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppFonts.arabic,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}