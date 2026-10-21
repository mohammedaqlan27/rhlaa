// lib/widgets/web_bookings_table.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WebBookingsTable extends StatelessWidget {
  final String agencyId;

  const WebBookingsTable({super.key, required this.agencyId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF181B20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الحجوزات الحالية للوكالة',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('agencyId', isEqualTo: agencyId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF17A5A3)));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('لا توجد حجوزات مسجلة حالياً', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFF222732)),
                    columns: const [
                      DataColumn(label: Text('رقم الحجز', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('اسم العميل', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('الرحلة', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('المقاعد', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('السعر الإجمالي', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('الحالة', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'مؤكد';
                      Color statusColor = status == 'مؤكد' ? Colors.green : (status == 'ملغى' ? Colors.red : Colors.orange);

                      return DataRow(
                        cells: [
                          DataCell(Text(doc.id.substring(0, 6), style: const TextStyle(color: Colors.white))),
                          DataCell(Text(data['passengerName'] ?? 'غير معروف', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'))),
                          DataCell(Text(data['tripTitle'] ?? 'رحلة', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'))),
                          DataCell(Text('${data['seatsCount'] ?? 1}', style: const TextStyle(color: Colors.white))),
                          DataCell(Text('${data['totalPrice'] ?? 0} ر.ي', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontFamily: 'Cairo')),
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