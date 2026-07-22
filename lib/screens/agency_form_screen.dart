// lib/screens/agency_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/agencies_provider.dart';
import '../models/agency.dart';
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
      appBar: AppBar(title: Text(isEdit ? 'تعديل المكتب' : 'إنشاء مكتب جديد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم المكتب'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل اسم المكتب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _managerCtrl,
                decoration: const InputDecoration(labelText: 'اسم المدير'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل اسم المدير' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobileCtrl,
                decoration: const InputDecoration(labelText: 'رقم الجوال'),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل رقم الجوال' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _balanceCtrl,
                decoration: const InputDecoration(labelText: 'رصيد المحفظة الابتدائي'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'أدخل قيمة الرصيد';
                  final parsed = double.tryParse(v);
                  if (parsed == null) return 'أدخل قيمة رقمية صحيحة';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('المكتب مفعل'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 20),
              _submitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: () async {
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
                      // إذا أردت تحديث الرصيد مباشرة، استخدم update + credit/debit عبر provider
                      await provider.updateAgency(widget.agency!.id, updates);
                      // إذا تغير الرصيد، نستخدم debit/credit منفصل
                      final currentBalance = widget.agency!.walletBalance;
                      if ((balance - currentBalance).abs() > 0.001) {
                        final diff = balance - currentBalance;
                        if (diff > 0) {
                          await provider.creditAgencyWallet(widget.agency!.id, diff);
                        } else {
                          await provider.debitAgencyWallet(widget.agency!.id, diff.abs());
                        }
                      }
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحديث')));
                      Navigator.of(context).pop(true);
                    } else {
                      final created = await provider.createAgency(
                        agencyName: name,
                        managerName: manager,
                        location: null,
                        mobileNumber: mobile,
                        initialBalance: balance,
                      );
                      if (created) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الإنشاء')));
                        Navigator.of(context).pop(true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الإنشاء')));
                      }
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
                child: Text(isEdit ? 'حفظ التغييرات' : 'إنشاء المكتب'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
