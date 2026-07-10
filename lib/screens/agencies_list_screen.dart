// lib/screens/agencies_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/agencies_provider.dart';
import 'agency_form_screen.dart';
import '../models/agency.dart';

class AgenciesListScreen extends StatefulWidget {
  const AgenciesListScreen({Key? key}) : super(key: key);

  @override
  State<AgenciesListScreen> createState() => _AgenciesListScreenState();
}

class _AgenciesListScreenState extends State<AgenciesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AgenciesProvider>(context, listen: false).loadAgencies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AgenciesProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة المكاتب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : () => provider.loadAgencies(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const AgencyFormScreen()),
              );
              if (created == true) provider.loadAgencies();
            },
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
          ? Center(child: Text(provider.error!))
          : provider.agencies.isEmpty
          ? const Center(child: Text('لا توجد مكاتب بعد'))
          : RefreshIndicator(
        onRefresh: () => provider.loadAgencies(),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: provider.agencies.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final Agency a = provider.agencies[i];
            return Card(
              child: ListTile(
                title: Text(a.agencyName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المدير: ${a.managerName}'),
                    Text('الهاتف: ${a.mobileNumber}'),
                    Text('الرصيد: ${a.walletBalance.toStringAsFixed(2)}'),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final updated = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => AgencyFormScreen(agency: a),
                        ),
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
                      // افتح شاشة التفاصيل
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AgencyDetailScreen(agencyId: a.id)),
                      );
                    } else if (value == 'set_location') {
                      // افتح شاشة تعيين الموقع مباشرة
                      Navigator.of(context).pushNamed('/agency_edit_location', arguments: a.id);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'details', child: Text('تفاصيل')),
                    const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(value: 'toggle', child: Text(a.isActive ? 'تعطيل' : 'تفعيل')),
                    const PopupMenuItem(value: 'credit', child: Text('شحن رصيد')),
                    const PopupMenuItem(value: 'set_location', child: Text('تعيين الموقع')),
                    const PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
              ),
            );
          },
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
        title: Text('شحن رصيد ${agency.agencyName}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'المبلغ'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'أدخل مبلغاً صالحاً';
              final parsed = double.tryParse(v);
              if (parsed == null || parsed <= 0) return 'أدخل مبلغ أكبر من صفر';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final amount = double.parse(ctrl.text.trim());
              Navigator.of(context).pop();
              await provider.creditAgencyWallet(agency.id, amount, performedBy: 'admin');
            },
            child: const Text('شحن'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا المكتب؟ لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('حذف')),
        ],
      ),
    );
  }
}
