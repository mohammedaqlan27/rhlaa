import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';

class AgenciesTable extends StatelessWidget {
  final bool isPendingOnly; // إذا كان true يعرض الطلبات المعلقة فقط، وإذا false يعرض كل الوكالات
  final Function(String docId, String agencyName) onAccept;
  final Function(String docId, String agencyName) onReject;

  const AgenciesTable({
    super.key,
    this.isPendingOnly = false,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firestore = FirebaseFirestore.instance;

    // بناء الاستعلام بناءً على ما إذا كانت الشاشة للطلبات المعلقة أم للإدارة الشاملة
    final query = isPendingOnly
        ? firestore.collection('agencies').where('isActive', isEqualTo: false)
        : firestore.collection('agencies');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                isPendingOnly ? 'لا توجد طلبات انضمام معلقة حالياً' : 'لا توجد وكالات مسجلة في النظام',
                style: TextStyle(
                  fontFamily: AppFonts.arabic,
                  fontSize: 14,
                  color: isDark ? AppColors.gray500 : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.gray100 : AppColors.gray200,
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppColors.gray900 : AppColors.gray100,
              ),
              columns: [
                DataColumn(
                  label: Text('اسم المكتب / الوكالة',
                      style: TextStyle(
                          fontFamily: AppFonts.arabic,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary)),
                ),
                DataColumn(
                  label: Text('رقم الترخيص',
                      style: TextStyle(
                          fontFamily: AppFonts.arabic,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary)),
                ),
                DataColumn(
                  label: Text('الحالة',
                      style: TextStyle(
                          fontFamily: AppFonts.arabic,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary)),
                ),
                DataColumn(
                  label: Text('الإجراءات',
                      style: TextStyle(
                          fontFamily: AppFonts.arabic,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary)),
                ),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final agencyName = data['agencyName'] ?? 'مكتب غير معروف';
                final licenseNumber = data['licenseNumber'] ?? '--';
                final isActive = data['isActive'] ?? false;

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        agencyName,
                        style: TextStyle(
                          fontFamily: AppFonts.arabic,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        licenseNumber,
                        style: TextStyle(
                          fontFamily: AppFonts.arabic,
                          color: isDark ? AppColors.gray400 : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isActive ? 'نشط' : 'قيد الانتظار',
                          style: TextStyle(
                            fontFamily: AppFonts.arabic,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isActive ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isActive) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('قبول', style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 12)),
                              onPressed: () => onAccept(doc.id, agencyName),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('رفض', style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 12)),
                              onPressed: () => onReject(doc.id, agencyName),
                            ),
                          ] else ...[
                            Text(
                              'لا توجد إجراءات مطلوبة',
                              style: TextStyle(
                                fontFamily: AppFonts.arabic,
                                fontSize: 12,
                                color: isDark ? AppColors.gray500 : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}