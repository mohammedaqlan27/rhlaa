// lib/screens/agency_location_edit_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/agencies_provider.dart';
import '../../models/agency.dart';

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

  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _textDark = Color(0xFF1E293B);

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
        Marker(
          markerId: MarkerId('agency_${widget.agencyId}'),
          position: pos,
          infoWindow: InfoWindow(title: _agency?.agencyName ?? 'موقع المكتب'),
        ),
      };
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_pickedPosition != null) {
      _mapController?.moveCamera(CameraUpdate.newLatLngZoom(_pickedPosition!, 15));
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تفعيل خدمة الموقع (GPS) في جهازك', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفض إذن الوصول للموقع', style: TextStyle(fontFamily: 'Cairo'))),
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('إذن الموقع مرفوض نهائياً. يرجى تفعيله من إعدادات التطبيق', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      debugPrint('Geolocator error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديد موقعك الحالي', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى النقر على الخريطة لاختيار موقع أولاً', style: TextStyle(fontFamily: 'Cairo'))));
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ موقع المكتب بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
          await provider.loadAgencyById(widget.agencyId);
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حفظ موقع المكتب', style: TextStyle(fontFamily: 'Cairo'))));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحفظ: $e', style: const TextStyle(fontFamily: 'Cairo'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = _pickedPosition ?? const LatLng(15.3694, 44.1910); // صنعاء افتراضياً

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _primaryBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'تعيين موقع المكتب',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _textDark, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton.icon(
              onPressed: _saving ? null : _saveLocation,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _primaryBlue, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, color: _primaryBlue),
              label: Text(_saving ? '' : 'حفظ', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _primaryBlue)),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(target: initialCamera, zoom: 13),
                  markers: _markers,
                  onTap: _onTap,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: _primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _agency != null ? 'المكتب: ${_agency!.agencyName}' : 'جاري التحميل...',
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: _textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pin_drop, color: Colors.red, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _pickedPosition != null
                            ? 'الإحداثيات: ${_pickedPosition!.latitude.toStringAsFixed(5)}, ${_pickedPosition!.longitude.toStringAsFixed(5)}'
                            : 'انقر على الخريطة لتحديد موقع المكتب',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.my_location, color: Colors.white, size: 18),
                        label: const Text('موقعي الحالي', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () async => await _useCurrentLocation(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                      label: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
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