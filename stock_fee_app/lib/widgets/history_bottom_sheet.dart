import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/history_record.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class HistoryBottomSheet extends StatefulWidget {
  final Function(HistoryRecord) onSelectRecord;

  const HistoryBottomSheet({super.key, required this.onSelectRecord});

  @override
  State<HistoryBottomSheet> createState() => _HistoryBottomSheetState();
}

class _HistoryBottomSheetState extends State<HistoryBottomSheet> {
  List<HistoryRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await StorageService.loadHistory();
    if (mounted) {
      setState(() {
        _records = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecord(String id) async {
    await StorageService.deleteRecord(id);
    _loadHistory();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('清除所有歷史紀錄'),
        content: const Text('確定要清除所有試算紀錄嗎？此動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.clearHistory();
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('MM/dd HH:mm');
    final numFmt = NumberFormat('#,###');

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history, color: Color(0xFF60A5FA), size: 22),
                    SizedBox(width: 8),
                    Text(
                      '試算歷史紀錄',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (_records.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white54),
                    label: const Text('清除全部', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    onPressed: _clearAll,
                  ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? const Center(
                        child: Text(
                          '尚無儲存的試算紀錄\n在計算頁面點擊「儲存紀錄」即可存檔',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, height: 1.5),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _records.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final item = _records[i];
                          final isProfit = item.netProfit > 0;
                          final isLoss = item.netProfit < 0;
                          final color = isProfit
                              ? AppTheme.twGainRed
                              : (isLoss ? AppTheme.twLossGreen : Colors.white70);

                          return InkWell(
                            onTap: () {
                              widget.onSelectRecord(item);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF243048),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.taxType.label,
                                                style: const TextStyle(
                                                    color: Colors.white70, fontSize: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '買 \$${item.buyPrice} → 賣 \$${item.sellPrice} (${numFmt.format(item.shares)}股)',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${timeFmt.format(item.createdAt)} · ${(item.discountRate * 10).toStringAsFixed(1)}折 · 低消\$${item.minFee}',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item.netProfit > 0 ? '+' : ''}${numFmt.format(item.netProfit)}',
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.roi > 0 ? '+' : ''}${item.roi.toStringAsFixed(2)}%',
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.white38),
                                    onPressed: () => _deleteRecord(item.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
