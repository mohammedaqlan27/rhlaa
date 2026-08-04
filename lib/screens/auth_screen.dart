// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../widgets/shared/custom_button.dart';
import '../widgets/Passenger/otp_dialog.dart'; // استيراد الواجهة الجديدة
import 'loading_screen.dart';

class AuthScreen extends StatefulWidget {
  final String? initialMessage;
  const AuthScreen({super.key, this.initialMessage});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  // المتحكمات (Controllers)
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _carOwnerController = TextEditingController();
  final _licenseController = TextEditingController();

  // حالات الواجهة
  final ValueNotifier<bool> _isDriver = ValueNotifier<bool>(false);
  bool _isLogin = true;
  bool _usePhone = false;
  String _agencyStatus = 'مستقل';

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.initialMessage!)));
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _idNumberController.dispose();
    _plateNumberController.dispose();
    _carOwnerController.dispose();
    _licenseController.dispose();
    _isDriver.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
      _isDriver.value = false;
    });
  }

  // دالة المعالجة الرئيسية (تقرر إرسال OTP أو الدخول المباشر)
  void _handleAuth(AuthState auth) async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    if (_usePhone) {
      // إذا كان يستخدم الهاتف، نبدأ عملية التحقق من الرقم أولاً
      final phoneNumber = _phoneController.text.trim();

      await auth.verifyPhoneNumber(
        phoneNumber,
            (verificationId) {
          // إظهار واجهة إدخال الكود (OTP Dialog)
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => OTPDialog(
              phoneNumber: phoneNumber,
              onConfirm: (otpCode) async {
                final success = await auth.signInWithOTP(otpCode);
                if (success && mounted) {
                  Navigator.pop(context); // إغلاق الدايلوج
                  _submitAuthForm(auth); // إكمال حفظ البيانات في Firestore
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(auth.errorMessage ?? 'كود التحقق غير صحيح'))
                  );
                }
              },
              onResend: () => auth.verifyPhoneNumber(phoneNumber, (vId) {}),
            ),
          );
        },
      );
    } else {
      // إذا كان يستخدم الإيميل، نذهب للتنفيذ مباشرة
      _submitAuthForm(auth);
    }
  }

  // التنفيذ النهائي (حفظ البيانات في Firebase/Firestore)
  Future<void> _submitAuthForm(AuthState auth) async {
    final identifier = _usePhone ? _phoneController.text.trim() : _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final userType = _isDriver.value ? 'Driver' : 'Passenger';

    bool success;
    if (_isLogin) {
      success = await auth.login(identifier, password);
    } else {
      success = await auth.register(
        email: _usePhone ? "$identifier@phone.com" : identifier,
        password: password,
        nickname: _nicknameController.text.isEmpty ? name : _nicknameController.text.trim(),
        userType: userType,
        mobileNumber: _usePhone ? identifier : _phoneController.text.trim(),
        idNumber: _idNumberController.text.trim(),
        plateNumber: _plateNumberController.text.trim(),
        agencyStatus: _agencyStatus,
        drivingLicenseNumber: _licenseController.text.trim(),
      );
    }

    if (!mounted) return;
    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${auth.errorMessage ?? 'حدث خطأ ما'}'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_isLogin ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: auth.isLoading
          ? const LoadingScreen(message: 'جاري المعالجة...')
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildHeader(theme),
            const SizedBox(height: 25),
            _buildAuthCard(auth, theme),
            const SizedBox(height: 20),
            _buildToggleModeButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.directions_bus_filled_rounded, size: 64, color: theme.primaryColor),
        ),
        const SizedBox(height: 16),
        const Text(
          'رُحلاء للسفريات',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
        ),
        const Text('سفرك أسهل، أسرع، وأكثر أماناً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
      ],
    );
  }

  Widget _buildAuthCard(AuthState auth, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildLoginTypeToggle(theme),
              const SizedBox(height: 25),

              if (!_isLogin) ...[
                _buildTextField(controller: _nameController, label: 'الاسم الكامل', icon: Icons.person_outline),
                const SizedBox(height: 15),
              ],

              if (_usePhone)
                _buildTextField(controller: _phoneController, label: 'رقم الهاتف (مثال: +967...)', icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone)
              else
                _buildTextField(controller: _emailController, label: 'البريد الإلكتروني', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),

              const SizedBox(height: 15),
              _buildTextField(controller: _passwordController, label: 'كلمة المرور', icon: Icons.lock_outline, isPassword: true),

              if (!_isLogin) _buildDriverSection(theme),

              const SizedBox(height: 30),
              CustomButton(
                text: _isLogin ? 'تسجيل الدخول' : 'إنشاء الحساب',
                isLoading: auth.isLoading,
                onPressed: () => _handleAuth(auth), // استدعاء دالة المعالجة الذكية
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginTypeToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _buildToggleButton(label: 'البريد', isSelected: !_usePhone, onTap: () => setState(() => _usePhone = false)),
          _buildToggleButton(label: 'الهاتف', isSelected: _usePhone, onTap: () => setState(() => _usePhone = true)),
        ],
      ),
    );
  }

  Widget _buildToggleButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontFamily: 'Cairo', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.blue : Colors.grey)),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverSection(ThemeData theme) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isDriver,
      builder: (context, isDriver, _) {
        return Column(
          children: [
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('التسجيل كـ سائق مركبة', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
              value: isDriver,
              onChanged: (val) => _isDriver.value = val,
              secondary: Icon(Icons.drive_eta_rounded, color: isDriver ? theme.primaryColor : Colors.grey),
            ),
            if (isDriver) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ستكون هذه الخيارات أجبارية عند إنشاءك أول رحلة.',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              _buildTextField(controller: _plateNumberController, label: 'رقم لوحة السيارة (اختياري)', icon: Icons.tag),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _agencyStatus,
                decoration: InputDecoration(
                  labelText: 'تبعية السائق/المركبة',
                  prefixIcon: const Icon(Icons.business_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['مستقل', 'تابع لمكتب سفريات', 'السائق موظف لدى مكتب'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)))).toList(),
                onChanged: (val) => setState(() => _agencyStatus = val!),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (val) => (val == null || val.isEmpty) && !_isLogin && !label.contains('اختياري') ? 'هذا الحقل مطلوب' : null,
    );
  }

  Widget _buildToggleModeButton(ThemeData theme) {
    return TextButton(
      onPressed: _toggleAuthMode,
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'Cairo', color: Colors.black54),
          children: [
            TextSpan(text: _isLogin ? 'ليس لديك حساب؟ ' : 'لديك حساب بالفعل؟ '),
            TextSpan(text: _isLogin ? 'أنشئ حساباً الآن' : 'سجل الدخول', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}