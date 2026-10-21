// lib/widgets/trip_filter_sheet.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../shared/app_card.dart';
import '../shared/custom_button.dart';
import '../../models/filter_result.dart';

class TripFilterSheet extends StatefulWidget {
  final List<String> internalDestinations;
  final List<String> externalDestinations;

  const TripFilterSheet({
    super.key,
    required this.internalDestinations,
    required this.externalDestinations,
  });

  @override
  State<TripFilterSheet> createState() => _TripFilterSheetState();
}

class _TripFilterSheetState extends State<TripFilterSheet> {
  bool _showActiveOnly = true;
  RangeValues _priceRange = const RangeValues(1000, 50000);
  String _selectedVehicle = 'الكل';
  final List<String> _vehicles = ['الكل', 'سيدان', 'دفع رباعي', 'باص'];
  bool _onlyDirect = false;

  // فلترة من/إلى و اتجاه الرحلة
  String? _direction; // 'local' | 'outbound' | 'inbound'
  String? _from;
  String? _to;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;

    // خيارات من/إلى تعتمد على اختيار الفئة أو الاتجاه
    List<String> fromOptions = [...widget.internalDestinations, ...widget.externalDestinations];
    List<String> toOptions = fromOptions;

    return SafeArea(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: surfaceColor.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.32),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'تصفية النتائج',
                        style: TextStyle(
                          fontFamily: AppFonts.arabic,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _showActiveOnly = true;
                          _priceRange = const RangeValues(1000, 50000);
                          _selectedVehicle = 'الكل';
                          _onlyDirect = false;
                          _direction = null;
                          _from = null;
                          _to = null;
                        });
                      },
                      child: const Text('إعادة ضبط'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Direction chips
                _buildFilterSection(
                  title: 'اتجاه الرحلة',
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('محلية'),
                        selected: _direction == 'local',
                        onSelected: (_) => setState(() => _direction = 'local'),
                      ),
                      ChoiceChip(
                        label: const Text('من داخل إلى خارج'),
                        selected: _direction == 'outbound',
                        onSelected: (_) => setState(() => _direction = 'outbound'),
                      ),
                      ChoiceChip(
                        label: const Text('من خارج إلى داخل'),
                        selected: _direction == 'inbound',
                        onSelected: (_) => setState(() => _direction = 'inbound'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // From / To dropdowns
                _buildFilterSection(
                  title: 'من',
                  child: _buildDropdown(
                    hint: 'اختر نقطة الانطلاق',
                    items: fromOptions,
                    value: _from,
                    onChanged: (v) => setState(() => _from = v),
                  ),
                ),

                const SizedBox(height: 12),

                _buildFilterSection(
                  title: 'إلى',
                  child: _buildDropdown(
                    hint: 'اختر الوجهة',
                    items: toOptions,
                    value: _to,
                    onChanged: (v) => setState(() => _to = v),
                  ),
                ),

                const SizedBox(height: 12),

                // الحالة
                _buildFilterSection(
                  title: 'الحالة',
                  child: AppCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('عرض الرحلات النشطة فقط', style: TextStyle(fontSize: 14, fontFamily: AppFonts.arabic)),
                        Semantics(
                          container: true,
                          label: 'تبديل عرض الرحلات النشطة فقط',
                          child: Switch.adaptive(
                            value: _showActiveOnly,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _showActiveOnly = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // نطاق السعر
                _buildFilterSection(
                  title: 'نطاق السعر (ر.ي)',
                  child: Column(
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
                        onChanged: (values) => setState(() => _priceRange = values),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_priceRange.start.round()} ر.ي', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: AppFonts.arabic)),
                          Text('${_priceRange.end.round()} ر.ي', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: AppFonts.arabic)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // نوع المركبة
                _buildFilterSection(
                  title: 'نوع المركبة',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _vehicles.map((v) {
                      final isSelected = _selectedVehicle == v;
                      return ChoiceChip(
                        label: Text(v, style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 13)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedVehicle = v);
                          }
                        },
                        selectedColor: AppColors.primary,
                        backgroundColor: Theme.of(context).cardColor,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),

                // خيارات إضافية
                _buildFilterSection(
                  title: 'خيارات إضافية',
                  child: AppCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('رحلات مباشرة فقط', style: TextStyle(fontSize: 14, fontFamily: AppFonts.arabic)),
                        Switch.adaptive(
                          value: _onlyDirect,
                          activeColor: AppColors.primary,
                          onChanged: (v) => setState(() => _onlyDirect = v),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // أزرار الإلغاء والتطبيق
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop(null);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.gray200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('إلغاء', style: TextStyle(fontFamily: AppFonts.arabic)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: 'تطبيق الفلاتر',
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          final result = FilterResult(
                            activeOnly: _showActiveOnly,
                            priceStart: _priceRange.start,
                            priceEnd: _priceRange.end,
                            vehicle: _selectedVehicle,
                            onlyDirect: _onlyDirect,
                            direction: _direction,
                            from: _from,
                            to: _to,
                          );
                          Navigator.pop(context, result);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildDropdown({required String hint, required List<String> items, String? value, required ValueChanged<String?> onChanged}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            hint: Text(hint, style: const TextStyle(fontFamily: AppFonts.arabic)),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: AppFonts.arabic)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
