import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _avatarController = TextEditingController();

  // حقول جديدة
  final _idNumberController = TextEditingController(); // رقم البطاقة/جواز السفر
  final _carPlateController = TextEditingController(); // لوحة السيارة
  final _carOwnerController = TextEditingController(); // اسم مالك السيارة
  final _drivingLicenseController = TextEditingController(); // رخصة القيادة

  File? _selectedImage;
  bool _isLoading = false;
  String? _userType; // راكب أو سائق

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
    _idNumberController.dispose();
    _carPlateController.dispose();
    _carOwnerController.dispose();
    _drivingLicenseController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>? ?? {};

      String? readString(List<String> keys) {
        for (final k in keys) {
          final v = data[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
        return null;
      }

      _nicknameController.text = readString(['nickname', 'name']) ?? '';
      _phoneController.text = readString(['mobileNumber', 'phone']) ?? '';
      _avatarController.text = readString(['profilePictureUrl']) ?? '';
      _idNumberController.text = readString(['idNumber', 'fullNameId']) ?? '';
      _carPlateController.text = readString(['carPlateNumber', 'plateNumber']) ?? '';
      _carOwnerController.text = readString(['carOwnerOfficialName', 'vehicleOwner']) ?? '';
      _drivingLicenseController.text = readString(['drivingLicenseNumber', 'licenseNumber']) ?? '';
      _userType = readString(['userType']); // passenger أو driver

      setState(() {});
    } catch (e) {
      debugPrint('EditProfileScreen._loadUserData error: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _avatarController.text = picked.path;
        });
      }
    } catch (e) {
      debugPrint('EditProfileScreen._pickImage error: $e');
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول أولاً')));
      return;
    }

    try {
      final updateData = <String, dynamic>{
        'nickname': _nicknameController.text.trim(),
        'mobileNumber': _phoneController.text.trim(),
        'profilePictureUrl': _avatarController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'carPlateNumber': _carPlateController.text.trim(),
        'carOwnerOfficialName': _carOwnerController.text.trim(),
        'drivingLicenseNumber': _drivingLicenseController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      updateData.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

      await FirebaseFirestore.instance.collection('users').doc(uid).update(updateData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تحديث الملف الشخصي بنجاح')));
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('EditProfileScreen._saveChanges error: $e');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل تحديث الملف الشخصي: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneRegex = RegExp(r'^(?:\+?\d{7,15})$');

    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الملف الشخصي'), backgroundColor: Colors.blue.shade900),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: _selectedImage != null
                                  ? FileImage(_selectedImage!)
                                  : (_avatarController.text.isNotEmpty ? NetworkImage(_avatarController.text) : null) as ImageProvider<Object>?,
                              child: _selectedImage == null && _avatarController.text.isEmpty ? const Icon(Icons.camera_alt, size: 40) : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(_nicknameController, 'الاسم الكامل', icon: Icons.person),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _phoneController,
                          'رقم الهاتف',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'يرجى إدخال رقم الهاتف';
                            if (!phoneRegex.hasMatch(value.trim())) return 'رقم الهاتف غير صالح';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(_idNumberController, 'رقم البطاقة / جواز السفر', icon: Icons.credit_card),
                        const SizedBox(height: 16),
                        _buildTextField(_avatarController, 'رابط الصورة (اختياري)', icon: Icons.link, keyboardType: TextInputType.url, validator: (val) => null),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('بيانات المركبة', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _buildTextField(_carPlateController, 'رقم لوحة السيارة (إلزامي للسائق)', icon: Icons.confirmation_number),
                        const SizedBox(height: 12),
                        _buildTextField(_carOwnerController, 'اسم مالك المركبة الرسمي (اختياري)', icon: Icons.badge, validator: (val) => null),
                        const SizedBox(height: 12),
                        _buildTextField(_drivingLicenseController, 'رقم رخصة القيادة (اختياري)', icon: Icons.card_membership, validator: (val) => null),
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          onPressed: _saveChanges,
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ التغييرات'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, minimumSize: const Size.fromHeight(50)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {IconData icon = Icons.edit, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
      keyboardType: keyboardType,
      validator: validator ?? (val) => val == null || val.isEmpty ? 'يرجى إدخال $label' : null,
    );
  }
}
