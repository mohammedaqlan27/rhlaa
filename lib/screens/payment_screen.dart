// lib/screens/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/payment_service.dart';
import 'payment_confirmation_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String? tripId;
  final int? seatNumber;
  final String? bookingId;
  final String? amount;

  const PaymentScreen({
    super.key,
    this.tripId,
    this.seatNumber,
    this.bookingId,
    this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'نقداً عند اللقاء';
  bool _isProcessing = false;
  String? _errorMessage;
  double _amount = 0.0;

  String? _currentTripId;
  int? _currentSeatNumber;
  String? _currentBookingId;

  final PaymentService _paymentService = PaymentService();

  // ألوان هوية رحلاء البصرية
  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _logoGreen = const Color(0xFF4EBF64);
  final Color _backgroundColor = const Color(0xFFF8FAFC);

  // قائمة طرق الدفع الموسعة والشاملة لليمن
  final List<Map<String, dynamic>> _methods = [
    {'title': 'نقداً عند اللقاء', 'subtitle': 'الدفع المباشر للكابتن فور الركوب', 'icon': Icons.money_rounded, 'color': Colors.green},
    {'title': 'كريمي جوال (Kuraimi)', 'subtitle': 'عبر رقم الحساب أو كود QR', 'icon': Icons.account_balance_rounded, 'color': Color(0xFF1E70B8)},
    {'title': 'محفظة جوالي (M-Jwali)', 'subtitle': 'خدمة مصرف البحرين الشامل', 'icon': Icons.smartphone_rounded, 'color': Colors.orange},
    {'title': 'محفظة فلوسك (Filousak)', 'subtitle': 'خدمة مصرف اليمن والبحرين', 'icon': Icons.wallet_rounded, 'color': Colors.blue},
    {'title': 'محفظة بيس (PYS)', 'subtitle': 'خدمة بنك الأمل للتمويل', 'icon': Icons.account_balance_wallet_rounded, 'color': Colors.teal},
    {'title': 'محفظة كاش (CASH)', 'subtitle': 'خدمة بنك سبأ الإسلامي', 'icon': Icons.payments_rounded, 'color': Colors.redAccent},
    {'title': 'محفظة ون نقد (One Cash)', 'subtitle': 'خدمة كاش السريعة', 'icon': Icons.flash_on_rounded, 'color': Colors.purple},
    {'title': 'محفظة إم فلوس (M-Floos)', 'subtitle': 'خدمة بنك التضامن الإسلامي', 'icon': Icons.currency_exchange_rounded, 'color': Colors.indigo},
    {'title': 'بطاقة إلكترونية (قريباً)', 'subtitle': 'الدفع عبر الفيزا أو الماستر كارد', 'icon': Icons.credit_card_rounded, 'color': Colors.grey, 'disabled': true},
  ];

  @override
  void initState() {
    super.initState();
    // استعادة تهيئة المتغيرات الأصلية
    _currentTripId = widget.tripId;
    _currentSeatNumber = widget.seatNumber;
    _currentBookingId = widget.bookingId;

    if (widget.amount != null) {
      _amount = double.tryParse(widget.amount!) ?? 0.0;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractArguments(); // استعادة منطق الـ Arguments
      _loadBookingAmountIfNeeded(); // استعادة منطق جلب المبلغ من الداتابيز
    });
  }

  // استعادة وظيفة استخراج البيانات من Arguments
  void _extractArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() {
        _currentTripId ??= args['tripId'];
        _currentSeatNumber ??= args['seatNumber'];
        _currentBookingId ??= args['bookingId'];
        if (args['amount'] != null) {
          _amount = double.tryParse(args['amount'].toString()) ?? _amount;
        }
      });
    }
  }

  // استعادة وظيفة جلب مبلغ الحجز من Firestore
  Future<void> _loadBookingAmountIfNeeded() async {
    try {
      final bId = _currentBookingId;
      if (bId != null && bId.isNotEmpty) {
        final snap = await FirebaseFirestore.instance.collection('bookings').doc(bId).get();
        if (snap.exists) {
          final data = snap.data() ?? {};
          final tp = data['totalPrice'] ?? data['amountPaid'] ?? data['price'];
          if (tp is num) {
            setState(() => _amount = tp.toDouble());
          } else if (tp is String) {
            setState(() => _amount = double.tryParse(tp) ?? 0.0);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading amount: $e');
    }
  }

  String _formatCurrency(double value) {
    return '${value.toStringAsFixed(0)} ر.ي';
  }

  void _showPaymentMethodsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text('💳 اختر وسيلة الدفع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: _methods.length,
                  itemBuilder: (context, index) {
                    final method = _methods[index];
                    final bool isDisabled = method['disabled'] == true;
                    final bool isSelected = _selectedMethod == method['title'];

                    return ListTile(
                      enabled: !isDisabled,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (method['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(method['icon'] as IconData, color: isDisabled ? Colors.grey : method['color'] as Color),
                      ),
                      title: Text(method['title'] as String,
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isDisabled ? Colors.grey : Colors.black87)),
                      subtitle: Text(method['subtitle'] as String, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                      trailing: isSelected ? Icon(Icons.check_circle, color: _logoGreen) : null,
                      onTap: () {
                        setState(() => _selectedMethod = method['title'] as String);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // استعادة منطق تأكيد الدفع الأصلي بالكامل
  Future<void> _confirmPayment() async {
    if (_currentTripId == null) {
      setState(() => _errorMessage = "خطأ: معرف الرحلة مفقود");
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      String? bId = _currentBookingId;
      bId ??= await _findLatestBookingId(user.uid, _currentTripId!);

      if (bId != null) {
        final PaymentResult result = await _paymentService.processPayment(
          bookingId: bId,
          amount: _amount,
          paymentMethod: _selectedMethod,
        );

        if (result.success && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PaymentConfirmationScreen(
                bookingId: bId!,
                transactionId: result.transactionId ?? 'TRX-${DateTime.now().millisecondsSinceEpoch}',
                amount: _amount,
                paymentMethod: _selectedMethod,
              ),
            ),
          );
        } else {
          setState(() => _errorMessage = result.message);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'حدث خطأ غير متوقع');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<String?> _findLatestBookingId(String uid, String tripId) async {
    final q = await FirebaseFirestore.instance
        .collection('bookings')
        .where('tripId', isEqualTo: tripId)
        .where('passengerId', isEqualTo: uid)
        .limit(1)
        .get();
    return q.docs.isNotEmpty ? q.docs.first.id : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('تأكيد الحجز والدفع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 20),
                  const Text('وسيلة الدفع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  _buildPaymentSelector(),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 15),
                    Text(_errorMessage!, style: const TextStyle(fontFamily: 'Cairo', color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: _logoBlue),
              const SizedBox(width: 10),
              const Text('ملخص الحجز', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 30),
          _buildSummaryRow('رقم الرحلة', _currentTripId ?? '---'),
          _buildSummaryRow('رقم المقعد', 'مقعد رقم ${_currentSeatNumber ?? "0"}'),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المبلغ الإجمالي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              Text(_formatCurrency(_amount), style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.bold, color: _logoGreen)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPaymentSelector() {
    return InkWell(
      onTap: _showPaymentMethodsBottomSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _logoBlue.withOpacity(0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: _logoBlue),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('طريقة الدفع المختارة', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
                  Text(_selectedMethod, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: _isProcessing ? null : _confirmPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: _logoBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isProcessing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('تأكيد الحجز وإصدار السند', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء والعودة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}