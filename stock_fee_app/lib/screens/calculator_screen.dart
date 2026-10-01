import 'package:flutter/material.dart';
import '../models/broker_setting.dart';
import '../models/fee_calculation.dart';
import '../models/history_record.dart';
import '../services/fee_calculator.dart';
import '../services/storage_service.dart';
import '../widgets/custom_number_field.dart';
import '../widgets/quick_discount_chips.dart';
import '../widgets/profit_summary_card.dart';
import '../widgets/cost_breakdown_dialog.dart';
import '../widgets/history_bottom_sheet.dart';
import 'breakeven_screen.dart';
import 'settings_screen.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final TextEditingController _buyPriceCtrl = TextEditingController(text: '100.0');
  final TextEditingController _sellPriceCtrl = TextEditingController(text: '105.0');
  final TextEditingController _sharesCtrl = TextEditingController(text: '1000');
  final TextEditingController _stockTitleCtrl = TextEditingController(text: '台積電 (2330)');

  BrokerSetting _broker = const BrokerSetting();
  TradeTaxType _taxType = TradeTaxType.stock;
  bool _isRoundLot = true; // 整股 (1000) vs 零股

  FeeCalculationResult? _result;

  @override
  void initState() {
    super.initState();
    _loadBrokerSetting();
  }

  Future<void> _loadBrokerSetting() async {
    final setting = await StorageService.loadBrokerSetting();
    if (mounted) {
      setState(() {
        _broker = setting;
        _recalculate();
      });
    }
  }

  void _recalculate() {
    final buyPrice = double.tryParse(_buyPriceCtrl.text) ?? 0.0;
    final sellPrice = double.tryParse(_sellPriceCtrl.text) ?? 0.0;
    final shares = int.tryParse(_sharesCtrl.text) ?? 0;

    if (buyPrice > 0 && sellPrice > 0 && shares > 0) {
      setState(() {
        _result = FeeCalculator.calculate(
          buyPrice: buyPrice,
          sellPrice: sellPrice,
          shares: shares,
          broker: _broker,
          taxType: _taxType,
        );
      });
    } else {
      setState(() {
        _result = null;
      });
    }
  }

  void _adjustBuyPrice(bool increment) {
    double price = double.tryParse(_buyPriceCtrl.text) ?? 10.0;
    double tick = FeeCalculator.getTickSize(price);
    price = increment ? price + tick : (price - tick > 0 ? price - tick : tick);
    _buyPriceCtrl.text = price.toStringAsFixed(2);
    _recalculate();
  }

  void _adjustSellPrice(bool increment) {
    double price = double.tryParse(_sellPriceCtrl.text) ?? 10.0;
    double tick = FeeCalculator.getTickSize(price);
    price = increment ? price + tick : (price - tick > 0 ? price - tick : tick);
    _sellPriceCtrl.text = price.toStringAsFixed(2);
    _recalculate();
  }

  void _setShares(int shares) {
    _sharesCtrl.text = shares.toString();
    _recalculate();
  }

  Future<void> _saveCurrentRecord() async {
    if (_result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先輸入有效價格與股數')),
      );
      return;
    }

    final record = HistoryRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _stockTitleCtrl.text.trim().isEmpty
          ? '試算紀錄'
          : _stockTitleCtrl.text.trim(),
      buyPrice: _result!.buyPrice,
      sellPrice: _result!.sellPrice,
      shares: _result!.shares,
      taxType: _result!.taxType,
      discountRate: _broker.discountRate,
      minFee: _broker.minFee,
      netProfit: _result!.netProfit,
      roi: _result!.roi,
      createdAt: DateTime.now(),
    );

    await StorageService.saveRecord(record);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已儲存試算紀錄'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _applyHistoryRecord(HistoryRecord record) {
    setState(() {
      _stockTitleCtrl.text = record.title;
      _buyPriceCtrl.text = record.buyPrice.toString();
      _sellPriceCtrl.text = record.sellPrice.toString();
      _sharesCtrl.text = record.shares.toString();
      _taxType = record.taxType;
      _broker = _broker.copyWith(
        discountRate: record.discountRate,
        minFee: record.minFee,
      );
      _recalculate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final discountPercent = (_broker.discountRate * 10).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.show_chart, color: Color(0xFF60A5FA), size: 24),
            SizedBox(width: 8),
            Text('台股手續費計算器'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '歷史紀錄',
            icon: const Icon(Icons.history),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => HistoryBottomSheet(
                  onSelectRecord: _applyHistoryRecord,
                ),
              );
            },
          ),
          IconButton(
            tooltip: '損益兩平試算',
            icon: const Icon(Icons.balance),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => BreakevenScreen(
                    initialBuyPrice: double.tryParse(_buyPriceCtrl.text) ?? 100.0,
                    initialShares: int.tryParse(_sharesCtrl.text) ?? 1000,
                    broker: _broker,
                    taxType: _taxType,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: '券商設定',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              final updated = await Navigator.push<BrokerSetting>(
                context,
                MaterialPageRoute(
                  builder: (ctx) => SettingsScreen(currentSetting: _broker),
                ),
              );
              if (updated != null) {
                setState(() {
                  _broker = updated;
                  _recalculate();
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頂部券商快速資訊條
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance, size: 16, color: Color(0xFF60A5FA)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_broker.name} · $discountPercent 折 · 低消 NT\$${_broker.minFee}',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final updated = await Navigator.push<BrokerSetting>(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => SettingsScreen(currentSetting: _broker),
                        ),
                      );
                      if (updated != null) {
                        setState(() {
                          _broker = updated;
                          _recalculate();
                        });
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('修改', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 標的備註 (非必填)
            TextField(
              controller: _stockTitleCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: '標的名稱或代號 (例: 2330 台積電)',
                prefixIcon: Icon(Icons.bookmark_outline, size: 18, color: Colors.white54),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                fillColor: Color(0xFF192237),
              ),
            ),
            const SizedBox(height: 14),

            // 交易稅率類型選擇 (現股 / 當沖 / ETF)
            const Text(
              '交易類型 / 稅率',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Row(
              children: TradeTaxType.values.map((type) {
                final isSelected = _taxType == type;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _taxType = type;
                          _recalculate();
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
            const SizedBox(height: 16),

            // 買進 / 賣出價格輸入列
            Row(
              children: [
                Expanded(
                  child: CustomNumberField(
                    label: '買進價格 (NT\$)',
                    controller: _buyPriceCtrl,
                    prefixIcon: Icons.arrow_downward,
                    suffixText: '元',
                    onChanged: (v) => _recalculate(),
                    onIncrement: () => _adjustBuyPrice(true),
                    onDecrement: () => _adjustBuyPrice(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomNumberField(
                    label: '賣出價格 (NT\$)',
                    controller: _sellPriceCtrl,
                    prefixIcon: Icons.arrow_upward,
                    suffixText: '元',
                    onChanged: (v) => _recalculate(),
                    onIncrement: () => _adjustSellPrice(true),
                    onDecrement: () => _adjustSellPrice(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 股數與零股/整股切換
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '交易股數',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('整股 (張)'),
                      selected: _isRoundLot,
                      onSelected: (val) {
                        setState(() {
                          _isRoundLot = true;
                          _setShares(1000);
                        });
                      },
                      selectedColor: const Color(0xFF3B82F6),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: _isRoundLot ? Colors.white : Colors.white60,
                        fontWeight: _isRoundLot ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('零股 (股)'),
                      selected: !_isRoundLot,
                      onSelected: (val) {
                        setState(() {
                          _isRoundLot = false;
                          _setShares(100);
                        });
                      },
                      selectedColor: const Color(0xFF3B82F6),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: !_isRoundLot ? Colors.white : Colors.white60,
                        fontWeight: !_isRoundLot ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            CustomNumberField(
              label: '',
              controller: _sharesCtrl,
              prefixIcon: Icons.pie_chart_outline,
              suffixText: '股',
              onChanged: (v) => _recalculate(),
              onIncrement: () {
                int s = int.tryParse(_sharesCtrl.text) ?? 1000;
                int step = _isRoundLot ? 1000 : 100;
                _setShares(s + step);
              },
              onDecrement: () {
                int s = int.tryParse(_sharesCtrl.text) ?? 1000;
                int step = _isRoundLot ? 1000 : 100;
                if (s > step) _setShares(s - step);
              },
            ),
            const SizedBox(height: 8),

            // 快速股數選擇晶片
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_isRoundLot) ...[
                    _buildShareQuickChip('1 張', 1000),
                    _buildShareQuickChip('2 張', 2000),
                    _buildShareQuickChip('3 張', 3000),
                    _buildShareQuickChip('5 張', 5000),
                    _buildShareQuickChip('10 張', 10000),
                  ] else ...[
                    _buildShareQuickChip('50 股', 50),
                    _buildShareQuickChip('100 股', 100),
                    _buildShareQuickChip('200 股', 200),
                    _buildShareQuickChip('500 股', 500),
                    _buildShareQuickChip('800 股', 800),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 快速折讓選擇
            const Text(
              '快速切換折讓',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            QuickDiscountChips(
              currentDiscount: _broker.discountRate,
              onSelected: (discount) {
                setState(() {
                  _broker = _broker.copyWith(discountRate: discount);
                  _recalculate();
                });
              },
            ),
            const SizedBox(height: 20),

            // 損益結果卡片
            if (_result != null) ...[
              ProfitSummaryCard(
                result: _result!,
                onViewDetails: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => CostBreakdownDialog(result: _result!),
                  );
                },
              ),
              const SizedBox(height: 16),

              // 底部功能快捷操作列
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: const Text('儲存紀錄'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saveCurrentRecord,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calculate_outlined, size: 18),
                      label: const Text('損益兩平試算'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => BreakevenScreen(
                              initialBuyPrice: _result!.buyPrice,
                              initialShares: _result!.shares,
                              broker: _broker,
                              taxType: _taxType,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.calculate, size: 48, color: Colors.white24),
                    SizedBox(height: 12),
                    Text(
                      '請輸入有效的買進與賣出價格',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildShareQuickChip(String label, int shares) {
    final currentShares = int.tryParse(_sharesCtrl.text) ?? 0;
    final isSelected = currentShares == shares;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: () => _setShares(shares),
        backgroundColor: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF334155),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
