import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'سياسة الخصوصية',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E70B8),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text(
              'سياسة الخصوصية',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'نحن نلتزم بحماية بياناتك الشخصية وضمان استخدامها بشكل آمن. '
                  'يتم جمع المعلومات فقط لتحسين تجربة المستخدم وتقديم الخدمات بشكل أفضل.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            SizedBox(height: 20),
            Text(
              '• لا نقوم بمشاركة بياناتك مع أطراف ثالثة بدون موافقتك.\n'
                  '• يتم استخدام بياناتك فقط للأغراض المتعلقة بالخدمات.\n'
                  '• يمكنك طلب حذف بياناتك في أي وقت.\n'
                  '• يتم تخزين البيانات بشكل آمن ومشفّر.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            SizedBox(height: 20),
            Text(
              'لمزيد من التفاصيل، يمكنك التواصل مع فريق الدعم الفني أو مراجعة '
                  'الشروط والأحكام الخاصة بالتطبيق.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ],
        ),
      ),
    );
  }
}
