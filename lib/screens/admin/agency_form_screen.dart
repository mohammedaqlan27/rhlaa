// lib/screens/agency_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/agencies_provider.dart';
import '../../models/agency.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgencyFormScreen extends StatefulWidget {
  final Agency? agency;
  const AgencyFormScreen({super.key, this.agency});

  @override
  State<AgencyFormScreen> createState() => _AgencyFormScreenState();
}

class _AgencyFormScreenState extends State<AgencyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _managerCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _balanceCtrl;
  bool _isActive = true;
  bool _submitting = false;

  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _bgGrey = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    final a = widget.agency;
    _nameCtrl = TextEditingController(text: a?.agencyName ?? '');
    _managerCtrl = TextEditingController(text: a?.managerName ?? '');
    _mobileCtrl = TextEditingController(text: a?.mobileNumber ?? '');
    _balanceCtrl = TextEditingController(text: a != null ? a.walletBalance.toStringAsFixed(2) : '0.0');
    _isActive = a?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _managerCtrl.dispose();
    _mobileCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AgenciesProvider>(context, listen: false);
    final isEdit = widget.agency != null;

    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _primaryBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? 'تعديل بيانات المكتب' : 'إنشاء مكتب جديد',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _textDark, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('المعلومات الأساسية'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameCtrl,
                label: 'اسم المكتب أو الوكالة',
                icon: Icons.storefront,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم المكتب' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _managerCtrl,
                label: 'اسم المدير المسؤول',
                icon: Icons.person_outline,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم المدير' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _mobileCtrl,
                label: 'رقم الهاتف / الجوال',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'يرجى إدخال رقم الجوال';
                  if (v.trim().length < 8) return 'أدخل رقم جوال صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('المالية والحالة'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _balanceCtrl,
                label: 'رصيد المحفظة الابتدائي (ر.ي)',
                icon: Icons.account_balance_wallet_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'أدخل قيمة الرصيد';
                  final parsed = double.tryParse(v);
                  if (parsed == null || parsed < 0) return 'أدخل مبلغاً صحيحاً';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withAlpha(50)),
                ),
                child: SwitchListTile(
                  activeColor: _primaryBlue,
                  title: const Text('حالة المكتب (مفعل)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('عند التعطيل لن يتمكن المسافرون من رؤية المكتب', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _submitting ? null : () => _submitForm(provider, isEdit),
                  child: _submitting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                    isEdit ? 'حفظ التغييرات' : 'إنشاء المكتب الآن',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: _primaryBlue),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: _textDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
          prefixIcon: Icon(icon, color: _primaryBlue, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        validator: validator,
      ),
    );
  }

  Future<void> _submitForm(AgenciesProvider provider, bool isEdit) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final name = _nameCtrl.text.trim();
    final manager = _managerCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final balance = double.tryParse(_balanceCtrl.text.trim()) ?? 0.0;

    try {
      if (isEdit) {
        final updates = <String, dynamic>{
          'agencyName': name,
          'managerName': manager,
          'mobileNumber': mobile,
          'isActive': _isActive,
          'updatedAt': Timestamp.now(),
        };

        await provider.updateAgency(widget.agency!.id, updates);

        final currentBalance = widget.agency!.walletBalance;
        if ((balance - currentBalance).abs() > 0.001) {
          final diff = balance - currentBalance;
          if (diff > 0) {
            await provider.creditAgencyWallet(widget.agency!.id, diff, performedBy: 'admin_edit');
          } else {
            await provider.debitAgencyWallet(widget.agency!.id, diff.abs(), performedBy: 'admin_edit');
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث بيانات المكتب بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
          Navigator.of(context).pop(true);
        }
      } else {
        final created = await provider.createAgency(
          agencyName: name,
          managerName: manager,
          location: null,
          mobileNumber: mobile,
          initialBalance: balance,
        );
        if (created) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء المكتب بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
            Navigator.of(context).pop(true);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل عملية إنشاء المكتب', style: TextStyle(fontFamily: 'Cairo'))));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}