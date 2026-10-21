import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/agencies_provider.dart';
import '../../models/agency.dart';

// استدعاء الودجيت الجاهز
import '/widgets/agency/web/agency_wallet_card.dart';

class AgencyWalletScreen extends StatefulWidget {
  final String? agencyId;
  const AgencyWalletScreen({Key? key, this.agencyId}) : super(key: key);

  @override
  State<AgencyWalletScreen> createState() => _AgencyWalletScreenState();
}

class _AgencyWalletScreenState extends State<AgencyWalletScreen> {
  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<AgenciesProvider>(context);
    final agency = prov.currentAgency;
    final id = widget.agencyId ?? agency?.id;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('محفظة المكتب')),
        body: id == null
            ? const Center(child: Text('لا يوجد مكتب محدد'))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🟢 بطاقة المحفظة فقط
              AgencyWalletCard(
                balance: agency?.walletBalance ?? 0,
                onTopUp: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('فتح نافذة الإيداع أو السحب')),
                  );
                },
                onViewDetails: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('عرض تفاصيل المحفظة')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
