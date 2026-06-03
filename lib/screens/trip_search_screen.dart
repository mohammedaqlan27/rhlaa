// lib/screens/trip_search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import 'trip_details_screen.dart';
import '../widgets/trip_card.dart';

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

  Future<void> _searchTrips() async {
    if (_selectedTripCategory == null || _selectedDestination == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار فئة الرحلة والوجهة')),
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

      // نبحث عن الرحلات المفعّلة فقط (ندعم صيغ متعددة لاحقًا إن لزم)
      query = query.where('status', whereIn: ['مفعّلة', 'active']);

      // فئة الرحلة
      query = query.where('tripCategory', isEqualTo: _selectedTripCategory);

      // الوجهة
      query = query.where('destination', isEqualTo: _selectedDestination);

      // نوع المركبة اختياري
      if (_selectedVehicleType != null && _selectedVehicleType!.isNotEmpty) {
        query = query.where('vehicleType', isEqualTo: _selectedVehicleType);
      }

      // ترتيب حسب وقت المغادرة إن أمكن
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

    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Icon(Icons.location_on, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Expanded(child: Text('$destination', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${price.toStringAsFixed(0)} ريال', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, color: theme.colorScheme.secondary, size: 18),
              const SizedBox(width: 6),
              Text(departureText, style: theme.textTheme.bodySmall),
              const Spacer(),
              Icon(Icons.event_seat, color: theme.colorScheme.secondary, size: 18),
              const SizedBox(width: 6),
              Text('$availableSeats من $totalSeats', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.directions_car, color: theme.colorScheme.secondary, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(vehicleType, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: 8),
              Icon(Icons.person, color: theme.colorScheme.secondary, size: 18),
              const SizedBox(width: 6),
              Text(driverName, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  // محاولة تحويل إلى Trip ثم الانتقال إلى التفاصيل
                  try {
                    final trip = Trip.fromDocument(doc);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح تفاصيل الرحلة'))); 
                  }
                },
                icon: Icon(Icons.info_outline, color: theme.colorScheme.primary),
                label: Text('عرض التفاصيل', style: TextStyle(color: theme.colorScheme.primary)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📌 ميزة الحجز قيد التطوير')));
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('احجز الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildResultList(BuildContext context) {
    final theme = Theme.of(context);

    // إذا أمكن تحويل المستند إلى Trip، نستخدم TripCard (التصميم الموحد)
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
          // إذا فشل التحويل نعرض بطاقة احتياطية مبسطة
          return _buildFallbackCard(context, doc);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destinationOptions = _selectedTripCategory != null ? _destinations[_selectedTripCategory] ?? [] : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث عن الرحلات'),
        backgroundColor: theme.colorScheme.primary,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // فئة الرحلة
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('🧭 اختر فئة الرحلة:', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedTripCategory,
                      items: _tripCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedTripCategory = val;
                          _selectedDestination = null;
                        });
                      },
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category, color: theme.colorScheme.secondary),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // الوجهة
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('📍 اختر الوجهة:', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedDestination,
                      items: destinationOptions.map((dest) => DropdownMenuItem(value: dest, child: Text(dest))).toList(),
                      onChanged: (val) => setState(() => _selectedDestination = val),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on, color: theme.colorScheme.secondary),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // نوع المركبة
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('🚗 نوع السيارة (اختياري):', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedVehicleType,
                      items: _vehicleTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (val) => setState(() => _selectedVehicleType = val),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_car, color: theme.colorScheme.secondary),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // أزرار البحث ومسح الاختيارات
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _searchTrips,
                            icon: Icon(Icons.search, color: theme.colorScheme.onPrimary),
                            label: const Text('بحث', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedTripCategory = null;
                              _selectedDestination = null;
                              _selectedVehicleType = null;
                              _results = [];
                              _errorMessage = null;
                            });
                          },
                          icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
                          label: Text('مسح', style: TextStyle(color: theme.colorScheme.primary)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.primary),
                            minimumSize: const Size(120, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // نتائج البحث / حالة التحميل / رسالة الخطأ
            Expanded(
              child: Builder(builder: (context) {
                if (_isSearching) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text('جاري البحث عن الرحلات...', style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  );
                }

                if (_errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _searchTrips,
                          child: const Text('حاول مرة أخرى'),
                          style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  );
                }

                if (_results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('لا توجد نتائج حالياً', style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 6),
                        Text('جرّب تغيير الفلاتر أو المسح لإعادة البحث', style: theme.textTheme.bodySmall),
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
