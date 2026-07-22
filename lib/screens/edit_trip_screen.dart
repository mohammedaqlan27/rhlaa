import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';

class EditTripScreen extends StatefulWidget {
  final String tripId;

  // تأكد أن السطر التالي لا يحتوي على "required Trip trip"
  const EditTripScreen({super.key, required this.tripId});

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}
class _EditTripScreenState extends State<EditTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late Trip _trip;
  bool _isLoading = true;
  bool _isSaving = false;

  // المتحكمات بالنصوص
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _priceController = TextEditingController();
  final _flexibleWindowController = TextEditingController();

  // ألوان الهوية البصرية (تطبيق رحلاء)
  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _logoGreen = const Color(0xFF4EBF64);
  final Color _backgroundColor = const Color(0xFFF8FAFC);

  // خيارات القوائم المنسدلة
  final List<String> carTypes = ['سيارة سيدان', 'سيارة دفع رباعي', 'سيارة فان'];
  final List<String> tripCategories = ['داخلية', 'خارجية'];

  String _carType = 'سيارة سيدان';
  String _tripCategory = 'داخلية';
  int _totalSeats = 4;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _priceController.dispose();
    _flexibleWindowController.dispose();
    super.dispose();
  }

  /// جلب بيانات الرحلة من قاعدة البيانات
  Future<void> _loadTrip() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ الرحلة المطلوبة غير موجودة')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // تحويل البيانات من Firestore إلى كائن Trip
      _trip = Trip.fromDocument(doc);

      // تعبئة الحقول بالبيانات الحالية
      _titleController.text = _trip.title;
      _descriptionController.text = _trip.description;
      _originController.text = _trip.origin;
      _destinationController.text = _trip.destination;
      _priceController.text = _trip.price.toString();
      _flexibleWindowController.text = _trip.flexibleWindow;
      _carType = _trip.vehicleType.isNotEmpty ? _trip.vehicleType : carTypes.first;
      _tripCategory = _trip.tripCategory.isNotEmpty ? _trip.tripCategory : tripCategories.first;
      _totalSeats = _trip.totalSeats;

      if (_trip.departureTime != null) {
        final dt = _trip.departureTime!;
        _selectedDate = DateTime(dt.year, dt.month, dt.day);
        _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading trip: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  /// حفظ التعديلات وإرسالها إلى Firestore
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // دمج التاريخ والوقت المختارين
      final departureDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // إنشاء نسخة محدثة من الرحلة باستخدام copyWith
      final updatedTrip = _trip.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        origin: _originController.text.trim(),
        destination: _destinationController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? _trip.price,
        flexibleWindow: _flexibleWindowController.text.trim(),
        vehicleType: _carType,
        tripCategory: _tripCategory,
        totalSeats: _totalSeats,
        departureTime: departureDateTime,
        updatedAt: Timestamp.now(), // التعديل هنا: استخدم Timestamp بدلاً من DateTime
      );

      // تحديث الوثيقة في Firestore
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .update(updatedTrip.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ تعديلات رحلتك بنجاح',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        );
        Navigator.pop(context, true); // العودة مع إشارة للنجاح
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ فشل الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: _logoBlue)),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('تعديل بيانات الرحلة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoTeal,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // قسم المعلومات الأساسية
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildTextField(_titleController, 'عنوان الرحلة', icon: Icons.title_rounded),
                        _buildTextField(_descriptionController, 'تفاصيل إضافية للركاب',
                            icon: Icons.chat_bubble_outline_rounded, maxLines: 2),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_originController, 'الانطلاق', icon: Icons.trip_origin)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField(_destinationController, 'الوجهة', icon: Icons.flag_circle)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // قسم السعر ونوع المركبة
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildTextField(_priceController, 'السعر الجديد',
                            icon: Icons.payments_outlined, keyboardType: TextInputType.number),
                        _buildDropdown('نوع المركبة', _carType, carTypes,
                                (val) => setState(() => _carType = val)),
                        _buildDropdown('فئة النطاق الجغرافي', _tripCategory, tripCategories,
                                (val) => setState(() => _tripCategory = val)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // قسم الوقت والتاريخ
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text('📅 تاريخ الحركة: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                        trailing: Icon(Icons.calendar_month, color: _logoBlue),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _selectedDate = picked);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: Text('⏰ وقت الانطلاق: ${_selectedTime.format(context)}',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                        trailing: Icon(Icons.access_time_filled_rounded, color: _logoTeal),
                        onTap: () async {
                          final timePicked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (timePicked != null) setState(() => _selectedTime = timePicked);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // زر الحفظ
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveChanges,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_as_rounded, color: Colors.white),
                  label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ ونشر التعديلات',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
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

  // أداة بناء حقول النص
  Widget _buildTextField(TextEditingController controller, String label,
      {IconData icon = Icons.edit, TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey[600]),
          prefixIcon: Icon(icon, size: 20, color: _logoTeal),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _logoBlue)),
        ),
        validator: (val) {
          if (val == null || val.trim().isEmpty) return 'هذا الحقل مطلوب';
          return null;
        },
      ),
    );
  }

  // أداة بناء القوائم المنسدلة
  Widget _buildDropdown(String label, String value, List<String> items, void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))
        )).toList(),
        onChanged: (val) { if (val != null) onChanged(val); },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey[600]),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _logoBlue)),
        ),
      ),
    );
  }
}