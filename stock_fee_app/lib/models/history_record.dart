import 'dart:convert';
import 'broker_setting.dart';

class HistoryRecord {
  final String id;
  final String title;
  final double buyPrice;
  final double sellPrice;
  final int shares;
  final TradeTaxType taxType;
  final double discountRate;
  final int minFee;
  final int netProfit;
  final double roi;
  final DateTime createdAt;

  HistoryRecord({
    required this.id,
    required this.title,
    required this.buyPrice,
    required this.sellPrice,
    required this.shares,
    required this.taxType,
    required this.discountRate,
    required this.minFee,
    required this.netProfit,
    required this.roi,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'shares': shares,
        'taxType': taxType.name,
        'discountRate': discountRate,
        'minFee': minFee,
        'netProfit': netProfit,
        'roi': roi,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HistoryRecord.fromMap(Map<String, dynamic> map) {
    return HistoryRecord(
      id: map['id'] ?? '',
      title: map['title'] ?? '未命名計算',
      buyPrice: (map['buyPrice'] as num?)?.toDouble() ?? 0.0,
      sellPrice: (map['sellPrice'] as num?)?.toDouble() ?? 0.0,
      shares: (map['shares'] as num?)?.toInt() ?? 1000,
      taxType: TradeTaxType.values.firstWhere(
        (e) => e.name == map['taxType'],
        orElse: () => TradeTaxType.stock,
      ),
      discountRate: (map['discountRate'] as num?)?.toDouble() ?? 0.6,
      minFee: (map['minFee'] as num?)?.toInt() ?? 20,
      netProfit: (map['netProfit'] as num?)?.toInt() ?? 0,
      roi: (map['roi'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory HistoryRecord.fromJson(String source) =>
      HistoryRecord.fromMap(jsonDecode(source));
}
