import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مركز المساعدة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E70B8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'مرحبًا بك في مركز المساعدة',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'هنا يمكنك العثور على إجابات للأسئلة الشائعة، التواصل مع الدعم الفني، '
                'أو الاطلاع على الإرشادات الخاصة باستخدام التطبيق.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.question_answer, color: Colors.blue),
            title: const Text('الأسئلة الشائعة', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {
              // TODO: Navigate to FAQ screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.green),
            title: const Text('تواصل مع الدعم الفني', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {
              // TODO: Open support chat or WhatsApp
            },
          ),
          ListTile(
            leading: const Icon(Icons.book, color: Colors.orange),
            title: const Text('دليل الاستخدام', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {
              // TODO: Navigate to user guide
            },
          ),
        ],
      ),
    );
  }
}
