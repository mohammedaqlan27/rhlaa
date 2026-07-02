// lib/screens/create_trip_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/app_card.dart';
import '../widgets/custom_button.dart';
import '../providers/vehicle_provider.dart';
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

  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoGreen = const Color(0xFF4EBF64);

  final List<String> origins = ['صنعاء', 'عدن', 'تعز', 'الحديدة', 'إب', 'حضرموت', 'مأرب'];
  final List<String> carTypes = ['سيارة سيدان', 'سيارة دفع رباعي', 'سيارة فان', 'حافلة صغيرة'];

  String _selectedOrigin = 'صنعاء';
  String _selectedDestination = 'عدن';
  String _carType = 'سيارة سيدان';
  String _tripCategory = 'داخلية';
  int _totalSeats = 4;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _fetchDriverData();
    // استمع لمزود المركبات لاستخدام المركبة المختارة إن وُجدت
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vp = context.read<VehicleProvider>();
      final sel = vp.selectedVehicle;
      if (sel != null) {
        _driverCarPlateNumber = sel.plateNumber;
        _driverCarOwnerOfficialName = sel.vehicleOwner;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _fetchDriverData() async {
    setState(() => _isLoadingUserData = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingUserData = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _driverCarPlateNumber = (data['carPlateNumber'] ?? data['plateNumber'] ?? data['plate_number'] ?? '') as String?;
        _driverCarOwnerOfficialName = (data['carOwnerOfficialName'] ?? data['vehicle_owner'] ?? data['vehicleOwner'] ?? '') as String?;
      } else {
        _driverCarPlateNumber = null;
        _driverCarOwnerOfficialName = null;
      }

      // إذا كان هناك مركبة مختارة في الـ Provider، استخدمها لتجاوز بيانات الملف
      final vp = context.read<VehicleProvider>();
      final sel = vp.selectedVehicle;
      if (sel != null) {
        _driverCarPlateNumber = sel.plateNumber;
        _driverCarOwnerOfficialName = sel.vehicleOwner;
      }
    } catch (e) {
      debugPrint("CreateTripScreen._fetchDriverData error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _openVehicleScreenAndRefresh() async {
    final result = await Navigator.push<bool?>(context, MaterialPageRoute(builder: (_) => const VehicleScreen()));
    // بعد العودة نعيد جلب بيانات المستخدم ونحدث مزود المركبات
    await _fetchDriverData();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await context.read<VehicleProvider>().fetchDriverVehicles(uid);
    }
    if (result == true) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث بيانات المركبة', style: TextStyle(fontFamily: 'Cairo'))));
    }
  }

  Future<void> _submitTrip() async {
    if (!_formKey.currentState!.validate()) return;

    // إلزامية بيانات المركبة: اسم المالك ورقم اللوحة
    if ((_driverCarOwnerOfficialName ?? '').trim().isEmpty) {
      _showCompleteProfileDialog(message: 'يرجى إدخال اسم مالك المركبة');
      return;
    }
    if ((_driverCarPlateNumber ?? '').trim().isEmpty) {
      _showCompleteProfileDialog(message: 'يرجى إدخال رقم لوحة المركبة');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'يجب تسجيل الدخول أولاً';

      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

      final tripData = {
        'title': 'رحلة من $_selectedOrigin إلى $_selectedDestination',
        'description': _descriptionController.text.trim(),
        'driverId': user.uid,
        'driverName': user.displayName ?? 'سائق موثق',
        'origin': _selectedOrigin,
        'destination': _selectedDestination,
        'tripCategory': _tripCategory,
        'vehicleType': _carType,
        'totalSeats': _totalSeats,
        'availableSeats': _totalSeats,
        'seatStatus': List<bool>.filled(_totalSeats, true),
        'departureTime': Timestamp.fromDate(_selectedDate),
        'status': 'active',
        'price': price,
        // نستخدم أسماء الحقول المتوافقة مع قاعدة البيانات لديك
        'plateNumber': _driverCarPlateNumber,
        'plate_number': _driverCarPlateNumber,
        'carPlateNumber': _driverCarPlateNumber,
        'vehicleOwner': _driverCarOwnerOfficialName,
        'vehicle_owner': _driverCarOwnerOfficialName,
        'carOwnerOfficialName': _driverCarOwnerOfficialName,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('trips').add(tripData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم نشر الرحلة بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _fetchDriverData());
            },
            child: const Text('تعديل الملف'),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSection() {
    return AppCard(
      child: Column(
        children: [
          _buildDropdown<String>('نقطة الانطلاق', _selectedOrigin, origins, (val) => setState(() => _selectedOrigin = val!)),
          const Icon(Icons.arrow_downward, color: Colors.grey),
          _buildDropdown<String>('وجهة الوصول', _selectedDestination, origins, (val) => setState(() => _selectedDestination = val!)),
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
            if (n == null || n < 0) return 'السعر غير صالح';
            return null;
          }),
          const SizedBox(height: 12),
          _buildDropdown<String>('نوع المركبة', _carType, carTypes, (val) => setState(() => _carType = val!)),
          const SizedBox(height: 12),
          _buildDropdown<int>('عدد المقاعد', _totalSeats, [1, 2, 3, 4, 5, 6, 7], (val) => setState(() => _totalSeats = val!)),
          const SizedBox(height: 12),
          ListTile(
            title: Text('تاريخ الرحلة: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}', style: const TextStyle(fontFamily: 'Cairo')),
            trailing: const Icon(Icons.calendar_today, color: Colors.blue),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
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
                      label: const Text('اختيار/إضافة مركبة أخرى'),
                      style: ElevatedButton.styleFrom(backgroundColor: _logoGreen),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _fetchDriverData()),
                      child: const Text('تعديل بيانات المركبة في الملف'),
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
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontFamily: 'Cairo')),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i.toString(), style: const TextStyle(fontFamily: 'Cairo')))).toList(),
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'إنشاء رحلة جديدة',
      isLoading: _isSubmitting,
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildRouteSection(),
              const SizedBox(height: 16),
              _buildDetailsSection(),
              const SizedBox(height: 24),
              CustomButton(
                onPressed: _submitTrip,
                text: 'نشر الرحلة الآن',
                icon: Icons.publish,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
