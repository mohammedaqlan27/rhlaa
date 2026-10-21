// lib/screens/agency/agency_transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/agencies_provider.dart';
import '../../models/agency_transaction.dart';
import '/widgets/agency/web/web_transactions_table.dart';

class AgencyTransactionsScreen extends StatefulWidget {
  final String? agencyId;
  const AgencyTransactionsScreen({Key? key, this.agencyId}) : super(key: key);

  @override
  State<AgencyTransactionsScreen> createState() => _AgencyTransactionsScreenState();
}

class _AgencyTransactionsScreenState extends State<AgencyTransactionsScreen> {
  DateTime? _from;
  DateTime? _to;
  bool _loading = false;

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _to = d);
  }

  Future<void> _load() async {
    final prov = Provider.of<AgenciesProvider>(context, listen: false);
    final id = widget.agencyId ?? prov.currentAgency?.id;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد مكتب محدد')));
      return;
    }
    setState(() => _loading = true);
    await prov.loadTransactions(id, from: _from, to: _to);
    setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<AgenciesProvider>(context);
    final List<AgencyTransaction> list = prov.transactions;
    final id = widget.agencyId ?? prov.currentAgency?.id;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('سجل المعاملات')),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: id == null
              ? const Center(child: Text('لا يوجد مكتب محدد'))
              : LayoutBuilder(
            builder: (context, constraints) {
              // 🌐 إذا العرض واسع → جدول
              if (constraints.maxWidth > 850) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pickFrom,
                            child: Text(_from == null ? 'من تاريخ' : _from!.toLocal().toString().split(' ').first),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pickTo,
                            child: Text(_to == null ? 'إلى تاريخ' : _to!.toLocal().toString().split(' ').first),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(onPressed: _load, child: const Text('تطبيق')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: WebTransactionsTable(agencyId: id),
                    ),
                  ],
                );
              }

              // 📱 إذا العرض ضيق → بطاقات
              return _loading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                  ? const Center(child: Text('لا توجد معاملات'))
                  : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final t = list[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: ListTile(
                      leading: Icon(
                        t.type == 'credit' ? Icons.arrow_downward : Icons.arrow_upward,
                        color: t.type == 'credit' ? Colors.green : Colors.red,
                      ),
                      title: Text('${t.type.toUpperCase()} — ${t.amount.toStringAsFixed(2)}'),
                      subtitle: Text(t.reason ?? ''),
                      trailing: Text(
                        t.createdAt.toDate().toLocal().toString().split('.').first,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
