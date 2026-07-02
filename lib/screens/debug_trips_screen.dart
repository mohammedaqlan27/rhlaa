// lib/screens/debug_trips_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DebugTripsScreen extends StatefulWidget {
  const DebugTripsScreen({super.key});

  @override
  State<DebugTripsScreen> createState() => _DebugTripsScreenState();
}

class _DebugTripsScreenState extends State<DebugTripsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _lastAction = 'لم يتم التشغيل بعد';
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String _error = '';

  Future<void> _runQueryAll() async {
    setState(() { _loading = true; _error = ''; _lastAction = 'جلب كل المستندات (collection.get)'; _results = []; });
    try {
      final snap = await _firestore.collection('trips').get();
      final docs = snap.docs.map((d) => {'id': d.id, 'data': d.data()}).toList();
      debugPrint('DebugTrips: all count=${docs.length}');
      setState(() { _results = docs; });
    } catch (e, st) {
      debugPrint('DebugTrips _runQueryAll error: $e\n$st');
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _runQueryStatusVariants() async {
    setState(() { _loading = true; _error = ''; _lastAction = 'جلب حسب status (whereIn)'; _results = []; });
    try {
      // جرّب القيم المحتملة هنا
      final variants = ['active', 'Active', 'نشطة', 'مفعّلة', 'مفعلة'];
      // Firestore whereIn يدعم حتى 10 عناصر
      final snap = await _firestore.collection('trips').where('status', whereIn: variants).get();
      final docs = snap.docs.map((d) => {'id': d.id, 'status': d.data()['status'], 'data': d.data()}).toList();
      debugPrint('DebugTrips: statusVariants count=${docs.length}');
      setState(() { _results = docs; });
    } catch (e, st) {
      debugPrint('DebugTrips _runQueryStatusVariants error: $e\n$st');
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _runQuerySeatsFilter() async {
    setState(() { _loading = true; _error = ''; _lastAction = 'جلب مع فلتر availableSeats > 0 (client-side fallback)'; _results = []; });
    try {
      // نقرأ كل المستندات ثم نفلتر محلياً لتحاشي مشاكل الفهرس أو أنواع الحقول
      final snap = await _firestore.collection('trips').get();
      final docs = <Map<String, dynamic>>[];
      for (final d in snap.docs) {
        final data = d.data();
        final raw = data['availableSeats'] ?? data['available_seats'];
        final seats = (raw is int) ? raw : int.tryParse('$raw') ?? 0;
        if (seats > 0) {
          docs.add({'id': d.id, 'availableSeats': seats, 'status': data['status'], 'data': data});
        }
      }
      debugPrint('DebugTrips: seatsFilter count=${docs.length}');
      setState(() { _results = docs; });
    } catch (e, st) {
      debugPrint('DebugTrips _runQuerySeatsFilter error: $e\n$st');
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _runQueryDriverTrips(String driverId) async {
    setState(() { _loading = true; _error = ''; _lastAction = 'جلب رحلات السائق driverId=$driverId'; _results = []; });
    try {
      final snap = await _firestore.collection('trips').where('driverId', isEqualTo: driverId).get();
      final docs = snap.docs.map((d) => {'id': d.id, 'data': d.data()}).toList();
      debugPrint('DebugTrips: driverTrips count=${docs.length}');
      setState(() { _results = docs; });
    } catch (e, st) {
      debugPrint('DebugTrips _runQueryDriverTrips error: $e\n$st');
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  // الدالة الجديدة: جلب ثم فلترة محلياً على وجود كلمة active أو مكافئات عربية داخل حقل status
  Future<void> _runQueryStatusContainsActive() async {
    setState(() { _loading = true; _error = ''; _lastAction = "جلب مستندات ثم فلترة محلياً على 'active'"; _results = []; });
    try {
      final snap = await _firestore.collection('trips').get();
      final docs = <Map<String, dynamic>>[];
      for (final d in snap.docs) {
        final data = d.data();
        final statusRaw = (data['status'] ?? '').toString().toLowerCase();
        if (statusRaw.contains('active') || statusRaw.contains('نش') || statusRaw.contains('مفع')) {
          docs.add({'id': d.id, 'status': data['status'], 'data': data});
        }
      }
      debugPrint('DebugTrips: statusContainsActive count=${docs.length}');
      setState(() { _results = docs; });
    } catch (e, st) {
      debugPrint('DebugTrips _runQueryStatusContainsActive error: $e\n$st');
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Widget _buildResultTile(Map<String, dynamic> item) {
    final id = item['id'] ?? '';
    final status = item['status'] ?? (item['data']?['status'] ?? '—');
    final seats = item['availableSeats'] ?? (item['data']?['availableSeats'] ?? item['data']?['available_seats'] ?? '—');
    return ListTile(
      title: Text('id: $id', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      subtitle: Text('status: $status — seats: $seats'),
      isThreeLine: false,
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Trips Queries', style: TextStyle(fontFamily: 'Cairo'))),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: _loading ? null : _runQueryAll, child: const Text('جلب كل المستندات')),
                ElevatedButton(onPressed: _loading ? null : _runQueryStatusVariants, child: const Text('جلب حسب status (variants)')),
                ElevatedButton(onPressed: _loading ? null : _runQuerySeatsFilter, child: const Text('جلب مع فلتر المقاعد')),
                ElevatedButton(onPressed: _loading ? null : _runQueryStatusContainsActive, child: const Text("جلب status يحتوي 'active'")),
                ElevatedButton(
                  onPressed: _loading ? null : () => _showDriverIdDialog(),
                  child: const Text('جلب رحلات سائق محدد'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('آخر إجراء: $_lastAction', style: const TextStyle(fontFamily: 'Cairo')),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('خطأ: $_error', style: const TextStyle(color: Colors.red, fontFamily: 'Cairo')),
            ],
            const SizedBox(height: 8),
            _loading ? const LinearProgressIndicator() : const SizedBox(height: 4),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                  ? Center(child: Text('لا توجد نتائج حالياً', style: const TextStyle(fontFamily: 'Cairo')))
                  : ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) => _buildResultTile(_results[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDriverIdDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('معرف السائق', style: TextStyle(fontFamily: 'Cairo')),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'أدخل driverId')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final id = controller.text.trim();
              Navigator.of(ctx).pop();
              if (id.isNotEmpty) _runQueryDriverTrips(id);
            },
            child: const Text('تشغيل'),
          ),
        ],
      ),
    );
  }
}
