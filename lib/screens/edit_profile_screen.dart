// lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_card.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

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

  final _idNumberController = TextEditingController();
  final _PlateController = TextEditingController();
  final _carOwnerController = TextEditingController();
  final _drivingLicenseController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;
  String? _userType;

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoTeal = Color(0xFF17A5A3);
  static const Color _baseBg = Color(0xFFF1F5F9);

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
    _PlateController.dispose();
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

      final data = doc.data() ?? {};

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
      _PlateController.text = readString(['PlateNumber', 'plateNumber']) ?? '';
      _carOwnerController.text = readString(['carOwnerOfficialName', 'vehicleOwner']) ?? '';
      _drivingLicenseController.text = readString(['drivingLicenseNumber', 'licenseNumber']) ?? '';
      _userType = readString(['userType']);

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول أولاً', style: TextStyle(fontFamily: 'Cairo'))));
      }
      return;
    }

    try {
      final updateData = <String, dynamic>{
        'nickname': _nicknameController.text.trim(),
        'mobileNumber': _phoneController.text.trim(),
        'profilePictureUrl': _avatarController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'carPlateNumber': _PlateController.text.trim(),
        'carOwnerOfficialName': _carOwnerController.text.trim(),
        'drivingLicenseNumber': _drivingLicenseController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      updateData.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

      await FirebaseFirestore.instance.collection('users').doc(uid).update(updateData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تحديث ملفك الشخصي بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('EditProfileScreen._saveChanges error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل التحديث: $e', style: const TextStyle(fontFamily: 'Cairo'))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneRegex = RegExp(r'^(?:\+?\d{7,15})$');
    final bool isDriver = (_userType?.toLowerCase().contains('driver') ?? false) || (_userType?.contains('سائق') ?? false);

    return Scaffold(
      backgroundColor: _baseBg,
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: _baseBg,
        foregroundColor: _logoBlue,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_logoBlue)))
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // حاوية نيومورفية بيضاوية للصورة الشخصية
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _baseBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFCBD5E1).withOpacity(0.6), blurRadius: 12, offset: const Offset(4, 4)),
                      const BoxShadow(color: Colors.white, blurRadius: 12, offset: Offset(-4, -4)),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: _logoBlue.withOpacity(0.1),
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (_avatarController.text.isNotEmpty && !_avatarController.text.startsWith('/')
                        ? NetworkImage(_avatarController.text)
                        : null) as ImageProvider<Object>?,
                    child: _selectedImage == null && (_avatarController.text.isEmpty || _avatarController.text.startsWith('/'))
                        ? const Icon(Icons.camera_enhance_rounded, size: 32, color: _logoBlue)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // كارت نيومورفي للبيانات الشخصية الأساسية
            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CustomTextField(controller: _nicknameController, label: 'الاسم الكامل', prefixIcon: Icons.person_rounded),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    prefixIcon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'يرجى إدخال رقم الهاتف';
                      if (!phoneRegex.hasMatch(value.trim())) return 'رقم الهاتف غير صحيح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(controller: _idNumberController, label: 'رقم البطاقة الشخصية / جواز السفر', prefixIcon: Icons.badge_rounded),
                  const SizedBox(height: 16),
                  CustomTextField(
                      controller: _avatarController,
                      label: 'رابط الصورة الشخصية (اختياري)',
                      prefixIcon: Icons.link_rounded,
                      keyboardType: TextInputType.url,
                      validator: (val) => null
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // قسم بيانات المركبة (يظهر بشكل أوضح ومخصص للسائقين)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 8),
              child: Text(
                  'بيانات المركبة والتوثيق',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: isDriver ? _logoTeal : Colors.black54)
              ),
            ),

            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CustomTextField(
                    controller: _PlateController,
                    label: 'رقم لوحة السيارة ${isDriver ? "(مطلوب للقيادة)" : "(اختياري)"}',
                    prefixIcon: Icons.pin_rounded,
                    validator: (val) => isDriver && (val == null || val.isEmpty) ? 'بيانات اللوحة مطلوبة كابتن!' : null,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(controller: _carOwnerController, label: 'اسم مالك المركبة الرسمي', prefixIcon: Icons.assignment_ind_rounded, validator: (val) => null),
                  const SizedBox(height: 16),
                  CustomTextField(controller: _drivingLicenseController, label: 'رقم رخصة القيادة', prefixIcon: Icons.card_membership_rounded, validator: (val) => null),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // زر الحفظ النيومورفي المطور
            CustomButton(
              onPressed: _saveChanges,
              text: 'حفظ التغييرات الجديدة',
              icon: Icons.save_rounded,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}