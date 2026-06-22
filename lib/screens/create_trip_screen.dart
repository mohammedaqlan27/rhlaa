import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/user_service.dart';
import 'edit_profile_screen.dart';
import '../services/trip_service.dart';
import '../models/trip.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _flexibleWindowController = TextEditingController();

  String? _driverCarPlateNumber;
  String? _driverCarOwnerOfficialName;
  bool _isLoadingUserData = true;
  bool _isSubmitting = false;

  // مستخلص ألوان اللوجو لتطبيق رحلاء
  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _logoGreen = const Color(0xFF4EBF64);
  final Color _backgroundColor = const Color(0xFFF8FAFC);

  final List<String> origins = ['صنعاء', 'عدن', 'تعز', 'الحديدة'];
  final List<String> titles = ['رحلة صنعاء إلى عدن', 'رحلة عدن إلى تعز', 'رحلة تعز إلى صنعاء', 'رحلة خاصة'];
  final List<String> times = ['صباحًا', 'مساءً'];
  final List<String> currencies = ['ريال يمني', 'ريال سعودي'];
  final List<String> carTypes = ['سيارة سيدان', 'سيارة دفع رباعي', 'سيارة فان'];
  final List<String> tripCategories = ['داخلية', 'خارجية'];

  String _selectedOrigin = 'صنعاء';
  String _selectedDestination = 'عدن';
  String _selectedTitle = 'رحلة صنعاء إلى عدن';
  String _selectedTime = 'صباحًا';
  String _selectedCurrency = 'ريال يمني';
  String _carType = 'سيارة سيدان';
  String _tripCategory = 'داخلية';
  int _totalSeats = 4;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchDriverData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    _flexibleWindowController.dispose();
    super.dispose();
  }

  Future<void> _fetchDriverData() async {
    if (!mounted) return;
    setState(() => _isLoadingUserData = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingUserData = false);
      return;
    }

    try {
      UserService? userService;
      try {
        userService = Provider.of<UserService>(context, listen: false);
      } catch (_) {}

      if (userService != null) {
        final appUser = await userService.getUserById(user.uid);
        if (appUser != null) {
          _driverCarPlateNumber = appUser.carPlateNumber;
          _driverCarOwnerOfficialName = appUser.carOwnerOfficialName;
          setState(() => _isLoadingUserData = false);
          return;
        }
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();

      if (data != null) {
        setState(() {
          _driverCarPlateNumber = (data['plate_number'] ?? data['carPlateNumber']) as String?;
          _driverCarOwnerOfficialName = (data['vehicle_owner'] ?? data['carOwnerOfficialName']) as String?;
        });
      }
    } catch (e) {
      _showSnackBar('❌ فشل في جلب بيانات السائق: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Cairo'))),
    );
  }

  bool _validatePrice() {
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    if (_selectedTitle == 'رحلة صنعاء إلى عدن' && _selectedCurrency == 'ريال يمني') {
      if (price < 8000 || price > 14000) {
        _showSnackBar('❌ السعر خارج النطاق المسموح (8000–14000 ريال يمني)');
        return false;
      }
    }
    if (price <= 0) {
      _showSnackBar('❌ يرجى إدخال سعر صالح للرحلة');
      return false;
    }
    return true;
  }

  Future<bool> _ensureProfileCompleteForDriver() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};

    final userType = (data['user_type'] ?? data['userType'] ?? '').toString().toLowerCase();
    if (userType != 'driver' && userType != 'سائق') {
      _showSnackBar('❌ عذراً، الحسابات المعرفة كمسافرين لا يمكنها إنشاء رحلات');
      return false;
    }

    final plate = (data['plate_number'] ?? data['carPlateNumber'] ?? '') as String;
    final owner = (data['vehicle_owner'] ?? data['carOwnerOfficialName'] ?? '') as String;

    if (plate.trim().isEmpty || owner.trim().isEmpty) {
      if (!mounted) return false;
      final goToProfile = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Icon(Icons.directions_car_filled_outlined, size: 50, color: _logoBlue),
              const SizedBox(height: 16),
              const Text('إكمال بيانات المركبة مطلوب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('يتطلب نظام رحلاء إدخال رقم اللوحة والمستندات الرسمية لضمان سلامة الركاب.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _logoBlue, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تعديل الملف الشخصي', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      );

      if (goToProfile == true) {
        if (!mounted) return false;
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
        await _fetchDriverData();
        return await _ensureProfileCompleteForDriver();
      }
      return false;
    }
    return true;
  }

  Future<void> _submitTrip() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate() || _isLoadingUserData) return;
    if (!_validatePrice()) return;

    setState(() => _isSubmitting = true);

    try {
      final ok = await _ensureProfileCompleteForDriver();
      if (!ok) {
        setState(() => _isSubmitting = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      final plate = _driverCarPlateNumber ?? 'غير متوفر';
      final owner = _driverCarOwnerOfficialName ?? 'غير متوفر';

      final Map<String, dynamic> tripMap = {
        'title': _selectedTitle,
        'description': _descriptionController.text.trim(),
        'driverId': user.uid,
        'driverName': user.displayName ?? 'سائق رحلاء',
        'tripCategory': _tripCategory,
        'origin': _selectedOrigin,
        'destination': _selectedDestination,
        'vehicleType': _carType,
        'totalSeats': _totalSeats,
        'availableSeats': _totalSeats,
        'seatStatus': List<bool>.filled(_totalSeats, true),
        'departureTime': Timestamp.fromDate(_selectedDate),
        'date': Timestamp.fromDate(_selectedDate),
        'time': _selectedTime,
        'flexibleWindow': _flexibleWindowController.text.trim(),
        'status': 'active',
        'price': price,
        'carPlateNumber': plate,
        'carOwnerOfficialName': owner,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('trips').add(tripMap);
      _showSnackBar('✅ تم إدراج رحلتك بنجاح في نظام رحلاء');
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _showSnackBar('❌ خطأ في الحفظ المباشر: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('جدولة رحلة جديدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoadingUserData
          ? Center(child: CircularProgressIndicator(color: _logoBlue))
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📍 مسار وجهة الرحلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _logoBlue)),
                        const Divider(),
                        _buildDropdown('عنوان الرحلة', _selectedTitle, titles, (val) => setState(() => _selectedTitle = val)),
                        Row(
                          children: [
                            Expanded(child: _buildDropdown('نقطة الانطلاق', _selectedOrigin, origins, (val) => setState(() => _selectedOrigin = val))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildDropdown('الوجهة النهائية', _selectedDestination, origins, (val) => setState(() => _selectedDestination = val))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('💰 التسعير والركاب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _logoTeal)),
                        const Divider(),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_priceController, 'السعر', keyboardType: TextInputType.number, icon: Icons.monetization_on_outlined)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildDropdown('العملة', _selectedCurrency, currencies, (val) => setState(() => _selectedCurrency = val))),
                          ],
                        ),
                        _buildDropdown('توقيت الحركة العام', _selectedTime, times, (val) => setState(() => _selectedTime = val)),
                        _buildDropdown('فئة نوع السيارة وطرازها', _carType, carTypes, (val) => setState(() => _carType = val)),
                        _buildDropdown('عدد المقاعد المتاحة بالمركبة', _totalSeats, List.generate(10, (i) => i + 1), (val) => setState(() => _totalSeats = val)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text('📅 تاريخ الانطلاق: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                    trailing: Icon(Icons.calendar_month_outlined, color: _logoBlue),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitTrip,
                  icon: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_road_rounded, color: Colors.white),
                  label: Text(_isSubmitting ? 'جاري بث الرحلة للمسافرين...' : 'تأكيد ونشر الرحلة الآن', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _logoGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>(String label, T currentValue, List<T> items, void Function(T) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<T>(
        value: currentValue,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item.toString(), style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)))).toList(),
        onChanged: (val) { if (val != null) onChanged(val); },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey[600]),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _logoBlue)),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {TextInputType keyboardType = TextInputType.text, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey[600]),
          prefixIcon: Icon(icon, size: 20, color: _logoTeal),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _logoBlue)),
        ),
        validator: (val) => val == null || val.trim().isEmpty ? 'حقل مطلوب' : null,
      ),
    );
  }
}