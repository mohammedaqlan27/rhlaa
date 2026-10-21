// lib/screens/agencies_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/agencies_provider.dart';
import 'agency_form_screen.dart';
import '../../models/agency.dart';
import 'agency_detail_screen.dart';

class AgenciesListScreen extends StatefulWidget {
  const AgenciesListScreen({super.key});

  @override
  State<AgenciesListScreen> createState() => _AgenciesListScreenState();
}

class _AgenciesListScreenState extends State<AgenciesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _bgGrey = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AgenciesProvider>(context, listen: false).loadAgencies();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AgenciesProvider>(context);

    // تصفية القائمة بحسب البحث
    final filteredAgencies = provider.agencies.where((a) {
      final nameMatches = a.agencyName.toLowerCase().contains(_searchQuery.toLowerCase());
      final managerMatches = a.managerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final phoneMatches = a.mobileNumber.contains(_searchQuery);
      return nameMatches || managerMatches || phoneMatches;
    }).toList();

    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'قائمة المكاتب والوكالات',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _textDark, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _primaryBlue),
            onPressed: provider.isLoading ? null : () => provider.loadAgencies(),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: _primaryBlue),
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const AgencyFormScreen()),
              );
              if (created == true) provider.loadAgencies();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث السريع
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'ابحث باسم المكتب، المدير أو الهاتف...',
                hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: _primaryBlue),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: _bgGrey,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
                : provider.error != null
                ? Center(child: Text(provider.error!, style: const TextStyle(fontFamily: 'Cairo', color: Colors.red)))
                : filteredAgencies.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isEmpty ? 'لا توجد مكاتب بعد' : 'لا توجد نتائج مطابقة للبحث',
                    style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              color: _primaryBlue,
              onRefresh: () => provider.loadAgencies(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filteredAgencies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final Agency a = filteredAgencies[i];
                  return _buildAgencyCard(context, provider, a);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgencyCard(BuildContext context, AgenciesProvider provider, Agency a) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: a.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
          child: Icon(
            a.isActive ? Icons.storefront : Icons.store_mall_directory_outlined,
            color: a.isActive ? Colors.green : Colors.red,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                a.agencyName,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: _textDark),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: a.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                a.isActive ? 'مفعل' : 'معطل',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold, color: a.isActive ? Colors.green : Colors.red),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('المدير: ${a.managerName}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('الهاتف: ${a.mobileNumber}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 14, color: _primaryBlue),
                const SizedBox(width: 4),
                Text(
                  'الرصيد: ${a.walletBalance.toStringAsFixed(2)} ر.ي',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: _primaryBlue),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (value) async {
            if (value == 'edit') {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => AgencyFormScreen(agency: a)),
              );
              if (updated == true) provider.loadAgencies();
            } else if (value == 'toggle') {
              await provider.setAgencyActive(a.id, !a.isActive);
            } else if (value == 'credit') {
              _showWalletDialog(context, provider, a);
            } else if (value == 'delete') {
              final ok = await _confirmDelete(context);
              if (ok == true) {
                await provider.deleteAgency(a.id);
              }
            } else if (value == 'details') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AgencyDetailScreen(agencyId: a.id)),
              );
            } else if (value == 'set_location') {
              Navigator.of(context).pushNamed('/agency_edit_location', arguments: a.id);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'details', child: Row(children: [Icon(Icons.info_outline, size: 18), SizedBox(width: 8), Text('تفاصيل', style: TextStyle(fontFamily: 'Cairo'))])),
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('تعديل', style: TextStyle(fontFamily: 'Cairo'))])),
            PopupMenuItem(value: 'toggle', child: Row(children: [Icon(a.isActive ? Icons.block : Icons.check_circle_outline, size: 18), const SizedBox(width: 8), Text(a.isActive ? 'تعطيل' : 'تفعيل', style: const TextStyle(fontFamily: 'Cairo'))])),
            const PopupMenuItem(value: 'credit', child: Row(children: [Icon(Icons.add_card, size: 18), SizedBox(width: 8), Text('شحن رصيد', style: TextStyle(fontFamily: 'Cairo'))])),
            const PopupMenuItem(value: 'set_location', child: Row(children: [Icon(Icons.map_outlined, size: 18), SizedBox(width: 8), Text('تعيين الموقع', style: TextStyle(fontFamily: 'Cairo'))])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.red))])),
          ],
        ),
      ),
    );
  }

  Future<void> _showWalletDialog(BuildContext context, AgenciesProvider provider, Agency agency) async {
    final TextEditingController ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('شحن رصيد ${agency.agencyName}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'المبلغ (ر.ي)',
              labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'أدخل مبلغاً صالحاً';
              final parsed = double.tryParse(v);
              if (parsed == null || parsed <= 0) return 'أدخل مبلغ أكبر من صفر';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final amount = double.parse(ctrl.text.trim());
              Navigator.of(context).pop();
              await provider.creditAgencyWallet(agency.id, amount, performedBy: 'admin');
            },
            child: const Text('شحن', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من حذف هذا المكتب؟ لا يمكن التراجع عن هذه العملية.', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }
}