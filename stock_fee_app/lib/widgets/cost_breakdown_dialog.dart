import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fee_calculation.dart';
import '../theme/app_theme.dart';

class CostBreakdownDialog extends StatelessWidget {
  final FeeCalculationResult result;

  const CostBreakdownDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final discountPercent = (result.broker.discountRate * 10).toStringAsFixed(1);

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt, color: Color(0xFF60A5FA), size: 22),
                    SizedBox(width: 8),
                    Text(
                      '交易費用明細',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 16),

            // 買進區塊
            _buildSectionHeader('買進交易 (支出)', Icons.call_received, Colors.amber),
            const SizedBox(height: 8),
            _buildRow('買進成交金額', 'NT\$ ${fmt.format(result.buyAmount)}',
                subText: '\$${result.buyPrice} × ${fmt.format(result.shares)} 股'),
            _buildRow(
              '券商手續費 (0.1425% × $discountPercent折)',
              'NT\$ ${fmt.format(result.buyFee)}',
              subText: result.buyFee == result.broker.minFee &&
                      result.buyFeeOriginal * result.broker.discountRate < result.broker.minFee
                  ? '（觸及最低低消 ${result.broker.minFee} 元）'
                  : '（原始手續費 \$${result.buyFeeOriginal}）',
            ),
            _buildRow('買進總成本', 'NT\$ ${fmt.format(result.totalBuyCost)}', isBold: true),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 16),

            // 賣出區塊
            _buildSectionHeader('賣出交易 (收入)', Icons.call_made, const Color(0xFF60A5FA)),
            const SizedBox(height: 8),
            _buildRow('賣出成交金額', 'NT\$ ${fmt.format(result.sellAmount)}',
                subText: '\$${result.sellPrice} × ${fmt.format(result.shares)} 股'),
            _buildRow(
              '券商手續費 (0.1425% × $discountPercent折)',
              '- NT\$ ${fmt.format(result.sellFee)}',
              subText: result.sellFee == result.broker.minFee &&
                      result.sellFeeOriginal * result.broker.discountRate < result.broker.minFee
                  ? '（觸及最低低消 ${result.broker.minFee} 元）'
                  : '（原始手續費 \$${result.sellFeeOriginal}）',
            ),
            _buildRow(
              '證券交易稅 (${result.taxType.label})',
              '- NT\$ ${fmt.format(result.sellTax)}',
            ),
            _buildRow(
              '賣出費用合計',
              '- NT\$ ${fmt.format(result.totalSellExpenses)}',
              subText: '手續費 + 證交稅',
            ),
            _buildRow('賣出實收金額', 'NT\$ ${fmt.format(result.netSellIncome)}', isBold: true),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 16),

            // 結算區塊
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161F30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  _buildRow('總手續費支出 (買+賣)', 'NT\$ ${fmt.format(result.buyFee + result.sellFee)}'),
                  _buildRow('總交易稅支出', 'NT\$ ${fmt.format(result.sellTax)}'),
                  const SizedBox(height: 6),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '最終淨損益',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${result.netProfit >= 0 ? '+' : ''}NT\$ ${fmt.format(result.netProfit)}',
                        style: TextStyle(
                          color: result.isProfitable
                              ? AppTheme.twGainRed
                              : (result.isLoss ? AppTheme.twLossGreen : Colors.white),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('關閉'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value, {String? subText, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isBold ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: isBold ? Colors.white : Colors.white,
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
          if (subText != null)
            Text(
              subText,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}
