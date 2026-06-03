// lib/screens/create_trip_screen.dart
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
      } catch (_) {
        userService = null;
      }

      if (userService != null) {
        final appUser = await userService.getUserById(user.uid);
        if (appUser != null) {
          _driverCarPlateNumber = appUser.carPlateNumber;
          _driverCarOwnerOfficialName = appUser.carOwnerOfficialName;
          setState(() => _isLoadingUserData = false);
          if (_driverCarPlateNumber == null || _driverCarOwnerOfficialName == null) {
            _showSnackBar('⚠️ يرجى استكمال بيانات المركبة في ملفك الشخصي (سيُطلب منك إكمالها قبل الإنشاء)');
          }
          return;
        }
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() as Map<String, dynamic>?;

      if (data != null) {
        final plateCandidates = <String>[
          'carPlateNumber',
          'car_plate_number',
          'plateNumber',
          'plate_number',
          'carPlate',
          'plate'
        ];
        final ownerCandidates = <String>[
          'carOwnerOfficialName',
          'car_owner_official_name',
          'vehicleOwner',
          'vehicle_owner',
          'carOwner'
        ];

        String? plate;
        String? owner;

        for (final k in plateCandidates) {
          final v = data[k];
          if (v is String && v.trim().isNotEmpty) {
            plate = v.trim();
            break;
          }
        }

        for (final k in ownerCandidates) {
          final v = data[k];
          if (v is String && v.trim().isNotEmpty) {
            owner = v.trim();
            break;
          }
        }

        setState(() {
          _driverCarPlateNumber = plate;
          _driverCarOwnerOfficialName = owner;
        });

        if (_driverCarPlateNumber == null || _driverCarOwnerOfficialName == null) {
          _showSnackBar('⚠️ يرجى استكمال بيانات المركبة في ملفك الشخصي (سيُطلب منك إكمالها قبل الإنشاء)');
        }
      }
    } catch (e) {
      _showSnackBar('❌ فشل في جلب بيانات السائق: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      _showSnackBar('❌ يرجى إدخال سعر صالح');
      return false;
    }

    return true;
  }

  Future<bool> _ensureProfileCompleteForDriver() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('❌ يجب تسجيل الدخول أولاً');
      return false;
    }

    UserService? userService;
    try {
      userService = Provider.of<UserService>(context, listen: false);
    } catch (_) {
      userService = null;
    }

    String? userType;
    String? plate;
    String? owner;
    String? drivingLicense;
    String? idNumber;

    if (userService != null) {
      final appUser = await userService.getUserById(user.uid);
      if (appUser != null) {
        userType = appUser.userType;
        plate = appUser.carPlateNumber;
        owner = appUser.carOwnerOfficialName;
        drivingLicense = appUser.drivingLicenseNumber;
        idNumber = appUser.idNumber;
      }
    } else {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() as Map<String, dynamic>?;
      userType = (data?['userType'] ?? data?['user_type'])?.toString();
      plate = (data?['carPlateNumber'] ?? data?['car_plate_number'] ?? data?['plateNumber']) as String?;
      owner = (data?['carOwnerOfficialName'] ?? data?['car_owner_official_name'] ?? data?['vehicleOwner']) as String?;
      drivingLicense = (data?['drivingLicenseNumber'] ?? data?['driving_license_number']) as String?;
      idNumber = (data?['idNumber'] ?? data?['fullNameId']) as String?;
    }

    final typeLower = (userType ?? '').toLowerCase();

    if (typeLower != 'driver' && typeLower != 'سائق') {
      _showSnackBar('❌ فقط السائقين يمكنهم إنشاء رحلات');
      return false;
    }

    if (idNumber == null || idNumber.trim().isEmpty) {
      _showSnackBar('❌ يجب إدخال رقم البطاقة/الجواز في الملف الشخصي');
      return false;
    }

    if (plate == null || plate.trim().isEmpty || owner == null || owner.trim().isEmpty) {
      final goToProfile = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('اكمل بيانات المركبة'),
            content: const Text('يجب إكمال بيانات المركبة في الملف الشخصي قبل إنشاء الرحلة. هل تريد الانتقال لتعديل الملف الآن؟'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('لاحقاً')),
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('تعديل الملف')),
            ],
          );
        },
      );

      if (goToProfile == true) {
        if (!mounted) return false;
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
        await _fetchDriverData();
        return await _ensureProfileCompleteForDriver();
      }

      return false;
    }

    if (_tripCategory == 'خارجية' && (drivingLicense == null || drivingLicense.trim().isEmpty)) {
      _showSnackBar('❌ لا يمكن إنشاء رحلة خارجية بدون رخصة القيادة في الملف الشخصي');
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
      if (user == null) {
        _showSnackBar('❌ يجب تسجيل الدخول أولاً');
        setState(() => _isSubmitting = false);
        return;
      }

      final price = double.tryParse(_priceController.text.trim()) ?? 0;

      double driverRating = 0.0;
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        final ratingVal = userData?['averageRating'] ?? userData?['average_rating'];
        if (ratingVal is num) driverRating = ratingVal.toDouble();
      } catch (_) {}

      final plate = _driverCarPlateNumber ?? 'غير متوفر';
      final owner = _driverCarOwnerOfficialName ?? 'غير متوفر';

      final Map<String, dynamic> tripMap = {
        'title': _selectedTitle,
        'description': _descriptionController.text.trim(),
        'driverId': user.uid,
        'driverName': user.displayName ?? user.email ?? 'سائق',
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
        'driverRating': driverRating,
        'carPlateNumber': plate,
        'carOwnerOfficialName': owner,
        'createdAt': FieldValue.serverTimestamp(),
      };

      try {
        TripService? tripService;
        try {
          tripService = Provider.of<TripService>(context, listen: false);
        } catch (_) {
          tripService = null;
        }

        if (tripService != null) {
          final trip = Trip(
            title: _selectedTitle,
            description: _descriptionController.text.trim(),
            driverId: user.uid,
            driverName: user.displayName ?? user.email ?? 'سائق',
            tripCategory: _tripCategory,
            origin: _selectedOrigin,
            destination: _selectedDestination,
            vehicleType: _carType,
            vehicleId: null,
            totalSeats: _totalSeats,
            availableSeats: _totalSeats,
            seatStatus: List<bool>.filled(_totalSeats, true),
            departureTime: _selectedDate,
            date: _selectedDate,
            time: _selectedTime,
            flexibleWindow: _flexibleWindowController.text.trim(),
            status: 'active',
            price: price,
            driverRating: driverRating,
            carPlateNumber: plate,
            carOwnerOfficialName: owner,
            createdAt: null,
          );

          final createdId = await tripService.createTrip(trip);
          if (createdId == null) {
            final docRef = await FirebaseFirestore.instance.collection('trips').add(tripMap);
            debugPrint('CreateTripScreen: fallback wrote trip id=${docRef.id}');
          } else {
            debugPrint('CreateTripScreen: trip created via TripService id=$createdId');
          }
        } else {
          final docRef = await FirebaseFirestore.instance.collection('trips').add(tripMap);
          debugPrint('CreateTripScreen: wrote trip id=${docRef.id}');
        }
      } catch (e, st) {
        debugPrint('CreateTripScreen: create trip error, fallback to direct write: $e\n$st');
        await FirebaseFirestore.instance.collection('trips').add(tripMap);
      }

      _showSnackBar('✅ تم إنشاء الرحلة بنجاح');
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('CreateTripScreen._submitTrip error: $e\n$st');
      _showSnackBar('❌ فشل في حفظ الرحلة: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        title: Text(
          'تاريخ الرحلة: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
          style: const TextStyle(fontSize: 16),
        ),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            locale: const Locale('ar'),
          );
          if (picked != null) setState(() => _selectedDate = picked);
        },
      ),
    );
  }

  Widget _buildSeatSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<int>(
        initialValue: _totalSeats,
        items: List.generate(10, (i) => i + 1).map((n) => DropdownMenuItem(value: n, child: Text('$n مقاعد'))).toList(),
        onChanged: (val) {
          if (val != null) setState(() => _totalSeats = val);
        },
        decoration: InputDecoration(
          labelText: 'عدد المقاعد',
          prefixIcon: const Icon(Icons.event_seat),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>(String label, T currentValue, List<T> items, void Function(T) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<T>(
        initialValue: currentValue,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item.toString()))).toList(),
        onChanged: (val) {
          if (val != null) onChanged(val as T);
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.arrow_drop_down),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text, bool validatorOptional = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.edit),
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: (val) {
          if (validatorOptional) return null;
          return val == null || val.isEmpty ? 'يرجى إدخال $label' : null;
        },
      ),
    );
  }

  Widget _buildStaticInfo(String label, String? value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.badge, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  const SizedBox(height: 4),
                  Text(
                    value ?? 'غير متوفر - يرجى التحديث في الملف الشخصي',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: value != null ? theme.colorScheme.onSurface : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء رحلة جديدة'),
        backgroundColor: theme.colorScheme.primary,
        centerTitle: true,
      ),
      body: _isLoadingUserData
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
                      children: [
                        _buildDropdown('عنوان الرحلة', _selectedTitle, titles, (val) => setState(() => _selectedTitle = val)),
                        _buildDropdown('نقطة الانطلاق', _selectedOrigin, origins, (val) => setState(() => _selectedOrigin = val)),
                        _buildDropdown('الوجهة', _selectedDestination, origins, (val) => setState(() => _selectedDestination = val)),
                        _buildTextField(_descriptionController, 'وصف الرحلة', validatorOptional: true),
                        _buildDropdown('العملة', _selectedCurrency, currencies, (val) => setState(() => _selectedCurrency = val)),
                        _buildTextField(_priceController, 'السعر', keyboardType: TextInputType.number),
                        _buildDropdown('وقت الرحلة', _selectedTime, times, (val) => setState(() => _selectedTime = val)),
                        _buildTextField(_flexibleWindowController, 'نافذة مرنة', validatorOptional: true),
                        _buildDropdown('نوع السيارة وطرازها', _carType, carTypes, (val) => setState(() => _carType = val)),
                        _buildDropdown('فئة الرحلة', _tripCategory, tripCategories, (val) {
                          setState(() {
                            _tripCategory = val;
                          });
                        }),
                        _buildStaticInfo('رقم لوحة السيارة', _driverCarPlateNumber),
                        _buildStaticInfo('اسم مالك المركبة/المعرض', _driverCarOwnerOfficialName),
                        const SizedBox(height: 10),
                        _buildSeatSelector(),
                        _buildDatePicker(),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitTrip,
                          icon: _isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle),
                          label: Text(_isSubmitting ? 'جاري الإنشاء...' : 'إنشاء الرحلة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            minimumSize: const Size(double.infinity, 50),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
