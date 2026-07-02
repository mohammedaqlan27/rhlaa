// lib/screens/trip_search_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../models/trip.dart';
import '../widgets/trip_card.dart';
import '../widgets/app_card.dart';
import '../widgets/custom_button.dart';
import 'trip_details_screen.dart';

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

  bool _hasSearched = false;
  final Color _primaryColor = const Color(0xFF4A7DAB);

  @override
  void initState() {
    super.initState();
    // جلب البيانات في الخلفية لضمان سرعة البحث المحلي
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripProvider>(context, listen: false).fetchAvailableTrips();
    });
  }

  void _handleSearch() {
    if (_selectedTripCategory == null || _selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى اختيار الفئة والوجهة', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }
    setState(() => _hasSearched = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('ابحث عن رحلتك', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          _buildSearchForm(),
          Expanded(
            child: _hasSearched ? _buildSearchResults() : _buildSearchPlaceholder(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchForm() {
    final destinationOptions = _selectedTripCategory != null ? _destinations[_selectedTripCategory] ?? [] : <String>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDropdown('الفئة', Icons.category, _tripCategories, _selectedTripCategory, (val) {
                setState(() { _selectedTripCategory = val; _selectedDestination = null; });
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown('الوجهة', Icons.location_on, destinationOptions, _selectedDestination, (val) {
                setState(() => _selectedDestination = val);
              })),
            ],
          ),
          const SizedBox(height: 16),
          CustomButton(
            onPressed: _handleSearch,
            text: 'بحث عن الرحلات المتاحة',
            icon: Icons.search,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, IconData icon, List<String> items, String? value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: Text('اختر', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator());

        // تصفية ذكية ومحلية (تتجنب مشاكل الـ Firebase Index)
        final results = provider.availableTrips.where((trip) {
          final matchCat = trip.tripCategory == _selectedTripCategory;
          final matchDest = trip.destination.trim() == _selectedDestination?.trim();
          final matchVehicle = _selectedVehicleType == null || trip.vehicleType == _selectedVehicleType;
          return matchCat && matchDest && matchVehicle;
        }).toList();

        if (results.isEmpty) {
          return _buildNoResults();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => TripCard(
            trip: results[index],
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: results[index]))),
          ),
        );
      },
    );
  }

  Widget _buildSearchPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.travel_explore, size: 100, color: Colors.blue.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('حدد وجهتك وابدأ البحث الآن', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sentiment_dissatisfied, size: 60, color: Colors.orangeAccent),
          const SizedBox(height: 16),
          const Text('لا توجد رحلات مطابقة حالياً', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          TextButton(onPressed: () => setState(() => _hasSearched = false), child: const Text('تغيير خيارات البحث', style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
  }
}