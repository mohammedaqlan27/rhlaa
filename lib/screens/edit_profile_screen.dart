// lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/shared/app_card.dart';
import '../widgets/shared/custom_button.dart';
import '../widgets/shared/custom_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // المتحكمات
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _avatarController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _plateController = TextEditingController();
  final _carOwnerController = TextEditingController();
  final _drivingLicenseController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;
  String? _userType;

  // لوحة الألوان المعتمدة (Design System)
  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _accentTeal = Color(0xFF17A5A3);
  static const Color _surfaceWhite = Color(0xFFFFFFFF);
  static const Color _backgroundGrey = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    for (var controller in [
      _nicknameController, _phoneController, _avatarController,
      _idNumberController, _plateController, _carOwnerController,
      _drivingLicenseController
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};

        _nicknameController.text = data['nickname'] ?? data['name'] ?? '';
        _phoneController.text = data['mobileNumber'] ?? data['phone'] ?? '';
        _avatarController.text = data['profilePictureUrl'] ?? '';
        _idNumberController.text = data['idNumber'] ?? '';
        _plateController.text = data['carPlateNumber'] ?? data['PlateNumber'] ?? '';
        _carOwnerController.text = data['carOwnerOfficialName'] ?? '';
        _drivingLicenseController.text = data['drivingLicenseNumber'] ?? '';
        _userType = data['userType']?.toString().toLowerCase();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _avatarController.text = picked.path;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      final bool isDriver = _userType == 'driver' || _userType == 'سائق';

      final updateData = <String, dynamic>{
        'nickname': _nicknameController.text.trim(),
        'mobileNumber': _phoneController.text.trim(),
        'profilePictureUrl': _avatarController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // إضافة بيانات المركبة فقط إذا كان المستخدم سائقاً
      if (isDriver) {
        updateData.addAll({
          'carPlateNumber': _plateController.text.trim(),
          'carOwnerOfficialName': _carOwnerController.text.trim(),
          'drivingLicenseNumber': _drivingLicenseController.text.trim(),
        });
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حفظ التغييرات بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDriver = _userType == 'driver' || _userType == 'سائق';

    return Scaffold(
      backgroundColor: _backgroundGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surfaceWhite,
        title: const Text('تعديل الحساب',
            style: TextStyle(color: _textDark, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeaderSection(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('المعلومات الشخصية', Icons.person_outline),
                    _buildBasicInfoFields(),

                    if (isDriver) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('بيانات التوثيق والمركبة', Icons.directions_car_filled_outlined),
                      _buildDriverFields(),
                    ],

                    const SizedBox(height: 40),
                    CustomButton(
                      onPressed: _saveChanges,
                      text: 'حفظ التغييرات',
                      icon: Icons.check_circle_outline,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: const BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _primaryBlue.withOpacity(0.2), width: 4),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: _backgroundGrey,
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : (_avatarController.text.isNotEmpty ? NetworkImage(_avatarController.text) : null) as ImageProvider?,
                  child: _avatarController.text.isEmpty && _selectedImage == null
                      ? const Icon(Icons.person, size: 60, color: Colors.grey)
                      : null,
                ),
              ),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: _primaryBlue, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_userType == 'driver' ? 'حساب كابتن' : 'حساب مسافر',
              style: TextStyle(color: _accentTeal, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _primaryBlue),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: _textDark)),
        ],
      ),
    );
  }

  Widget _buildBasicInfoFields() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CustomTextField(
            controller: _nicknameController,
            label: 'الاسم بالكامل',
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _phoneController,
            label: 'رقم الجوال',
            prefixIcon: Icons.phone_android,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _idNumberController,
            label: 'رقم الهوية / جواز السفر',
            prefixIcon: Icons.fingerprint,
          ),
        ],
      ),
    );
  }

  Widget _buildDriverFields() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CustomTextField(
            controller: _plateController,
            label: 'رقم لوحة المركبة',
            prefixIcon: Icons.numbers,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _carOwnerController,
            label: 'اسم مالك المركبة',
            prefixIcon: Icons.person_search,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _drivingLicenseController,
            label: 'رقم رخصة القيادة',
            prefixIcon: Icons.card_membership,
          ),
        ],
      ),
    );
  }
}