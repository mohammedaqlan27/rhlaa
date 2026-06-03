import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

/// نموذج صفحة اختبارية 1
class PageA extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page A')),
      body: const Center(child: Text('Page A works')),
    );
  }
}

/// نموذج صفحة اختبارية 2 (تسبب استثناء أثناء البناء)
class PageB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    throw Exception('Build error in Page B');
  }
}

/// نموذج صفحة اختبارية 3 (تأخير طويل)
class PageC extends StatefulWidget {
  @override
  _PageCState createState() => _PageCState();
}
class _PageCState extends State<PageC> {
  @override
  void initState() {
    super.initState();
    // محاكاة عملية طويلة أو خطأ غير متزامن
    Future.delayed(const Duration(seconds: 5), () {
      // لا نفعل شيئًا؛ هذا يسبب تأخيرًا فقط
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page C')),
      body: const Center(child: Text('Page C loaded (may be slow)')),
    );
  }
}

/// هيكل بيانات صفحة للاختبار
class PageInfo {
  final String name;
  final WidgetBuilder builder;
  PageInfo({required this.name, required this.builder});
}

class MyApp extends StatelessWidget {
  final List<PageInfo> pages = [
    PageInfo(name: 'PageA', builder: (_) => PageA()),
    PageInfo(name: 'PageB', builder: (_) => PageB()),
    PageInfo(name: 'PageC', builder: (_) => PageC()),
    // أضف هنا صفحاتك الحقيقية: PageInfo(name: 'Home', builder: (_) => HomePage()),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pages Tester',
      home: TestRunner(pages: pages),
    );
  }
}

class TestRunner extends StatefulWidget {
  final List<PageInfo> pages;
  const TestRunner({required this.pages});

  @override
  _TestRunnerState createState() => _TestRunnerState();
}

class _TestRunnerState extends State<TestRunner> {
  final Map<String, String> _results = {};
  bool _running = false;
  static const Duration pageTimeout = Duration(seconds: 3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pages Tester')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _running ? null : _runAllTests,
              child: Text(_running ? 'Running...' : 'Run tests for all pages'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: widget.pages.map((p) {
                  final status = _results[p.name] ?? 'Not tested';
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text(status),
                    trailing: ElevatedButton(
                      onPressed: _running ? null : () => _runSingleTest(p),
                      child: const Text('Test'),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      _running = true;
      _results.clear();
    });
    for (final p in widget.pages) {
      await _runSingleTest(p);
      // فاصل صغير بين الاختبارات
      await Future.delayed(const Duration(milliseconds: 300));
    }
    setState(() => _running = false);
  }

  Future<void> _runSingleTest(PageInfo page) async {
    setState(() {
      _results[page.name] = 'Testing...';
    });

    // حفظ المعالج القديم للأخطاء لاستعادته لاحقًا
    final oldOnError = FlutterError.onError;
    final completer = Completer<void>();
    String? errorMessage;

    // مؤقت لالتقاط الأخطاء المتزامنة وغير المتزامنة
    FlutterError.onError = (FlutterErrorDetails details) {
      errorMessage = details.exceptionAsString();
      if (!completer.isCompleted) completer.complete();
    };

    // أيضًا نلتقط الأخطاء غير المتزامنة في المنطقة (zone)
    final zone = Zone.current;
    late ZoneSpecification zoneSpec;
    zoneSpec = ZoneSpecification(
      handleUncaughtError: (Zone self, ZoneDelegate parent, Zone zone, Object error, StackTrace stack) {
        errorMessage = error.toString();
        if (!completer.isCompleted) completer.complete();
      },
    );

    // نفتح الصفحة داخل منطقة جديدة حتى نلتقط الأخطاء غير المتزامنة
    await Zone.current.fork(specification: zoneSpec).run(() async {
      // نضغط على الصفحة (ننتقل إليها) ثم ننتظر إما خطأ أو مهلة
      try {
        // نستخدم push ثم ننتظر لعدد من الثواني لمعرفة إن ظهرت أخطاء
        Navigator.of(context).push(MaterialPageRoute(builder: page.builder));
      } catch (e) {
        errorMessage = e.toString();
        if (!completer.isCompleted) completer.complete();
      }

      // ننتظر إما إشارة خطأ أو انتهاء المهلة
      try {
        await Future.any([
          completer.future,
          Future.delayed(pageTimeout),
        ]);
      } catch (_) {}

      // بعد الانتظار: إذا لم يحدث خطأ نعتبر الصفحة ناجحة
      if (!completer.isCompleted) completer.complete();
    });

    // نحاول إغلاق الصفحة المفتوحة إن كانت لا تزال موجودة
    try {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (_) {}

    // استعادة معالج الأخطاء القديم
    FlutterError.onError = oldOnError;

    // تقرير النتيجة
    if (errorMessage != null) {
      setState(() {
        _results[page.name] = 'Error: $errorMessage';
      });
    } else {
      setState(() {
        _results[page.name] = 'Success';
      });
    }
  }
}
