import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/trip.dart';
import '../widgets/shared/app_scaffold.dart';
import '../widgets/shared/app_card.dart';
import '../widgets/shared/custom_button.dart';
import '../providers/vehicle_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'edit_profile_screen.dart';
import 'vehicle_screen.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String? _driverCarPlateNumber;
  String? _driverCarOwnerOfficialName;
  bool _isLoadingUserData = true;
  bool _isSubmitting = false;

  late final List<String> _internalDestinations;
  late final List<String> _externalCities;
  late final List<String> _allDestinations;
  late final List<String> _carTypesList;

  String _selectedOrigin = '';
  String _selectedDestination = '';
  String _carType = '';
  String _tripCategory = 'داخلية';
  int _totalSeats = 4;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoGreen = const Color(0xFF4EBF64);

  @override
  void initState() {
    super.initState();

    _internalDestinations = List<String>.from(AppConstants.yemenGovernorates);
    _externalCities = List<String>.from(AppConstants.allExternalCities);
    _allDestinations = _mergePreserveOrder(_internalDestinations, _externalCities);

    _carTypesList = AppConstants.vehicleCategories.values.expand((l) => l).toList();

    _selectedOrigin = _allDestinations.isNotEmpty ? _allDestinations.first : 'غير محدد';
    _selectedDestination = _allDestinations.length > 1 ? _allDestinations[1] : _selectedOrigin;
    _carType = _carTypesList.isNotEmpty ? _carTypesList.first : 'غير محدد';

    _updateTripCategoryBasedOnSelection();
    _fetchDriverData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vp = context.read<VehicleProvider>();
      final sel = vp.selectedVehicle;
      if (sel != null) {
        _driverCarPlateNumber = sel.plateNumber;
        _driverCarOwnerOfficialName = sel.vehicleOwner;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  List<T> _mergePreserveOrder<T>(List<T> a, List<T> b) {
    final seen = <T>{};
    final out = <T>[];
    for (final e in a) {
      if (seen.add(e)) out.add(e);
    }
    for (final e in b) {
      if (seen.add(e)) out.add(e);
    }
    return out;
  }

  void _updateTripCategoryBasedOnSelection() {
    final originNorm = _normalize(_selectedOrigin);
    final destNorm = _normalize(_selectedDestination);

    final originIsInternal = _internalDestinations.map(_normalize).contains(originNorm);
    final destIsInternal = _internalDestinations.map(_normalize).contains(destNorm);

    final newCategory = (originIsInternal && destIsInternal) ? 'داخلية' : 'خارجية';
    if (newCategory != _tripCategory && mounted) {
      setState(() => _tripCategory = newCategory);
    }
  }

  String _normalize(String s) => s.trim().toLowerCase();

  Future<void> _fetchDriverData() async {
    if (!mounted) return;
    setState(() => _isLoadingUserData = true);
    final authProv = context.read<AuthProvider?>();
    final uid = authProv?.currentUserId ?? fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingUserData = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _driverCarPlateNumber = (data['plateNumber'] ?? data['plate_number'] ?? data['carPlateNumber'] ?? '') as String?;
        _driverCarOwnerOfficialName = (data['carOwnerOfficialName'] ?? data['vehicleOwner'] ?? '') as String?;
      }

      final vp = context.read<VehicleProvider>();
      try {
        await vp.fetchDriverVehicles(uid);
      } catch (e) {
        debugPrint('CreateTripScreen: fetchDriverVehicles error: $e');
      }

      if (vp.vehicles.isNotEmpty && (vp.selectedVehicle == null || vp.selectedVehicle!.id.isEmpty)) {
        vp.selectVehicleById(vp.vehicles.first.id);
      }

      final sel = vp.selectedVehicle;
      if (sel != null) {
        _driverCarPlateNumber = sel.plateNumber;
        _driverCarOwnerOfficialName = sel.vehicleOwner;
      }
    } catch (e, st) {
      debugPrint("CreateTripScreen._fetchDriverData error: $e\n$st");
    } finally {
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _openVehicleScreenAndRefresh() async {
    final result = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) {
          final auth = context.read<AuthProvider?>();
          final uid = auth?.currentUserId ?? fb.FirebaseAuth.instance.currentUser?.uid ?? "";
          return VehicleScreen(driverId: uid);
        },
      ),
    );
    await _fetchDriverData();
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث بيانات المركبة', style: TextStyle(fontFamily: 'Cairo'))),
      );
    }
  }

  Future<void> _submitTrip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final vp = context.read<VehicleProvider>();
      if (vp.selectedVehicle == null || (vp.selectedVehicle!.id.isEmpty)) {
        final authProv = context.read<AuthProvider?>();
        final uid = authProv?.currentUserId ?? fb.FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await vp.fetchDriverVehicles(uid);
          if (vp.vehicles.isNotEmpty) vp.selectVehicleById(vp.vehicles.first.id);
        }
      }

      final selectedVehicle = vp.selectedVehicle;
      if (selectedVehicle == null || (selectedVehicle.id.isEmpty)) {
        _showCompleteProfileDialog(message: 'يرجى اختيار مركبة من القائمة أو إضافة مركبة جديدة');
        return;
      }

      if ((selectedVehicle.plateNumber ?? '').trim().isEmpty) {
        _showCompleteProfileDialog(message: 'رقم لوحة المركبة غير محدد. يرجى تحديث بيانات المركبة.');
        return;
      }

      if ((selectedVehicle.vehicleOwner ?? '').trim().isEmpty) {
        _showCompleteProfileDialog(message: 'اسم مالك المركبة غير محدد. يرجى تحديث الملف أو إضافة مركبة موثوقة.');
        return;
      }

      final authProv = context.read<AuthProvider?>();
      final userId = authProv?.currentUserId ?? fb.FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _showCompleteProfileDialog(message: 'يجب تسجيل الدخول أولاً');
        return;
      }

      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      if (price <= 0) {
        _showCompleteProfileDialog(message: 'السعر يجب أن يكون أكبر من صفر');
        return;
      }

      if (_totalSeats <= 0) {
        _showCompleteProfileDialog(message: 'عدد المقاعد غير صالح');
        return;
      }

      if (_selectedDate.isBefore(DateTime.now())) {
        _showCompleteProfileDialog(message: 'تاريخ الرحلة يجب أن يكون في المستقبل');
        return;
      }

      final trip = Trip(
        id: '',
        title: 'رحلة من $_selectedOrigin إلى $_selectedDestination',
        description: _descriptionController.text.trim(),
        driverId: userId,
        driverName: authProv?.currentUserName ?? fb.FirebaseAuth.instance.currentUser?.displayName ?? 'سائق',
        origin: _selectedOrigin,
        destination: _selectedDestination,
        tripCategory: _tripCategory,
        vehicleType: _carType,
        totalSeats: _totalSeats,
        availableSeats: _totalSeats,
        seatStatus: List<bool>.filled(_totalSeats, true),
        departureTime: _selectedDate,
        status: 'active',
        price: price,
        carPlateNumber: selectedVehicle.plateNumber ?? '',
        carOwnerOfficialName: selectedVehicle.vehicleOwner ?? '',
        vehicleId: selectedVehicle.id,
        createdAt: null,
        updatedAt: null,
      );

      final tripProv = context.read<TripProvider>();
      final createdId = await tripProv.createNewTrip(trip, null);

      if (createdId != null && createdId.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم نشر الرحلة بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
          );
          Navigator.pop(context, true);
        }
      } else {
        final err = tripProv.errorMessage ?? 'فشل نشر الرحلة';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $err', style: const TextStyle(fontFamily: 'Cairo'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ غير متوقع: $e', style: const TextStyle(fontFamily: 'Cairo'))));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showCompleteProfileDialog({String message = 'يرجى إكمال بيانات السيارة'}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بيانات ناقصة', style: TextStyle(fontFamily: 'Cairo')),
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _fetchDriverData());
            },
            child: const Text('تعديل الملف', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'إنشاء رحلة جديدة',
      isLoading: _isSubmitting,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildRouteSection(),
              const SizedBox(height: 16),
              _buildDetailsSection(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CustomButton(
                  onPressed: _isSubmitting ? null : _submitTrip,
                  text: _isSubmitting ? 'جاري النشر...' : 'نشر الرحلة الآن',
                  icon: Icons.publish,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteSection() {
    return AppCard(
      child: Column(
        children: [
          _buildDropdown<String>(
            'نقطة الانطلاق',
            _selectedOrigin,
            _allDestinations,
                (val) {
              if (val == null) return;
              setState(() {
                _selectedOrigin = val;
                _updateTripCategoryBasedOnSelection();
              });
            },
          ),
          const SizedBox(height: 8),
          const Icon(Icons.arrow_downward, color: Colors.grey),
          const SizedBox(height: 8),
          _buildDropdown<String>(
            'وجهة الوصول',
            _selectedDestination,
            _allDestinations,
                (val) {
              if (val == null) return;
              setState(() {
                _selectedDestination = val;
                _updateTripCategoryBasedOnSelection();
              });
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('الفئة: $_tripCategory', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return AppCard(
      child: Column(
        children: [
          _buildTextField(_priceController, 'سعر المقعد (ر.ي)', Icons.money, TextInputType.number, validator: (v) {
            if (v == null || v.trim().isEmpty) return 'يرجى إدخال السعر';
            final n = double.tryParse(v.trim());
            if (n == null || n <= 0) return 'السعر غير صالح';
            return null;
          }),
          const SizedBox(height: 12),
          _buildDropdown<String>('نوع المركبة', _carType, _carTypesList, (val) => setState(() => _carType = val ?? _carType)),
          const SizedBox(height: 12),
          _buildDropdown<int>('عدد المقاعد', _totalSeats, [1, 2, 3, 4, 5, 6, 7], (val) => setState(() => _totalSeats = val ?? _totalSeats)),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('تاريخ الرحلة: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}', style: const TextStyle(fontFamily: 'Cairo')),
              trailing: Icon(Icons.calendar_today, color: _logoBlue),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null && mounted) setState(() => _selectedDate = date);
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingUserData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                const Text('معلومات المركبة المستخدمة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text('اللوحة: ${_driverCarPlateNumber ?? 'غير محددة'}', style: const TextStyle(fontFamily: 'Cairo')),
                    ),
                    Expanded(
                      child: Text('المالك: ${_driverCarOwnerOfficialName ?? 'غير محدد'}', style: const TextStyle(fontFamily: 'Cairo')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openVehicleScreenAndRefresh,
                      icon: const Icon(Icons.directions_car),
                      label: const Text('اختيار/إضافة مركبة أخرى', style: TextStyle(fontFamily: 'Cairo')),
                      style: ElevatedButton.styleFrom(backgroundColor: _logoGreen),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _fetchDriverData()),
                      child: const Text('تعديل البيانات', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(String label, T value, List<T> items, ValueChanged<T?> onChanged) {
    final seen = <T>{};
    final unique = <T>[];
    for (final e in items) {
      if (seen.add(e)) unique.add(e);
    }

    final T? effectiveValue = unique.contains(value) ? value : (unique.isNotEmpty ? unique.first : null);

    return DropdownButtonFormField<T>(
      value: effectiveValue,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontFamily: 'Cairo')),
      items: unique
          .map((i) => DropdownMenuItem<T>(
        value: i,
        child: Text(i.toString(), style: const TextStyle(fontFamily: 'Cairo')),
      ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon,
      TextInputType type, {
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'حقل مطلوب' : null,
    );
  }
}