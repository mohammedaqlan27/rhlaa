// lib/screens/vehicle_selection_screen.dart
import 'package:flutter/material.dart';

class VehicleSelectionScreen extends StatelessWidget {
  const VehicleSelectionScreen({super.key});

  // تعريف ثابت لأن القائمة لا تتغير
  static const List<Map<String, dynamic>> _vehicles = [
    {'title': 'سيدان', 'icon': Icons.directions_car},
    {'title': 'دفع رباعي', 'icon': Icons.airport_shuttle},
    {'title': 'فان', 'icon': Icons.directions_bus},
    {'title': 'شاحنة', 'icon': Icons.local_shipping},
  ];

  void _handleSelection(BuildContext context, String vehicleType) {
    // نعيد القيمة إلى الشاشة السابقة عند الحاجة
    Navigator.of(context).pop(vehicleType);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم اختيار: $vehicleType'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, String title, IconData icon) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _handleSelection(context, title),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 60, color: Colors.blue.shade900),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚘 اختيار المركبة'),
        backgroundColor: Colors.blue.shade900,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('أنواع المركبات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              itemCount: _vehicles.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) {
                final vehicle = _vehicles[index];
                return _buildVehicleCard(context, vehicle['title'] as String, vehicle['icon'] as IconData);
              },
            ),
          ),
        ]),
      ),
    );
  }
}
