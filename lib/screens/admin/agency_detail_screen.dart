// lib/screens/agency_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/agencies_provider.dart';
import '../../models/agency.dart';
import '../../models/agency_transaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgencyDetailScreen extends StatefulWidget {
  final String agencyId;
  const AgencyDetailScreen({super.key, required this.agencyId});

  @override
  State<AgencyDetailScreen> createState() => _AgencyDetailScreenState();
}

class _AgencyDetailScreenState extends State<AgencyDetailScreen> {
  GoogleMapController? _mapController;
  LatLng? _initialPosition;
  Set<Marker> _markers = {};

  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _bgGrey = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);

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
    if (_initialPosition != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition!, 14));
    }
  }

  void _processLocation(dynamic location) {
    LatLng? newPos;
    if (location is GeoPoint) {
      newPos = LatLng(location.latitude, location.longitude);
    } else if (location is Map) {
      final lat = location['latitude'] ?? location['lat'];
      final lng = location['longitude'] ?? location['lng'];
      if (lat != null && lng != null) {
        newPos = LatLng((lat as num).toDouble(), (lng as num).toDouble());
      }
    }

    if (newPos != null && newPos != _initialPosition) {
      setState(() {
        _initialPosition = newPos;
        _markers = {
          Marker(
            markerId: MarkerId('agency_${widget.agencyId}'),
            position: newPos!,
            infoWindow: const InfoWindow(title: 'موقع المكتب'),
          ),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AgenciesProvider>(context);
    final Agency? agency = provider.currentAgency;

    if (agency != null && agency.location != null) {
      // تحديث إحداثيات الخريطة بأمان
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processLocation(agency.location);
      });
    }

    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _primaryBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          agency?.agencyName ?? 'تفاصيل المكتب',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _textDark, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _primaryBlue),
            onPressed: () => provider.loadAgencyById(widget.agencyId),
          ),
        ],
      ),
      body: provider.isLoading && agency == null
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (agency != null) ...[
              // كارت تفاصيل المكتب
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          agency.agencyName,
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: _textDark),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: agency.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            agency.isActive ? 'مفعل' : 'معطل',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: agency.isActive ? Colors.green : Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text('المدير: ${agency.managerName}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text('الهاتف: ${agency.mobileNumber}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _primaryBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الرصيد الحالي:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: _textDark)),
                          Text(
                            '${agency.walletBalance.toStringAsFixed(2)} ر.ي',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: _primaryBlue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.add_card, color: Colors.white, size: 18),
                        label: const Text('شحن رصيد المكتب', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () => _showWalletDialog(context, provider, agency),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Text('موقع المكتب على الخريطة', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: _textDark)),
              const SizedBox(height: 8),

              // الخريطة
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200,
                  child: _initialPosition == null
                      ? Container(
                    color: Colors.white,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off_outlined, color: Colors.grey, size: 40),
                          SizedBox(height: 8),
                          Text('لم يتم تحديد موقع المكتب بعد', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                      : GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(target: _initialPosition!, zoom: 14),
                    markers: _markers,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Text('سجل المعاملات المالية', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: _textDark)),
              const SizedBox(height: 10),

              // سجل المعاملات
              _TransactionsList(transactions: provider.transactions),
            ] else if (provider.error != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text(provider.error!, style: const TextStyle(fontFamily: 'Cairo', color: Colors.red))),
              )
            ] else ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('لا توجد بيانات للمكتب', style: TextStyle(fontFamily: 'Cairo'))),
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
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
}

class _TransactionsList extends StatelessWidget {
  final List<AgencyTransaction> transactions;
  const _TransactionsList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('لا توجد معاملات مالية مسجلة بعد', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = transactions[i];
        final isCredit = t.type == 'credit';
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: isCredit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: isCredit ? Colors.green : Colors.red,
                size: 18,
              ),
            ),
            title: Text(
              '${isCredit ? 'إيداع / شحن' : 'سحب / خصم'} - ${t.amount.toStringAsFixed(2)} ر.ي',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: isCredit ? Colors.green[800] : Colors.red[800]),
            ),
            subtitle: Text(
              '${t.reason ?? 'عملية رصيد'} • المنفذ: ${t.performedBy ?? 'النظام'}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey),
            ),
            trailing: Text(
              (t.createdAt.toDate()).toLocal().toString().split('.').first.replaceAll(' ', '\n'),
              textAlign: TextAlign.end,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}