// lib/screens/vehicle_selection_screen.dart
import 'package:flutter/material.dart';
import '../widgets/shared/app_card.dart';
import '../widgets/shared/custom_button.dart';

class VehicleSelectionScreen extends StatefulWidget {
  final String? initialSelection;

  const VehicleSelectionScreen({super.key, this.initialSelection});

  @override
  State<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen> {
  String? _selectedType;

  // القائمة الثابتة مع الأيقونات الصحيحة المتناسقة
  static const List<Map<String, dynamic>> _vehicles = [
    {'title': 'سيارة سيدان', 'icon': Icons.directions_car_rounded, 'desc': 'صالون مريحة وعملية للمدن'},
    {'title': 'سيارة دفع رباعي', 'icon': Icons.airport_shuttle_rounded, 'desc': 'رحبة وقوية للمسافات البعيدة'},
    {'title': 'سيارة فان', 'icon': Icons.directions_bus_rounded, 'desc': 'عائلية ومناسبة للمجموعات الكبيرة'},
    {'title': 'شاحنة نقل', 'icon': Icons.local_shipping_rounded, 'desc': 'مخصصة لنقل الأمتعة والبضائع'},
  ];

  final Color _primaryColor = const Color(0xFF4A7DAB);
  final Color _backgroundColor = const Color(0xFFF4F7FA);

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialSelection;
  }

  void _confirmSelection() {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ يرجى تحديد نوع المركبة أولاً', style: TextStyle(fontFamily: 'Cairo')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(_selectedType);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم اختيار تفضيل: $_selectedType', style: const TextStyle(fontFamily: 'Cairo')),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildVehicleCard(String title, IconData icon, String desc) {
    final isSelected = _selectedType == title;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _primaryColor : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? _primaryColor.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.04),
            blurRadius: isSelected ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _selectedType = title;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 52,
                color: isSelected ? _primaryColor : Colors.grey.shade600,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  color: isSelected ? _primaryColor : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Cairo',
                  color: Colors.grey.shade500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('🚘 تفضيل نوع المركبة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اختر نوع السيارة المفضلة لرحلتك',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'سنقوم بفلترة وتصفية الرحلات بناءً على اختيارك لتوفير أقصى درجات الراحة لك.',
                    style: TextStyle(fontSize: 13, fontFamily: 'Cairo', color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _vehicles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final vehicle = _vehicles[index];
                  return _buildVehicleCard(
                    vehicle['title'] as String,
                    vehicle['icon'] as IconData,
                    vehicle['desc'] as String,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: CustomButton(
                onPressed: _confirmSelection,
                text: 'اعتماد نوع المركبة المختارة',
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}