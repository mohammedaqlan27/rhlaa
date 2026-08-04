// lib/screens/vehicle_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/vehicle.dart';
import '../providers/vehicle_provider.dart';

class VehicleScreen extends StatefulWidget {
  final String? vehicleId;
  const VehicleScreen({super.key, this.vehicleId});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  // المتحكمات (Controllers) لجميع الحقول المطلوبة
  final _plateController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _makeModelYearController = TextEditingController();
  final _maxCapacityController = TextEditingController();
  final _colorController = TextEditingController();
  final _notesController = TextEditingController();
  final _vehicleOwnerController = TextEditingController(); // اسم المالك الرسمي
  final _driverNameController = TextEditingController();   // اسم السائق الحقيقي
  final _licenseNumberController = TextEditingController();

  bool _isVerified = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _vehicleId;

  // ألوان الهوية البصرية الاحترافية
  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _accentTeal = Color(0xFF17A5A3);

  @override
  void initState() {
    super.initState();
    _vehicleId = widget.vehicleId;
    if (_vehicleId != null && _vehicleId!.isNotEmpty) {
      _loadVehicle(_vehicleId!);
    } else {
      _fillInitialDataFromUser();
    }
  }

  // جلب بيانات المستخدم لملء الخانات تلقائياً وتوفير الجهد
  Future<void> _fillInitialDataFromUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      setState(() {
        _driverNameController.text = (data['name'] ?? data['nickname'] ?? '') as String;
        _vehicleOwnerController.text = (data['vehicleOwner'] ?? data['vehicle_owner'] ?? '') as String;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _plateController.dispose();
    _vehicleTypeController.dispose();
    _makeModelYearController.dispose();
    _maxCapacityController.dispose();
    _colorController.dispose();
    _notesController.dispose();
    _vehicleOwnerController.dispose();
    _driverNameController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle(String id) async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('vehicles').doc(id).get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      _plateController.text = (data['plateNumber'] ?? data['plate_number'] ?? '') as String;
      _vehicleTypeController.text = (data['vehicleType'] ?? data['vehicle_type'] ?? '') as String;
      _makeModelYearController.text = (data['makeModelYear'] ?? data['make_model_year'] ?? '') as String;
      _maxCapacityController.text = (data['maxCapacity'] ?? data['max_capacity'] ?? '').toString();
      _colorController.text = (data['color'] ?? '') as String;
      _notesController.text = (data['notes'] ?? data['note'] ?? '') as String;
      _vehicleOwnerController.text = (data['vehicleOwner'] ?? data['vehicle_owner'] ?? '') as String;
      _driverNameController.text = (data['driverName'] ?? '') as String;
      _licenseNumberController.text = (data['licenseNumber'] ?? data['license_number'] ?? '').toString();
      _isVerified = (data['isVerified'] ?? data['is_verified'] ?? false) as bool;
      setState(() {});
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _requiredValidator(String label, String? val) {
    if (val == null || val.trim().isEmpty) return 'يرجى إدخال $label';
    return null;
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      final vehicle = Vehicle(
        id: _vehicleId ?? '',
        plateNumber: _plateController.text.trim(),
        vehicleOwner: _vehicleOwnerController.text.trim(),
        driverName: _driverNameController.text.trim(),
        vehicleType: _vehicleTypeController.text.trim(),
        makeModelYear: _makeModelYearController.text.trim(),
        color: _colorController.text.trim(),
        maxCapacity: int.tryParse(_maxCapacityController.text.trim()) ?? 0,
        licenseNumber: _licenseNumberController.text.trim(),
        isVerified: _isVerified,
        notes: _notesController.text.trim(),
        createdAt: null,
      );

      final vehicleProvider = context.read<VehicleProvider>();

      if (_vehicleId != null && _vehicleId!.isNotEmpty) {
        await vehicleProvider.updateVehicle(_vehicleId!, vehicle);
      } else {
        final id = await vehicleProvider.addVehicle(vehicle);
        if (id != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'vehicleIds': FieldValue.arrayUnion([id]),
            'currentVehicleId': id,
          }, SetOptions(merge: true));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم حفظ بيانات المركبة بنجاح')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_vehicleId != null ? 'تعديل بيانات المركبة' : 'إضافة مركبة جديدة',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('المعلومات الأساسية (إجباري)'),
              _buildTextField(_driverNameController, 'اسم السائق الحقيقي', Icons.person, isRequired: true),
              _buildTextField(_vehicleOwnerController, 'اسم مالك المركبة الرسمي', Icons.badge, isRequired: true),
              _buildTextField(_plateController, 'رقم لوحة السيارة', Icons.confirmation_number, isRequired: true),
              _buildTextField(_vehicleTypeController, 'نوع المركبة (باص، صالون...)', Icons.directions_car, isRequired: true),

              const SizedBox(height: 20),
              _buildSectionTitle('تفاصيل المركبة'),
              _buildTextField(_makeModelYearController, 'الموديل / سنة الصنع', Icons.calendar_today),
              _buildTextField(_maxCapacityController, 'عدد المقاعد', Icons.event_seat, isNumber: true),
              _buildTextField(_colorController, 'لون المركبة', Icons.color_lens),

              const SizedBox(height: 20),
              _buildSectionTitle('التوثيق والملاحظات'),
              _buildTextField(_licenseNumberController, 'رقم رخصة السير', Icons.card_membership),
              _buildTextField(_notesController, 'ملاحظات إضافية', Icons.note, maxLines: 2),

              const SizedBox(height: 10),
              _buildVerificationSwitch(),

              const SizedBox(height: 30),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 5),
      child: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: _primaryBlue)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isRequired = false, bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _primaryBlue, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: _primaryBlue)),
        ),
        validator: isRequired ? (v) => _requiredValidator(label, v) : null,
      ),
    );
  }

  Widget _buildVerificationSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _isVerified ? Colors.green : Colors.grey.shade300),
      ),
      child: SwitchListTile(
        title: const Text('موثقة / تم التحقق منها', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: const Text('تظهر علامة التوثيق للركاب لزيادة الثقة', style: TextStyle(fontSize: 11)),
        value: _isVerified,
        activeColor: Colors.green,
        onChanged: (val) => setState(() => _isVerified = val),
        secondary: Icon(Icons.verified, color: _isVerified ? Colors.green : Colors.grey),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveVehicle,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
      ),
      child: _isSaving
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('حفظ بيانات المركبة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}