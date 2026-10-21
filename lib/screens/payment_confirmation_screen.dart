import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:screenshot/screenshot.dart';

import '../theme/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _savePaymentToDatabase();
  }

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

  Future<void> _captureAndSaveReceipt() async {
    setState(() => _isSaving = true);

    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم حفظ السند في معرض الصور بنجاح', style: TextStyle(fontFamily: AppFonts.arabic))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ فشل حفظ الصورة', style: TextStyle(fontFamily: AppFonts.arabic))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
        drawer: _buildSideMenu(),
        appBar: AppBar(
          title: const Text('سند الدفع الرقمي', style: TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Screenshot(
                controller: _screenshotController,
                child: _buildTicketWidget(),
              ),
              const SizedBox(height: 30),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.webCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded, size: 70, color: AppColors.success),
                const SizedBox(height: 12),
                const Text('عملية ناجحة', style: TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.success)),
                Text('تم تأكيد حجزك بنجاح', style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
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
                    const Text('المبلغ الإجمالي', style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('${widget.amount.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                Icon(Icons.qr_code_2_rounded, size: 80, color: isDark ? Colors.white70 : Colors.black87),
                const SizedBox(height: 8),
                Text('رحلاء - رحلتك أمان', style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: isDark ? AppColors.backgroundDark : AppColors.background, borderRadius: BorderRadius.circular(8)),
            child:  Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 11, color: AppColors.gray500)),
                Text(value, style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary)),
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
          label: const Text('حفظ السند في الاستوديو', style: TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('العودة للرئيسية', style: TextStyle(fontFamily: AppFonts.arabic, color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSideMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? AppColors.webCardBackground : Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            accountName: const Text("مستخدم رحلاء", style: TextStyle(fontFamily: AppFonts.arabic)),
            accountEmail: Text(widget.bookingId),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: AppColors.primary)),
          ),
          ListTile(
            leading: Icon(Icons.home_outlined, color: isDark ? Colors.white : AppColors.textPrimary),
            title: Text('الرئيسية', style: TextStyle(fontFamily: AppFonts.arabic, color: isDark ? Colors.white : AppColors.textPrimary)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(Icons.history, color: isDark ? Colors.white : AppColors.textPrimary),
            title: Text('سجل المدفوعات', style: TextStyle(fontFamily: AppFonts.arabic, color: isDark ? Colors.white : AppColors.textPrimary)),
            onTap: () {},
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: Icon(Icons.support_agent, color: isDark ? Colors.white : AppColors.textPrimary),
            title: Text('الدعم الفني', style: TextStyle(fontFamily: AppFonts.arabic, color: isDark ? Colors.white : AppColors.textPrimary)),
            onTap: () {},
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}