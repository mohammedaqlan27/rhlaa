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

  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const String _fontCairo = 'Cairo';

  final List<Map<String, String>> _pages = const [
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_time', false);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // 1. شريط العلوي لمحي زر التخطي (Skip)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _currentPage < _pages.length - 1
                      ? TextButton(
                    onPressed: _finishOnboarding,
                    child: const Text(
                      'تخطي',
                      style: TextStyle(
                        fontFamily: _fontCairo,
                        color: Colors.grey,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                      : const SizedBox(height: 48), // الحفاظ على ارتفاع العنصر
                ),
              ),

              // 2. محتوى الشرائح التفاعلي
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _pages[index]['icon']!,
                          style: const TextStyle(fontSize: 100),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _pages[index]['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: _fontCairo,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _pages[index]['desc']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: _fontCairo,
                            color: Colors.grey.shade600,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. مؤشرات الصفحة (Dots Indicator)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                      (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentPage == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? _primaryBlue : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 4. زر التنقل السفلي
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: CustomButton(
                  text: _currentPage == _pages.length - 1 ? 'ابدأ الآن' : 'التالي',
                  onPressed: () {
                    if (_currentPage == _pages.length - 1) {
                      _finishOnboarding();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}