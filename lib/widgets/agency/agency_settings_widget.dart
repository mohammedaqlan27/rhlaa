// lib/widgets/agency/agency_settings_widget.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../state/auth_state.dart';
import '../../providers/agencies_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/shared/custom_button.dart';
import '../../utils/app_localizations.dart';

/// ودجت إعدادات المكتب القابل لإعادة الاستخدام
/// - يحمل بيانات المكتب المرتبط بالمستخدم الحالي أو حسب agencyId إن مرر
/// - يوفّر تحرير الحقول الأساسية، تبديل حالة التفعيل، وحفظ التعديلات عبر AgenciesProvider
/// - يوفّر روابط سريعة لإدارة المحفظة وسجل المعاملات وفتح واجهة المكتب
class AgencySettingsWidget extends StatefulWidget {
  final String? agencyId;
  const AgencySettingsWidget({Key? key, this.agencyId}) : super(key: key);

  @override
  State<AgencySettingsWidget> createState() => _AgencySettingsWidgetState();
}

class _AgencySettingsWidgetState extends State<AgencySettingsWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _managerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _isActive = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = Provider.of<AgenciesProvider>(context, listen: false);
      if (widget.agencyId != null && widget.agencyId!.isNotEmpty) {
        prov.loadAgencyById(widget.agencyId!).then((_) => _applyAgency(prov.currentAgency));
      } else {
        prov.loadAgencyForCurrentUser().then((_) => _applyAgency(prov.currentAgency));
      }
    });
  }

  void _applyAgency(dynamic a) {
    if (!mounted) return;
    if (a == null) return;
    try {
      _nameCtrl.text = a.agencyName ?? '';
      _managerCtrl.text = a.managerName ?? '';
      _phoneCtrl.text = a.mobileNumber ?? '';
      _locationCtrl.text = a.location is String ? a.location as String : '';
      _isActive = a.isActive ?? true;
    } catch (_) {
      // إذا كانت البنية مختلفة، نتجاهل القيم الفارغة
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _managerCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = Provider.of<AgenciesProvider>(context, listen: false);
    final agency = prov.currentAgency;
    if (agency == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد مكتب للحفظ')));
      return;
    }

    setState(() => _loading = true);
    final updates = <String, dynamic>{
      'agencyName': _nameCtrl.text.trim(),
      'managerName': _managerCtrl.text.trim(),
      'mobileNumber': _phoneCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'isActive': _isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final success = await prov.updateAgency(agency.id, updates);
    setState(() => _loading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات المكتب')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: ${prov.error ?? ''}')));
    }
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(context.t('language'), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('العربية', style: TextStyle(fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.pop(ctx);
                  AppLocalizations.load(const Locale('ar'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('English', style: TextStyle(fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.pop(ctx);
                  AppLocalizations.load(const Locale('en'));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<AgenciesProvider>(context);
    final auth = Provider.of<AuthState>(context, listen: false);
    final themeProv = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          color: isDark ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.95),
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text('إعدادات المكتب', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      IconButton(
                        icon: const Icon(Icons.language),
                        tooltip: context.t('language'),
                        onPressed: _showLanguageDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // --- نموذج تحرير بيانات المكتب ---
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'اسم المكتب', prefixIcon: Icon(Icons.business)),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _managerCtrl,
                              decoration: const InputDecoration(labelText: 'اسم المدير', prefixIcon: Icon(Icons.person)),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone)),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _locationCtrl,
                              decoration: const InputDecoration(labelText: 'الموقع', prefixIcon: Icon(Icons.location_on)),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('المكتب مفعل'),
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _loading ? null : _save,
                                    icon: _loading ? const SizedBox.shrink() : const Icon(Icons.save),
                                    label: _loading ? const Text('جاري الحفظ...') : const Text('حفظ'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // --- خيارات عامة ومخصصة للمكتب ---
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.account_circle, color: Colors.blue),
                          ),
                          title: Text(context.t('profile')),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
                            Navigator.pushNamed(context, '/profile');
                          },
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.lock_outline, color: Colors.blue),
                          ),
                          title: Text(context.t('privacy')),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => Navigator.pushNamed(context, '/privacy'),
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.notifications_outlined, color: Colors.blue),
                          ),
                          title: Text(context.t('notifications')),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => Navigator.pushNamed(context, '/notifications'),
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.support_agent, color: Colors.blue),
                          ),
                          title: Text(context.t('help_center')),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => Navigator.pushNamed(context, '/help_center'),
                        ),

                        // إدارة المحفظة (خاص بالمكاتب)
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                          ),
                          title: const Text('إدارة المحفظة'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
                            final id = prov.currentAgency?.id;
                            if (id != null) {
                              Navigator.pushNamed(context, '/agency_wallet', arguments: {'agencyId': id});
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد مكتب محدد')));
                            }
                          },
                        ),

                        // سجل المعاملات
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.list_alt, color: Colors.blue),
                          ),
                          title: const Text('سجل المعاملات'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
                            final id = prov.currentAgency?.id;
                            if (id != null) {
                              Navigator.pushNamed(context, '/agency_transactions', arguments: {'agencyId': id});
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد مكتب محدد')));
                            }
                          },
                        ),

                        // إعدادات متقدمة (يفتح نفس الشاشة أو شاشة منفصلة حسب الحاجة)
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.settings, color: Colors.blue),
                          ),
                          title: const Text('إعدادات متقدمة للمكتب'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
                            Navigator.pushNamed(context, '/agency_settings');
                          },
                        ),

                        // تبديل الثيم (مكرر هنا لسهولة الوصول داخل إعدادات المكتب)
                        SwitchListTile(
                          secondary: const Icon(Icons.brightness_6_outlined, color: Colors.blue),
                          title: Text(isDark ? 'الوضع الفاتح' : 'الوضع الداكن'),
                          value: isDark,
                          onChanged: (val) {
                            final themeMode = val ? ThemeMode.dark : ThemeMode.light;
                            themeProv.setThemeMode(themeMode);
                          },
                        ),

                        // تسجيل الخروج
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.logout, color: Colors.red),
                          ),
                          title: Text(context.t('logout')),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () async {
                            await auth.logout();
                            Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  CustomButton(text: context.t('close'), compact: true, onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on ThemeProvider {
  void setThemeMode(ThemeMode themeMode) {}
}
