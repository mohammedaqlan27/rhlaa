// lib/widgets/agency/agency_wallet_card.dart
import 'package:flutter/material.dart';
import '/theme/app_colors.dart';
import '/widgets/shared/app_card.dart';

class AgencyWalletCard extends StatelessWidget {
  final double balance;
  final VoidCallback? onTopUp;
  final VoidCallback? onViewDetails;

  const AgencyWalletCard({
    super.key,
    required this.balance,
    this.onTopUp,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'رصيد المحفظة المتاح',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              if (onViewDetails != null)
                TextButton(
                  onPressed: onViewDetails,
                  child: const Text('التفاصيل', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${balance.toStringAsFixed(2)} ريال',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (onTopUp != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('إيداع أو طلب رصيد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: onTopUp,
              ),
            ),
        ],
      ),
    );
  }
}
