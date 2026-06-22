// lib/screens/trip_search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import 'trip_details_screen.dart';
import '../widgets/trip_card.dart';
import '../widgets/app_card.dart';
import '../widgets/custom_button.dart';

class TripSearchScreen extends StatefulWidget {
  const TripSearchScreen({super.key});

  @override
  State<TripSearchScreen> createState() => _TripSearchScreenState();
}

class _TripSearchScreenState extends State<TripSearchScreen> {
  String? _selectedTripCategory;
  String? _selectedDestination;
  String? _selectedVehicleType;

  final List<String> _tripCategories = ['داخلية', 'خارجية'];
  final List<String> _vehicleTypes = ['سيارة سيدان', 'سيارة دفع رباعي', 'سيارة فان'];

  final Map<String, List<String>> _destinations = {
    'داخلية': ['صنعاء', 'عدن', 'تعز', 'حضرموت'],
    'خارجية': ['الرياض', 'جدة', 'مكة', 'مسقط', 'أبوظبي', 'دبي', 'الشارقة'],
  };

  List<DocumentSnapshot> _results = [];
  bool _isSearching = false;
  String? _errorMessage;

  final Color _primaryColor = const Color(0xFF4A7DAB);
  final Color _backgroundColor = const Color(0xFFF4F7FA);

  Future<void> _searchTrips() async {
    if (_selectedTripCategory == null || _selectedDestination == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى اختيار فئة الرحلة والوجهة', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _results = [];
    });

    try {
      Query query = FirebaseFirestore.instance.collection('trips');
      query = query.where('status', whereIn: ['مفعّلة', 'active']);
      query = query.where('tripCategory', isEqualTo: _selectedTripCategory);
      query = query.where('destination', isEqualTo: _selectedDestination);

      if (_selectedVehicleType != null && _selectedVehicleType!.isNotEmpty) {
        query = query.where('vehicleType', isEqualTo: _selectedVehicleType);
      }

      Query orderedQuery;
      try {
        orderedQuery = query.orderBy('departureTime');
      } catch (_) {
        try {
          orderedQuery = query.orderBy('date');
        } catch (_) {
          orderedQuery = query;
        }
      }

      final snapshot = await orderedQuery.get();

      if (!mounted) return;
      setState(() {
        _results = snapshot.docs;
        _isSearching = false;
      });
    } catch (e, st) {
      debugPrint('TripSearchScreen._searchTrips error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorMessage = 'حدث خطأ أثناء البحث. حاول مرة أخرى لاحقًا.';
      });
    }
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Widget _buildCustomDropdownField({required Widget child, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildFallbackCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final departureDt = _toDateTime(data['departureTime'] ?? data['date'] ?? data['createdAt']);
    final departureText = departureDt != null ? DateFormat('yyyy/MM/dd – HH:mm').format(departureDt) : 'غير محدد';
    final vehicleType = (data['vehicleType'] ?? '-')?.toString() ?? '-';
    final destination = (data['destination'] ?? '-')?.toString() ?? '-';
    final driverName = (data['driverName'] ?? data['driver_name'] ?? '-')?.toString() ?? '-';
    final availableSeats = data['availableSeats'] is int ? data['availableSeats'] : int.tryParse('${data['availableSeats'] ?? 0}') ?? 0;
    final totalSeats = data['totalSeats'] is int ? data['totalSeats'] : int.tryParse('${data['totalSeats'] ?? 0}') ?? 0;
    final price = (data['price'] is num) ? (data['price'] as num).toDouble() : double.tryParse('${data['price'] ?? 0}') ?? 0.0;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.orangeAccent),
                    const SizedBox(width: 6),
                    Text(destination, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('${price.toStringAsFixed(0)} ريال', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                )
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(departureText, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.event_seat, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('$availableSeats / $totalSeats مقاعد', style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
                  ],
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(vehicleType, style: const TextStyle(fontSize: 13, fontFamily: 'Cairo')),
                const SizedBox(width: 14),
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(driverName, style: const TextStyle(fontSize: 13, fontFamily: 'Cairo')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    try {
                      final trip = Trip.fromDocument(doc);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح تفاصيل الرحلة')));
                    }
                  },
                  child: Text('التفاصيل', style: TextStyle(color: _primaryColor, fontFamily: 'Cairo')),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📌 ميزة الحجز قيد التطوير')));
                  },
                  child: const Text('احجز الآن', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildResultList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final doc = _results[index];
        try {
          final trip = Trip.fromDocument(doc);
          return TripCard(
            trip: trip,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
            },
          );
        } catch (_) {
          return _buildFallbackCard(context, doc);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinationOptions = _selectedTripCategory != null ? _destinations[_selectedTripCategory] ?? [] : <String>[];

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('بحث عن الرحلات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🧭 فئة الرحلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    _buildCustomDropdownField(
                      icon: Icons.category_outlined,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _selectedTripCategory,
                          items: _tripCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedTripCategory = val;
                              _selectedDestination = null;
                            });
                          },
                          decoration: const InputDecoration(border: InputBorder.none),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('📍 الوجهة المقصودة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    _buildCustomDropdownField(
                      icon: Icons.location_on_outlined,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDestination,
                          items: destinationOptions.map((dest) => DropdownMenuItem(value: dest, child: Text(dest, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                          onChanged: (val) => setState(() => _selectedDestination = val),
                          decoration: const InputDecoration(border: InputBorder.none),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('🚗 نوع السيارة (اختياري)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    _buildCustomDropdownField(
                      icon: Icons.directions_car_outlined,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _selectedVehicleType,
                          items: _vehicleTypes.map((type) => DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                          onChanged: (val) => setState(() => _selectedVehicleType = val),
                          decoration: const InputDecoration(border: InputBorder.none),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: CustomButton(
                            onPressed: _searchTrips,
                            text: 'ابدأ البحث الآن',
                            icon: Icons.search,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: _primaryColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedTripCategory = null;
                              _selectedDestination = null;
                              _selectedVehicleType = null;
                              _results = [];
                              _errorMessage = null;
                            });
                          },
                          child: Icon(Icons.refresh, color: _primaryColor),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Builder(builder: (context) {
                if (_isSearching) {
                  return Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  );
                }
                if (_errorMessage != null) {
                  return Center(
                    child: Text(_errorMessage!, style: const TextStyle(fontFamily: 'Cairo', color: Colors.red)),
                  );
                }
                if (_results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('لا توجد نتائج بحث مطابقة حالياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return _buildResultList(context);
              }),
            ),
          ],
        ),
      ),
    );
  }
}