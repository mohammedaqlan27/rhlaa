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

  final _plateController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _makeModelYearController = TextEditingController();
  final _maxCapacityController = TextEditingController();

  final _colorController = TextEditingController();
  final _notesController = TextEditingController();
  final _vehicleOwnerController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  bool _isVerified = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _vehicleId;

  @override
  void initState() {
    super.initState();
    _vehicleId = widget.vehicleId;
    if (_vehicleId != null && _vehicleId!.isNotEmpty) {
      _loadVehicle(_vehicleId!);
    } else {
      _fillOwnerFromUser();
    }
  }

  Future<void> _fillOwnerFromUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() as Map<String, dynamic>? ?? {};
      // try multiple possible field names for backward compatibility
      _vehicleOwnerController.text = (data['vehicle_owner'] ?? data['vehicleOwner'] ?? data['name'] ?? '') as String;
      setState(() {});
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
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle(String id) async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('vehicles').doc(id).get();
      if (!doc.exists) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المركبة غير موجودة')));
        return;
      }
      final data = doc.data() as Map<String, dynamic>? ?? {};
      _plateController.text = (data['plateNumber'] as String?) ?? (data['plate_number'] as String?) ?? '';
      _vehicleTypeController.text = (data['vehicleType'] as String?) ?? (data['vehicle_type'] as String?) ?? '';
      _makeModelYearController.text = (data['makeModelYear'] as String?) ?? (data['make_model_year'] as String?) ?? '';
      _maxCapacityController.text = (data['maxCapacity']?.toString()) ?? (data['max_capacity']?.toString()) ?? '';
      _colorController.text = (data['color'] as String?) ?? '';
      _notesController.text = (data['notes'] as String?) ?? (data['note'] as String?) ?? '';
      _vehicleOwnerController.text = (data['vehicleOwner'] as String?) ?? (data['vehicle_owner'] as String?) ?? '';
      _licenseNumberController.text = (data['licenseNumber']?.toString()) ?? (data['license_number']?.toString()) ?? '';
      _isVerified = (data['isVerified'] as bool?) ?? (data['is_verified'] as bool?) ?? false;
      setState(() {});
    } catch (e) {
      debugPrint('VehicleScreen._loadVehicle error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل في جلب بيانات المركبة: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _requiredValidator(String label, String? val) {
    if (val == null || val.trim().isEmpty) return 'يرجى إدخال $label';
    return null;
  }

  /// بحث سريع عن مركبة حسب رقم اللوحة وملء الحقول إن وُجدت
  Future<void> _findByPlate() async {
    final plate = _plateController.text.trim();
    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل رقم اللوحة أولاً')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final q = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('plateNumber', isEqualTo: plate)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        // try snake_case fallback
        final q2 = await FirebaseFirestore.instance
            .collection('vehicles')
            .where('plate_number', isEqualTo: plate)
            .limit(1)
            .get();
        if (q2.docs.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم نعثر على مركبة بهذا الرقم')));
          return;
        } else {
          final doc = q2.docs.first;
          _populateFieldsFromVehicleDoc(doc.data() as Map<String, dynamic>, doc.id);
        }
      } else {
        final doc = q.docs.first;
        _populateFieldsFromVehicleDoc(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      debugPrint('VehicleScreen._findByPlate error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء البحث: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateFieldsFromVehicleDoc(Map<String, dynamic> data, String id) {
    _vehicleId = id;
    _plateController.text = (data['plateNumber'] as String?) ?? (data['plate_number'] as String?) ?? _plateController.text;
    _vehicleTypeController.text = (data['vehicleType'] as String?) ?? (data['vehicle_type'] as String?) ?? '';
    _makeModelYearController.text = (data['makeModelYear'] as String?) ?? (data['make_model_year'] as String?) ?? '';
    _maxCapacityController.text = (data['maxCapacity']?.toString()) ?? (data['max_capacity']?.toString()) ?? '';
    _colorController.text = (data['color'] as String?) ?? '';
    _notesController.text = (data['notes'] as String?) ?? (data['note'] as String?) ?? '';
    _vehicleOwnerController.text = (data['vehicleOwner'] as String?) ?? (data['vehicle_owner'] as String?) ?? '';
    _licenseNumberController.text = (data['licenseNumber']?.toString()) ?? (data['license_number']?.toString()) ?? '';
    _isVerified = (data['isVerified'] as bool?) ?? (data['is_verified'] as bool?) ?? false;
    setState(() {});
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ يجب تسجيل الدخول أولاً')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final plate = _plateController.text.trim();
      final vehicleType = _vehicleTypeController.text.trim();
      final makeModelYear = _makeModelYearController.text.trim();
      final maxCapacity = int.tryParse(_maxCapacityController.text.trim()) ?? 0;
      final color = _colorController.text.trim();
      final notes = _notesController.text.trim();
      final vehicleOwner = _vehicleOwnerController.text.trim();
      final licenseNumber = _licenseNumberController.text.trim();

      final vehicle = Vehicle(
        id: _vehicleId ?? '',
        plateNumber: plate,
        vehicleOwner: vehicleOwner,
        vehicleType: vehicleType,
        makeModelYear: makeModelYear,
        color: color,
        maxCapacity: maxCapacity,
        licenseNumber: licenseNumber,
        isVerified: _isVerified,
        notes: notes.isNotEmpty ? notes : null,
        createdAt: null,
      );

      final vehicleProvider = context.read<VehicleProvider>();

      if (_vehicleId != null && _vehicleId!.isNotEmpty) {
        final ok = await vehicleProvider.updateVehicle(_vehicleId!, vehicle);
        if (ok) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تحديث بيانات المركبة')));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ فشل في تحديث المركبة')));
        }
      } else {
        final id = await vehicleProvider.addVehicle(vehicle);
        if (id != null) {
          _vehicleId = id;
          // ربط المركبة بحساب المستخدم
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'vehicleIds': FieldValue.arrayUnion([id]),
            'plate_number': plate,
            'vehicle_owner': vehicleOwner,
            'carPlateNumber': plate,
            'vehicleOwner': vehicleOwner,
          }, SetOptions(merge: true));
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إضافة المركبة بنجاح')));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ فشل في إضافة المركبة')));
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint('VehicleScreen._saveVehicle error: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل في حفظ المركبة: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteVehicle() async {
    if (_vehicleId == null || _vehicleId!.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المركبة'),
        content: const Text('هل أنت متأكد أنك تريد حذف هذه المركبة؟ سيتم إلغاء ربطها من ملفك الشخصي.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('لا')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('نعم')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ يجب تسجيل الدخول أولاً')));
        return;
      }

      final vehicleProvider = context.read<VehicleProvider>();
      final ok = await vehicleProvider.removeVehicle(_vehicleId!, uid);
      if (ok) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        await userRef.set({
          'vehicleIds': FieldValue.arrayRemove([_vehicleId])
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم حذف المركبة')));
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ فشل في حذف المركبة')));
      }
    } catch (e) {
      debugPrint('VehicleScreen._deleteVehicle error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل في حذف المركبة: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_vehicleId != null ? 'تعديل المركبة' : 'إضافة مركبة جديدة'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        actions: [
          if (_vehicleId != null)
            IconButton(
              onPressed: _isSaving ? null : _deleteVehicle,
              icon: const Icon(Icons.delete_forever),
              tooltip: 'حذف المركبة',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _plateController,
                            decoration: const InputDecoration(
                              labelText: 'رقم لوحة السيارة',
                              prefixIcon: Icon(Icons.confirmation_number),
                            ),
                            validator: (v) => _requiredValidator('رقم لوحة السيارة', v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'ابحث باللوحة',
                          onPressed: _isLoading ? null : _findByPlate,
                          icon: const Icon(Icons.search),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _vehicleTypeController,
                      decoration: const InputDecoration(
                        labelText: 'نوع المركبة (مثال: حافلة، فان، سيدان)',
                        prefixIcon: Icon(Icons.directions_car),
                      ),
                      validator: (v) => _requiredValidator('نوع المركبة', v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _makeModelYearController,
                      decoration: const InputDecoration(
                        labelText: 'موديل / سنة الصنع',
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                      validator: (v) => _requiredValidator('موديل المركبة', v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _maxCapacityController,
                      decoration: const InputDecoration(
                        labelText: 'الحد الأقصى للركاب (عدد المقاعد)',
                        prefixIcon: Icon(Icons.event_seat),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final err = _requiredValidator('عدد المقاعد', v);
                        if (err != null) return err;
                        final n = int.tryParse(v!.trim());
                        if (n == null || n <= 0) return 'يرجى إدخال عدد مقاعد صالح';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _colorController,
                      decoration: const InputDecoration(
                        labelText: 'اللون (اختياري)',
                        prefixIcon: Icon(Icons.color_lens),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _vehicleOwnerController,
                      decoration: const InputDecoration(
                        labelText: 'اسم مالك المركبة الرسمي (اختياري)',
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _licenseNumberController,
                      decoration: const InputDecoration(
                        labelText: 'رقم رخصة المركبة / ترخيص (اختياري)',
                        prefixIcon: Icon(Icons.card_membership),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات إضافية (اختياري)',
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('موثوقة / تم التحقق منها'),
                      value: _isVerified,
                      onChanged: (val) => setState(() => _isVerified = val),
                      secondary: const Icon(Icons.verified),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveVehicle,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'جاري الحفظ...' : (_vehicleId != null ? 'حفظ التغييرات' : 'إضافة المركبة')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
