// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/shared/custom_button.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'مرحباً بك في رحلة',
      'desc': 'منصتك الموثوقة للسفر بين المدن بكل سهولة وأمان.',
      'icon': '🚀'
    },
    {
      'title': 'حجز عائلي أو فردي',
      'desc': 'يمكنك اختيار نوع الحجز المناسب لك أثناء اختيار رحلتك.',
      'icon': '👨‍👩‍👧‍👦'
    },
    {
      'title': 'كن شريكاً معنا',
      'desc': 'سجل كسائق وابدأ بجني الأرباح، سواء كنت مستقلاً أو تابعاً لمكتب.',
      'icon': '🚗'
    },
  ];

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_time', false);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: _pages.length,
              itemBuilder: (context, index) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_pages[index]['icon']!, style: const TextStyle(fontSize: 100)),
                  const SizedBox(height: 30),
                  Text(_pages[index]['title']!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(_pages[index]['desc']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: CustomButton(
              text: _currentPage == _pages.length - 1 ? 'ابدأ الآن' : 'التالي',
              onPressed: () {
                if (_currentPage == _pages.length - 1) {
                  _finishOnboarding();
                } else {
                  _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}