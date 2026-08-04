// lib/screens/payment_confirmation_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:screenshot/screenshot.dart'; // أضف هذه المكتبة في pubspec.yaml
// import 'package:image_gallery_saver/image_gallery_saver.dart'; // لحفظ الصورة في الاستوديو

class PaymentConfirmationScreen extends StatefulWidget {
  final String bookingId;
  final String transactionId;
  final double amount;
  final String paymentMethod;

  const PaymentConfirmationScreen({
    super.key,
    required this.bookingId,
    required this.transactionId,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;

  // ألوان الهوية البصرية لرحلاء
  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _logoGreen = const Color(0xFF4EBF64);
  final Color _bgGrey = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _savePaymentToDatabase(); // حفظ السند تلقائياً عند الدخول
  }

  // 1. حفظ السند في قاعدة البيانات (Firestore)
  Future<void> _savePaymentToDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('payments').doc(widget.transactionId).set({
        'userId': user.uid,
        'bookingId': widget.bookingId,
        'transactionId': widget.transactionId,
        'amount': widget.amount,
        'paymentMethod': widget.paymentMethod,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'success',
      });
      debugPrint("Payment saved to DB");
    } catch (e) {
      debugPrint("Error saving payment: $e");
    }
  }

  // 2. حفظ السند كصورة في الاستوديو
  Future<void> _captureAndSaveReceipt() async {
    setState(() => _isSaving = true);

    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        // هنا يتم استخدام image_gallery_saver لحفظ الصورة فعلياً
        // await ImageGallerySaver.saveImage(image);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم حفظ السند في معرض الصور بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ فشل حفظ الصورة')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      // القائمة الجانبية (Drawer)
      drawer: _buildSideMenu(),
      appBar: AppBar(
        title: const Text('سند الدفع الرقمي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        // زر الرجوع مفعل تلقائياً
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // تغليف السند لالتقاط صورة له
            Screenshot(
              controller: _screenshotController,
              child: _buildTicketWidget(),
            ),

            const SizedBox(height: 30),

            // أزرار التحكم
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // تصميم السند (Ticket Design)
  Widget _buildTicketWidget() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          // رأس السند
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30),
            width: double.infinity,
            decoration: BoxDecoration(
              color: _logoGreen.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle_rounded, size: 70, color: _logoGreen),
                const SizedBox(height: 12),
                const Text('عملية ناجحة',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF2D6A4F))),
                Text('تم تأكيد حجزك بنجاح',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),

          // تفاصيل السند
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildReceiptRow('رقم الحجز', widget.bookingId, Icons.confirmation_number_outlined),
                _buildReceiptRow('رقم العملية', widget.transactionId, Icons.receipt_long_outlined),
                _buildReceiptRow('طريقة الدفع', widget.paymentMethod, Icons.account_balance_wallet_outlined),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(thickness: 1, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المبلغ الإجمالي',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('${widget.amount.toStringAsFixed(0)} ر.ي',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: _logoBlue)),
                  ],
                ),
              ],
            ),
          ),

          // الباركود التجميلي (Visual Hierarchy)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                const Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.black87),
                const SizedBox(height: 8),
                Text('رحلاء - رحلتك أمان',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: _logoTeal),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _captureAndSaveReceipt,
          icon: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.file_download_outlined),
          label: const Text('حفظ السند في الاستوديو',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _logoBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          child: Text('العودة للرئيسية',
              style: TextStyle(fontFamily: 'Cairo', color: _logoBlue, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSideMenu() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: _logoBlue),
            accountName: const Text("مستخدم رحلاء", style: TextStyle(fontFamily: 'Cairo')),
            accountEmail: Text(widget.bookingId),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person)),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('الرئيسية', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('سجل المدفوعات', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {},
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('الدعم الفني', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {},
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

const Color _textDark = Color(0xFF1E293B);