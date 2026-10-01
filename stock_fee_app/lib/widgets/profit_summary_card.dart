import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fee_calculation.dart';
import '../theme/app_theme.dart';

class ProfitSummaryCard extends StatelessWidget {
  final FeeCalculationResult result;
  final VoidCallback onViewDetails;

  const ProfitSummaryCard({
    super.key,
    required this.result,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,###');
    final isProfit = result.isProfitable;
    final isLoss = result.isLoss;

    final profitColor = isProfit
        ? AppTheme.twGainRed
        : (isLoss ? AppTheme.twLossGreen : Colors.white70);

    final profitSign = result.netProfit > 0 ? '+' : '';
    final roiSign = result.roi > 0 ? '+' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isProfit
              ? [const Color(0xFF2E151B), const Color(0xFF1E293B)]
              : (isLoss
                  ? [const Color(0xFF132B24), const Color(0xFF1E293B)]
                  : [const Color(0xFF1E293B), const Color(0xFF192237)]),
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isProfit
              ? AppTheme.twGainRed.withValues(alpha: 0.3)
              : (isLoss
                  ? AppTheme.twLossGreen.withValues(alpha: 0.3)
                  : const Color(0xFF334155)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '預估淨損益',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: profitColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: profitColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isProfit
                          ? Icons.arrow_drop_up
                          : (isLoss ? Icons.arrow_drop_down : Icons.remove),
                      color: profitColor,
                      size: 18,
                    ),
                    Text(
                      '$roiSign${result.roi.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: profitColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'NT\$',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: profitColor.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$profitSign${currencyFormatter.format(result.netProfit)}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: profitColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  '買進總支出',
                  'NT\$ ${currencyFormatter.format(result.totalBuyCost)}',
                  '含手續費 \$${result.buyFee}',
                ),
              ),
              Container(height: 36, width: 1, color: const Color(0xFF334155)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _buildInfoItem(
                    '賣出實收金額',
                    'NT\$ ${currencyFormatter.format(result.netSellIncome)}',
                    '已扣手續費與稅',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onViewDetails,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 16, color: Color(0xFF60A5FA)),
                  SizedBox(width: 6),
                  Text(
                    '查看手續費與稅額詳細計算表',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF60A5FA),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16, color: Color(0xFF60A5FA)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String value, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
