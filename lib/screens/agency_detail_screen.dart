// lib/screens/agency_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/agencies_provider.dart';
import '../models/agency.dart';
import '../models/agency_transaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgencyDetailScreen extends StatefulWidget {
  final String agencyId;
  const AgencyDetailScreen({Key? key, required this.agencyId}) : super(key: key);

  @override
  State<AgencyDetailScreen> createState() => _AgencyDetailScreenState();
}

class _AgencyDetailScreenState extends State<AgencyDetailScreen> {
  GoogleMapController? _mapController;
  LatLng? _initialPosition;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AgenciesProvider>(context, listen: false);
      provider.loadAgencyById(widget.agencyId);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _updateMapLocation(dynamic location) {
    if (location == null) return;
    if (location is GeoPoint) {
      final pos = LatLng(location.latitude, location.longitude);
      setState(() {
        _initialPosition = pos;
        _markers = {
          Marker(markerId: MarkerId('agency_${widget.agencyId}'), position: pos),
        };
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 13));
    } else if (location is Map) {
      // إذا خزنت الموقع كخريطة تحتوي lat/lng
      final lat = location['latitude'] ?? location['lat'];
      final lng = location['longitude'] ?? location['lng'];
      if (lat != null && lng != null) {
        final pos = LatLng((lat as num).toDouble(), (lng as num).toDouble());
        setState(() {
          _initialPosition = pos;
          _markers = {
            Marker(markerId: MarkerId('agency_${widget.agencyId}'), position: pos),
          };
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 13));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AgenciesProvider>(context);
    final Agency? agency = provider.currentAgency;

    if (agency != null) {
      _updateMapLocation(agency.location);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(agency?.agencyName ?? 'تفاصيل المكتب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadAgencyById(widget.agencyId),
          ),
        ],
      ),
      body: provider.isLoading && agency == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (agency != null) ...[
              ListTile(
                title: Text(agency.agencyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('المدير: ${agency.managerName}'),
                trailing: Text('الرصيد: ${agency.walletBalance.toStringAsFixed(2)}'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('الهاتف: ${agency.mobileNumber}'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('الحالة: '),
                    Text(agency.isActive ? 'مفعل' : 'معطل', style: TextStyle(color: agency.isActive ? Colors.green : Colors.red)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: _initialPosition == null
                    ? Center(child: Text('لا يوجد موقع متاح للمكتب'))
                    : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(target: _initialPosition!, zoom: 13),
                  markers: _markers,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('شحن رصيد'),
                  onPressed: () => _showWalletDialog(context, provider, agency),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('سجل المعاملات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              _TransactionsList(transactions: provider.transactions),
            ] else if (provider.error != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(provider.error!, style: const TextStyle(color: Colors.red)),
              )
            ] else ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد بيانات للمكتب'),
              )
            ]
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
}

class _TransactionsList extends StatelessWidget {
  final List<AgencyTransaction> transactions;
  const _TransactionsList({Key? key, required this.transactions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('لا توجد معاملات بعد'),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final t = transactions[i];
        return ListTile(
          leading: Icon(t.type == 'credit' ? Icons.arrow_downward : Icons.arrow_upward, color: t.type == 'credit' ? Colors.green : Colors.red),
          title: Text('${t.type.toUpperCase()} - ${t.amount.toStringAsFixed(2)}'),
          subtitle: Text('${t.reason ?? ''} • ${t.performedBy ?? ''}'),
          trailing: Text(
            (t.createdAt.toDate()).toLocal().toString().split('.').first,
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }
}
