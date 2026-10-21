// lib/widgets/web_trips_table.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/theme/app_colors.dart';

class WebTripsTable extends StatelessWidget {
  final String agencyId;
  final Function(String tripId)? onEditTrip;
  final Function(String tripId)? onDeleteTrip;

  const WebTripsTable({
    super.key,
    required this.agencyId,
    this.onEditTrip,
    this.onDeleteTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF181B20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إدارة رحلات الوكالة والمسارات',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('إضافة رحلة جديدة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                onPressed: () {
                  // الانتقال لصفحة إضافة رحلة
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('trips')
                  .where('agencyId', isEqualTo: agencyId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('لا توجد رحلات مضافة حالياً', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFF222732)),
                    columns: const [
                      DataColumn(label: Text('عنوان الرحلة / المسار', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('خط الانطلاق والوصول', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('السعر', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('المقاعد المتبقية', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('الحالة', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('الإجراءات', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map;
                      final status = data['status'] ?? 'active';
                      return DataRow(
                        cells: [
                          DataCell(Text(data['title'] ?? 'رحلة بدون عنوان', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
                          DataCell(Text('${data['origin'] ?? ''} ➔ ${data['destination'] ?? ''}', style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'))),
                          DataCell(Text('${data['price'] ?? 0} ر.ي', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                          DataCell(Text('${data['availableSeats'] ?? 0} / ${data['totalSeats'] ?? 0}', style: const TextStyle(color: Colors.white))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (status == 'active' ? Colors.green : Colors.red).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(status == 'active' ? 'متاحة' : 'منتهية/ملغاة', style: TextStyle(color: status == 'active' ? Colors.green : Colors.red, fontSize: 11, fontFamily: 'Cairo')),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 18),
                                  onPressed: () => onEditTrip?.call(doc.id),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                  onPressed: () => onDeleteTrip?.call(doc.id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
