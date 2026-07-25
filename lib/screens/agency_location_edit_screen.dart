// lib/screens/agency_location_edit_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/agencies_provider.dart';
import '../models/agency.dart';

class AgencyLocationEditScreen extends StatefulWidget {
  final String agencyId;
  const AgencyLocationEditScreen({super.key, required this.agencyId});

  @override
  State<AgencyLocationEditScreen> createState() => _AgencyLocationEditScreenState();
}

class _AgencyLocationEditScreenState extends State<AgencyLocationEditScreen> {
  GoogleMapController? _mapController;
  LatLng? _pickedPosition;
  Set<Marker> _markers = {};
  bool _saving = false;
  bool _loading = true;
  Agency? _agency;

  @override
  void initState() {
    super.initState();
    _loadAgency();
  }

  Future<void> _loadAgency() async {
    final provider = Provider.of<AgenciesProvider>(context, listen: false);
    await provider.loadAgencyById(widget.agencyId);
    final a = provider.currentAgency;
    if (mounted) {
      setState(() {
        _agency = a;
        _loading = false;
      });
      if (a != null && a.location != null) {
        _setLocationFromDynamic(a.location);
      }
    }
  }

  void _setLocationFromDynamic(dynamic location) {
    if (location == null) return;
    if (location is GeoPoint) {
      final pos = LatLng(location.latitude, location.longitude);
      _updatePicked(pos);
    } else if (location is Map) {
      final lat = location['latitude'] ?? location['lat'];
      final lng = location['longitude'] ?? location['lng'];
      if (lat != null && lng != null) {
        final pos = LatLng((lat as num).toDouble(), (lng as num).toDouble());
        _updatePicked(pos);
      }
    }
  }

  void _updatePicked(LatLng pos) {
    setState(() {
      _pickedPosition = pos;
      _markers = {
        Marker(markerId: MarkerId('agency_${widget.agencyId}'), position: pos),
      };
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 14));
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_pickedPosition != null) {
      _mapController?.moveCamera(CameraUpdate.newLatLngZoom(_pickedPosition!, 14));
    }
  }

  void _onTap(LatLng pos) {
    _updatePicked(pos);
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // اطلب من المستخدم تفعيل خدمة الموقع
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تفعيل خدمة الموقع على جهازك')),
      );
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض إذن الموقع')),
        );
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('إذن الموقع مرفوض نهائياً. افتح إعدادات التطبيق لمنح الإذن.')),
      );
      return null;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      return pos;
    } catch (e) {
      debugPrint('Geolocator error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الحصول على الموقع الحالي')),
      );
      return null;
    }
  }

  Future<void> _useCurrentLocation() async {
    final pos = await _determinePosition();
    if (pos == null) return;
    final latLng = LatLng(pos.latitude, pos.longitude);
    _updatePicked(latLng);
  }

  Future<void> _saveLocation() async {
    if (_pickedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر موقعاً أولاً')));
      return;
    }
    setState(() => _saving = true);
    try {
      final provider = Provider.of<AgenciesProvider>(context, listen: false);
      final updates = <String, dynamic>{
        'location': GeoPoint(_pickedPosition!.latitude, _pickedPosition!.longitude),
        'updatedAt': Timestamp.now(),
      };
      final success = await provider.updateAgency(widget.agencyId, updates);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الموقع بنجاح')));
        await provider.loadAgencyById(widget.agencyId);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حفظ الموقع')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = _pickedPosition ?? const LatLng(15.3694, 44.1910); // مركز صنعاء تقريبي
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعيين موقع المكتب'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _saveLocation,
            icon: const Icon(Icons.save, color: Colors.white),
            label: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(target: initialCamera, zoom: 12),
              markers: _markers,
              onTap: _onTap,
              myLocationEnabled: false,
              zoomControlsEnabled: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _agency != null ? 'المكتب: ${_agency!.agencyName}' : 'المكتب غير محمّل',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_pickedPosition != null ? 'الموقع المحدد: ${_pickedPosition!.latitude.toStringAsFixed(6)}, ${_pickedPosition!.longitude.toStringAsFixed(6)}' : 'لم يتم اختيار موقع'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.my_location),
                        label: const Text('تحديد موقعي الحالي'),
                        onPressed: () async {
                          // اطلب الموقع الحالي وحدّث الخريطة
                          await _useCurrentLocation();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('إلغاء'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
