// lib/screens/vehicle_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/vehicle_selection_screen.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle.dart';

class VehicleScreen extends StatelessWidget {
  final String driverId;

  const VehicleScreen({Key? key, required this.driverId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final vehicleProv = context.watch<VehicleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة المركبات',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E70B8),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => vehicleProv.fetchDriverVehicles(driverId),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: vehicleProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vehicleProv.vehicles.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: vehicleProv.vehicles.length,
        itemBuilder: (ctx, i) {
          final v = vehicleProv.vehicles[i];
          final isSelected = vehicleProv.selectedVehicle?.id == v.id;
          return _vehicleCard(context, v, isSelected, vehicleProv);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVehicleDialog(context, vehicleProv),
        backgroundColor: const Color(0xFF17A5A3),
        icon: const Icon(Icons.add),
        label: const Text(
          'إضافة مركبة جديدة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _vehicleCard(BuildContext context, Vehicle v, bool isSelected,
      VehicleProvider provider) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.directions_car,
            color: isSelected ? Colors.blue : Colors.grey),
        title: Text(
          '${v.vehicleType ?? 'مركبة'} • ${v.plateNumber ?? '-'}',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        subtitle: Text(
          'ID: ${v.id}',
          style: const TextStyle(fontFamily: 'Cairo', color: Colors.black54),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'select') {
              provider.selectVehicleById(v.id);
            } else if (value == 'delete') {
              await provider.removeVehicle(v.id, ownerId: driverId);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'select', child: Text('تعيين كمركبة نشطة')),
            const PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.car_repair, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد مركبات مسجلة',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showAddVehicleDialog(BuildContext context, VehicleProvider provider) {
    final typeController = TextEditingController();
    final plateController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مركبة جديدة',
            style: TextStyle(fontFamily: 'Cairo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: typeController,
              decoration: const InputDecoration(
                  labelText: 'نوع المركبة', hintText: 'مثال: سيدان'),
            ),
            TextField(
              controller: plateController,
              decoration: const InputDecoration(
                  labelText: 'رقم اللوحة', hintText: 'مثال: 1234'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                typeController.dispose();
                plateController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final newVehicle = Vehicle(
                id: '',
                plateNumber: plateController.text.trim(),
                vehicleOwner: driverId,
                ownerId: driverId,
                driverId: driverId,
                driverName: null,
                vehicleType: typeController.text.trim(),
                makeModelYear: '',
                color: '',
                maxCapacity: 4,
                licenseNumber: '',
                isVerified: false,
                sGovernmentRegistered: false,
                notes: '',
                extra: null,
                vehicleDocuments: const [],
                insuranceExpiryDate: null,
                lastInspectionDate: null,
                carOwnerOfficialName: '',
                createdAt: Timestamp.now(),
                updatedAt: Timestamp.now(),
              );

              await provider.addVehicle(newVehicle);

              typeController.dispose();
              plateController.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
