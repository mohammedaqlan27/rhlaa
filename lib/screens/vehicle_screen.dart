// lib/screens/vehicle_screen.dart
// شاشة لإضافة / تعديل بيانات المركبة وربطها بالمستخدم
// تحفظ الحقول بصيغة camelCase وتتحقق من الحقول الإلزامية قبل الحفظ.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VehicleScreen extends StatefulWidget {
  /// عند التعديل يمكن تمرير vehicleId عبر constructor أو عبر Navigator arguments
  final String? vehicleId;
  const VehicleScreen({super.key, this.vehicleId});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  // الحقول الأساسية
  final _plateController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _makeModelYearController = TextEditingController();
  final _maxCapacityController = TextEditingController();

  // الحقول الاختيارية
  final _colorController = TextEditingController();
  final _notesController = TextEditingController();
  final _vehicleOwnerController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  bool _isVerified = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _vehicleId; // المعرف الحالي (للتعديل)

  @override
  void initState() {
    super.initState();
    _vehicleId = widget.vehicleId;
    if (_vehicleId != null && _vehicleId!.isNotEmpty) {
      _loadVehicle(_vehicleId!);
    }
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
      _plateController.text = (data['plateNumber'] as String?) ?? '';
      _vehicleTypeController.text = (data['vehicleType'] as String?) ?? '';
      _makeModelYearController.text = (data['makeModelYear'] as String?) ?? '';
      _maxCapacityController.text = (data['maxCapacity']?.toString()) ?? '';
      _colorController.text = (data['color'] as String?) ?? '';
      _notesController.text = (data['notes'] as String?) ?? '';
      _vehicleOwnerController.text = (data['vehicleOwner'] as String?) ?? '';
      _licenseNumberController.text = (data['licenseNumber']?.toString()) ?? '';
      _isVerified = (data['isVerified'] as bool?) ?? false;
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

      final data = <String, dynamic>{
        'plateNumber': plate,
        'vehicleType': vehicleType,
        'makeModelYear': makeModelYear,
        'maxCapacity': maxCapacity,
        'color': color,
        'notes': notes,
        'vehicleOwner': vehicleOwner,
        'licenseNumber': licenseNumber,
        'isVerified': _isVerified,
        'ownerUserId': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // إزالة الحقول الفارغة لتجنّب الكتابة بقيم فارغة غير مرغوبة
      data.removeWhere((k, v) => v == null || (v is String && v.isEmpty));

      final vehiclesRef = FirebaseFirestore.instance.collection('vehicles');

      if (_vehicleId != null && _vehicleId!.isNotEmpty) {
        // تحديث مركبة موجودة
        await vehiclesRef.doc(_vehicleId).update(data);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تحديث بيانات المركبة')));
      } else {
        // إنشاء مركبة جديدة
        final docRef = await vehiclesRef.add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _vehicleId = docRef.id;

        // ربط المركبة بمستخدم (إضافة المعرف إلى مصفوفة vehicleIds في مستند المستخدم)
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        await userRef.set({
          'vehicleIds': FieldValue.arrayUnion([docRef.id])
        }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إضافة المركبة بنجاح')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ يجب تسجيل الدخول أولاً')));
        return;
      }

      await FirebaseFirestore.instance.collection('vehicles').doc(_vehicleId).delete();

      // إزالة المعرف من مصفوفة vehicleIds في مستند المستخدم
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      await userRef.set({
        'vehicleIds': FieldValue.arrayRemove([_vehicleId])
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم حذف المركبة')));
        Navigator.of(context).pop(true);
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
                          TextFormField(
                            controller: _plateController,
                            decoration: const InputDecoration(
                              labelText: 'رقم لوحة السيارة',
                              prefixIcon: Icon(Icons.confirmation_number),
                            ),
                            validator: (v) => _requiredValidator('رقم لوحة السيارة', v),
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
