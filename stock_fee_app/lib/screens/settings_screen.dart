import 'package:flutter/material.dart';
import '../models/broker_setting.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  final BrokerSetting currentSetting;

  const SettingsScreen({super.key, required this.currentSetting});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _minFeeCtrl;
  late FeeRoundingMethod _roundingMethod;

  final List<Map<String, dynamic>> _brokerPresets = [
    {'name': '國泰證券', 'discount': 0.28, 'minFee': 1},
    {'name': '永豐大戶投', 'discount': 0.20, 'minFee': 1},
    {'name': '富邦證券', 'discount': 0.18, 'minFee': 1},
    {'name': '新光證券', 'discount': 0.10, 'minFee': 1},
    {'name': '元大證券', 'discount': 0.60, 'minFee': 20},
    {'name': '凱基證券', 'discount': 0.60, 'minFee': 20},
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentSetting.name);
    _discountCtrl = TextEditingController(
      text: (widget.currentSetting.discountRate * 10).toStringAsFixed(1),
    );
    _minFeeCtrl = TextEditingController(text: widget.currentSetting.minFee.toString());
    _roundingMethod = widget.currentSetting.roundingMethod;
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _nameCtrl.text = preset['name'];
      _discountCtrl.text = ((preset['discount'] as double) * 10).toStringAsFixed(1);
      _minFeeCtrl.text = preset['minFee'].toString();
    });
  }

  Future<void> _saveSettings() async {
    final discountVal = double.tryParse(_discountCtrl.text) ?? 6.0;
    // 使用者輸入如 2.8 代表 2.8 折 => rate = 0.28
    final discountRate = (discountVal / 10.0).clamp(0.01, 1.0);
    final minFee = int.tryParse(_minFeeCtrl.text) ?? 20;

    final updated = BrokerSetting(
      name: _nameCtrl.text.trim().isEmpty ? '自訂券商' : _nameCtrl.text.trim(),
      discountRate: discountRate,
      minFee: minFee,
      roundingMethod: _roundingMethod,
    );

    await StorageService.saveBrokerSetting(updated);

    if (mounted) {
      Navigator.pop(context, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('券商與手續費設定'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 快速預設套用
            const Text(
              '常見券商優惠範本 (點擊快速套用)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _brokerPresets.map((preset) {
                return ActionChip(
                  label: Text('${preset['name']} (${((preset['discount'] as double) * 10).toStringAsFixed(1)}折/低消\$${preset['minFee']})'),
                  backgroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFF334155)),
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onPressed: () => _applyPreset(preset),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 設定表單卡片
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('券商名稱', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: '例: 永豐大戶投、國泰證券',
                      prefixIcon: Icon(Icons.account_balance, size: 18, color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('手續費折讓 (折)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: '例: 2.8 代表 2.8 折 (28%)，6 代表 6 折 (60%)',
                      suffixText: '折',
                      prefixIcon: Icon(Icons.percent, size: 18, color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('單筆最低手續費 (低消)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _minFeeCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: '常見為 20 元，零股優惠常為 1 元',
                      suffixText: '元',
                      prefixIcon: Icon(Icons.monetization_on_outlined, size: 18, color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('手續費小數計算方式', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: FeeRoundingMethod.values.map((method) {
                      final isSelected = _roundingMethod == method;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(method.label),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _roundingMethod = method);
                            },
                            selectedColor: const Color(0xFF3B82F6),
                            backgroundColor: const Color(0xFF161F30),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.white60,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 法規說明卡片
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF162032),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2B3A55)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Color(0xFF60A5FA)),
                      SizedBox(width: 8),
                      Text(
                        '台股交易費率法規須知',
                        style: TextStyle(
                          color: Color(0xFF60A5FA),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• 手續費：買進與賣出均收取成交金額之 0.1425%，依券商折讓優惠折扣。\n'
                    '• 證交稅：僅賣出時收取。\n'
                    '   - 一般現股賣出：0.3%\n'
                    '   - 現股當日沖銷 (當沖)：0.15%\n'
                    '   - 指數股票型基金 (ETF)：0.1%\n'
                    '• 最低手續費：法定上限為每筆 20 元，各券商對電子下單或零股通常有 1 元特惠。',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 儲存按鈕
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('儲存設定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
