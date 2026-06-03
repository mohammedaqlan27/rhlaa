// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import 'loading_screen.dart';

class AuthScreen extends StatefulWidget {
  final String? initialMessage;
  const AuthScreen({super.key, this.initialMessage});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();

  // حقول جديدة للتسجيل
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _carOwnerController = TextEditingController();
  final _licenseController = TextEditingController();

  final _isDriver = ValueNotifier<bool>(false);
  bool _isFamily = false;
  bool _isLogin = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.initialMessage!)),
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
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
      _emailController.clear();
      _passwordController.clear();
      _nameController.clear();
      _nicknameController.clear();
      _phoneController.clear();
      _idNumberController.clear();
      _plateNumberController.clear();
      _carOwnerController.clear();
      _licenseController.clear();
      _isDriver.value = false;
      _isFamily = false;
    });
  }

  Future<void> _submitAuthForm(AuthState auth) async {
    if (_formKey.currentState == null) return;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final nicknameInput = _nicknameController.text.trim();
    final nameInput = _nameController.text.trim();
    final nickname = nicknameInput.isNotEmpty ? nicknameInput : (nameInput.isNotEmpty ? nameInput : 'مستخدم');

    final userType = _isDriver.value ? 'Driver' : 'Passenger';

    if (_isLogin) {
      final success = await auth.login(email, password);
      if (!mounted) return;

      // use firebaseUser getter from AuthState
      if (success && auth.firebaseUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تسجيل الدخول بنجاح')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      } else {
        final msg = auth.errorMessage ?? 'فشل تسجيل الدخول';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $msg')));
      }
    } else {
      try {
        // نمرر الحقول الجديدة إلى دالة التسجيل في AuthState
        final success = await auth.register(
          email: email,
          password: password,
          nickname: nickname,
          userType: userType,
          mobileNumber: _phoneController.text.trim(),
          idNumber: _idNumberController.text.trim(),
          plateNumber: _isDriver.value ? _plateNumberController.text.trim() : null,
          carOwnerOfficialName: _carOwnerController.text.trim(),
          drivingLicenseNumber: _licenseController.text.trim(),
        );

        if (!mounted) return;

        // use firebaseUser getter from AuthState
        if (success && auth.firebaseUser != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم إنشاء الحساب بنجاح')),
          );
          Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
        } else {
          final msg = auth.errorMessage ?? 'فشل التسجيل';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $msg')));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ في التسجيل: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildFormFields(AuthState auth) {
    final isLoading = auth.isLoading;
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 48, color: Color(0xFF1E88E5)),
          const SizedBox(height: 16),
          Text(
            _isLogin ? 'تسجيل الدخول إلى حسابك' : 'أنشئ حسابك لبدء الرحلة',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          if (!_isLogin) ...[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (val) {
                if (_isLogin) return null;
                return val == null || val.isEmpty ? 'الاسم الكامل مطلوب' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'اسم العرض (اختياري)',
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 12),

            // رقم الهاتف إلزامي عند التسجيل
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (val) {
                if (_isLogin) return null;
                return val == null || val.isEmpty ? 'رقم الهاتف مطلوب' : null;
              },
            ),
            const SizedBox(height: 12),

            // رقم البطاقة / جواز السفر إلزامي عند التسجيل
            TextFormField(
              controller: _idNumberController,
              decoration: const InputDecoration(
                labelText: 'رقم البطاقة / جواز السفر',
                prefixIcon: Icon(Icons.credit_card),
              ),
              validator: (val) {
                if (_isLogin) return null;
                return val == null || val.isEmpty ? 'رقم البطاقة أو الجواز مطلوب' : null;
              },
            ),
            const SizedBox(height: 12),
          ],

          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'البريد الإلكتروني',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (val) => val == null || !val.contains('@') ? 'صيغة البريد غير صحيحة' : null,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
            validator: (val) => val == null || val.length < 6 ? 'كلمة المرور قصيرة جداً' : null,
          ),
          const SizedBox(height: 12),

          if (!_isLogin) ...[
            ValueListenableBuilder<bool>(
              valueListenable: _isDriver,
              builder: (context, value, _) => SwitchListTile(
                title: Text(value ? 'أريد التسجيل كسائق' : 'أريد التسجيل كمسافر'),
                value: value,
                onChanged: (val) => _isDriver.value = val,
                secondary: const Icon(Icons.directions_car),
              ),
            ),

            // إذا اختار المستخدم أنه سائق، نظهر حقول المركبة الإلزامية/الاختيارية
            ValueListenableBuilder<bool>(
              valueListenable: _isDriver,
              builder: (context, isDriver, _) {
                if (!isDriver) return const SizedBox.shrink();
                return Column(
                  children: [
                    TextFormField(
                      controller: _plateNumberController,
                      decoration: const InputDecoration(
                        labelText: 'رقم لوحة السيارة',
                        prefixIcon: Icon(Icons.confirmation_number),
                      ),
                      validator: (val) {
                        if (!isDriver) return null;
                        return val == null || val.isEmpty ? 'لوحة السيارة مطلوبة للسائق' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _carOwnerController,
                      decoration: const InputDecoration(
                        labelText: 'اسم مالك السيارة (اختياري)',
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _licenseController,
                      decoration: const InputDecoration(
                        labelText: 'رقم رخصة القيادة (اختياري)',
                        prefixIcon: Icon(Icons.card_membership),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),

            SwitchListTile(
              title: Text(_isFamily ? 'حجز الرحلات للعائلة' : 'حجز الرحلات كفرد'),
              value: _isFamily,
              onChanged: (val) => setState(() => _isFamily = val),
              secondary: Icon(_isFamily ? Icons.family_restroom : Icons.person),
            ),
            const SizedBox(height: 20),
          ],

          ElevatedButton.icon(
            onPressed: isLoading ? null : () => _submitAuthForm(auth),
            icon: isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_isLogin ? Icons.login : Icons.person_add),
            label: Text(_isLogin ? 'تسجيل الدخول' : 'إنشاء حساب'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: _toggleAuthMode,
            child: Text(
              _isLogin ? 'ليس لديك حساب؟ أنشئ واحداً' : 'لديك حساب؟ سجل الدخول',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'تسجيل الدخول' : 'إنشاء حساب'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: auth.isLoading
            ? const LoadingScreen(message: 'جاري معالجة طلبك، يرجى الانتظار...')
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _buildFormFields(auth),
                  ),
                ),
              ),
      ),
    );
  }
}
