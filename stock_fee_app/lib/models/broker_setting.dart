enum TradeTaxType {
  stock('現股 (0.3%)', 0.003),
  dayTrade('現股當沖 (0.15%)', 0.0015),
  etf('ETF (0.1%)', 0.001);

  final String label;
  final double rate;
  const TradeTaxType(this.label, this.rate);
}

enum FeeRoundingMethod {
  round('四捨五入'),
  floor('無條件捨去');

  final String label;
  const FeeRoundingMethod(this.label);
}

class BrokerSetting {
  final String name;
  final double discountRate; // e.g. 0.28 for 2.8折
  final int minFee; // e.g. 20 or 1
  final FeeRoundingMethod roundingMethod;

  const BrokerSetting({
    this.name = '自訂券商',
    this.discountRate = 0.6, // 預設 6 折
    this.minFee = 20, // 預設 20 元低消
    this.roundingMethod = FeeRoundingMethod.round,
  });

  BrokerSetting copyWith({
    String? name,
    double? discountRate,
    int? minFee,
    FeeRoundingMethod? roundingMethod,
  }) {
    return BrokerSetting(
      name: name ?? this.name,
      discountRate: discountRate ?? this.discountRate,
      minFee: minFee ?? this.minFee,
      roundingMethod: roundingMethod ?? this.roundingMethod,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'discountRate': discountRate,
        'minFee': minFee,
        'roundingMethod': roundingMethod.name,
      };

  factory BrokerSetting.fromJson(Map<String, dynamic> json) {
    return BrokerSetting(
      name: json['name'] ?? '自訂券商',
      discountRate: (json['discountRate'] as num?)?.toDouble() ?? 0.6,
      minFee: (json['minFee'] as num?)?.toInt() ?? 20,
      roundingMethod: FeeRoundingMethod.values.firstWhere(
        (e) => e.name == json['roundingMethod'],
        orElse: () => FeeRoundingMethod.round,
      ),
    );
  }
}
