import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/broker_setting.dart';
import '../services/fee_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_number_field.dart';

class BreakevenScreen extends StatefulWidget {
  final double initialBuyPrice;
  final int initialShares;
  final BrokerSetting broker;
  final TradeTaxType taxType;

  const BreakevenScreen({
    super.key,
    required this.initialBuyPrice,
    required this.initialShares,
    required this.broker,
    required this.taxType,
  });

  @override
  State<BreakevenScreen> createState() => _BreakevenScreenState();
}

class _BreakevenScreenState extends State<BreakevenScreen> {
  late TextEditingController _buyPriceCtrl;
  late TextEditingController _sharesCtrl;
  late TradeTaxType _taxType;
  late BrokerSetting _broker;

  @override
  void initState() {
    super.initState();
    _buyPriceCtrl = TextEditingController(text: widget.initialBuyPrice.toStringAsFixed(2));
    _sharesCtrl = TextEditingController(text: widget.initialShares.toString());
    _taxType = widget.taxType;
    _broker = widget.broker;
  }

  void _adjustBuyPrice(bool increment) {
    double price = double.tryParse(_buyPriceCtrl.text) ?? 10.0;
    double tick = FeeCalculator.getTickSize(price);
    price = increment ? price + tick : (price - tick > 0 ? price - tick : tick);
    _buyPriceCtrl.text = price.toStringAsFixed(2);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final buyPrice = double.tryParse(_buyPriceCtrl.text) ?? 0.0;
    final shares = int.tryParse(_sharesCtrl.text) ?? 0;

    double breakevenPrice = 0.0;
    double safeTickPrice = 0.0;
    int safeTickProfit = 0;
    double breakevenChangePct = 0.0;
    List<Map<String, dynamic>> ladderList = [];

    if (buyPrice > 0 && shares > 0) {
      breakevenPrice = FeeCalculator.calculateBreakevenPrice(
        buyPrice: buyPrice,
        shares: shares,
        broker: _broker,
        taxType: _taxType,
      );

      final safeTickResult = FeeCalculator.findProfitableTick(
        buyPrice: buyPrice,
        shares: shares,
        broker: _broker,
        taxType: _taxType,
        startingPrice: breakevenPrice,
      );
      safeTickPrice = safeTickResult.key;
      safeTickProfit = safeTickResult.value;

      breakevenChangePct = ((safeTickPrice - buyPrice) / buyPrice) * 100;

      // 生成跳動檔位階梯表 (+1 到 +10 檔)
      double currentPrice = safeTickPrice;
      for (int i = 0; i <= 8; i++) {
        final res = FeeCalculator.calculate(
          buyPrice: buyPrice,
          sellPrice: currentPrice,
          shares: shares,
          broker: _broker,
          taxType: _taxType,
        );
        ladderList.add({
          'price': currentPrice,
          'profit': res.netProfit,
          'roi': res.roi,
          'steps': i == 0 ? '兩平檔位' : '+$i 檔',
        });
        double tick = FeeCalculator.getTickSize(currentPrice);
        currentPrice = double.parse((currentPrice + tick).toStringAsFixed(2));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('損益兩平與檔位試算'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 交易型態選擇
            Row(
              children: TradeTaxType.values.map((type) {
                final isSelected = _taxType == type;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () => setState(() => _taxType = type),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF334155),
                          ),
                        ),
                        child: Text(
                          type.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // 輸入欄位
            Row(
              children: [
                Expanded(
                  child: CustomNumberField(
                    label: '買進價格 (NT\$)',
                    controller: _buyPriceCtrl,
                    prefixIcon: Icons.arrow_downward,
                    suffixText: '元',
                    onChanged: (v) => setState(() {}),
                    onIncrement: () => _adjustBuyPrice(true),
                    onDecrement: () => _adjustBuyPrice(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomNumberField(
                    label: '交易股數',
                    controller: _sharesCtrl,
                    prefixIcon: Icons.pie_chart_outline,
                    suffixText: '股',
                    onChanged: (v) => setState(() {}),
                    onIncrement: () {
                      int s = int.tryParse(_sharesCtrl.text) ?? 1000;
                      _sharesCtrl.text = (s + 1000).toString();
                      setState(() {});
                    },
                    onDecrement: () {
                      int s = int.tryParse(_sharesCtrl.text) ?? 1000;
                      if (s > 1000) {
                        _sharesCtrl.text = (s - 1000).toString();
                        setState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 損益兩平核心卡片
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '保證獲利最小跳動價',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '需要漲幅: ${breakevenChangePct >= 0 ? '+' : ''}${breakevenChangePct.toStringAsFixed(2)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text(
                        'NT\$',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF93C5FD),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        safeTickPrice.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '元',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '在此價位賣出，扣除手續費與稅後可淨收 NT\$ +${fmt.format(safeTickProfit)} 元。',
                    style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '（純數學理論兩平價：NT\$ ${breakevenPrice.toStringAsFixed(2)} 元，依台股跳動升降單位向上靠攏至合法檔位）',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 跳動檔位階梯獲利表
            const Text(
              '台股跳動檔位階梯獲利表 (當沖/短線必備)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(1.2),
                    2: FlexColumnWidth(1.3),
                    3: FlexColumnWidth(1.1),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFF243048)),
                      children: [
                        _buildTableHeader('檔位'),
                        _buildTableHeader('賣出價格'),
                        _buildTableHeader('淨獲利'),
                        _buildTableHeader('報酬率'),
                      ],
                    ),
                    ...ladderList.map((item) {
                      final isFirst = item['steps'] == '兩平檔位';
                      final int profit = item['profit'];
                      final double roi = item['roi'];

                      return TableRow(
                        decoration: BoxDecoration(
                          color: isFirst ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : null,
                          border: const Border(
                            bottom: BorderSide(color: Color(0xFF2D3B52), width: 0.5),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Text(
                              item['steps'],
                              style: TextStyle(
                                color: isFirst ? const Color(0xFF60A5FA) : Colors.white70,
                                fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Text(
                              '\$${(item['price'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Text(
                              '${profit >= 0 ? '+' : ''}${fmt.format(profit)} 元',
                              style: TextStyle(
                                color: profit > 0
                                    ? AppTheme.twGainRed
                                    : (profit < 0 ? AppTheme.twLossGreen : Colors.white70),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Text(
                              '${roi >= 0 ? '+' : ''}${roi.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: roi > 0
                                    ? AppTheme.twGainRed
                                    : (roi < 0 ? AppTheme.twLossGreen : Colors.white70),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
