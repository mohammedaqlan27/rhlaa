// lib/widgets/web_transactions_table.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/theme/app_colors.dart';

class WebTransactionsTable extends StatelessWidget {
  final String agencyId;
  const WebTransactionsTable({super.key, required this.agencyId});

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
          const Text('سجل المعاملات المالية للمحفظة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('transactions').where('agencyId', isEqualTo: agencyId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('لا توجد معاملات مسجلة', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')));
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('رقم المعاملة', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('النوع', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('المبلغ', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('التاريخ', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                      DataColumn(label: Text('الحالة', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      bool isDeposit = data['type'] == 'deposit';
                      return DataRow(cells: [
                        DataCell(Text(doc.id.substring(0, 6), style: const TextStyle(color: Colors.white))),
                        DataCell(Text(isDeposit ? 'إيداع رصيد' : 'سحب / عمولة', style: TextStyle(color: isDeposit ? Colors.green : Colors.orange, fontFamily: 'Cairo'))),
                        DataCell(Text('${data['amount']} ر.ي', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataCell(Text(data['date'] ?? '-', style: const TextStyle(color: Colors.white70))),
                        DataCell(Text(data['status'] ?? 'مكتملة', style: const TextStyle(color: Colors.greenAccent))),
                      ]);
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
