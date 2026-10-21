// lib/widgets/web_performance_chart.dart
import 'package:flutter/material.dart';

class WebPerformanceChart extends StatelessWidget {
  const WebPerformanceChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF181B20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('مؤشر حركة الحجوزات الأسبوعي', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar('السبت', 0.4),
                _buildBar('الأحد', 0.6),
                _buildBar('الإثنين', 0.8),
                _buildBar('الثلاثاء', 0.5),
                _buildBar('الأربعاء', 0.9),
                _buildBar('الخميس', 1.0),
                _buildBar('الجمعة', 0.7),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String day, double heightFactor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FractionallySizedBox(
          heightFactor: heightFactor,
          child: Container(
            width: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF17A5A3), Color(0xFF1E70B8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Cairo')),
      ],
    );
  }
}