import 'broker_setting.dart';

class FeeCalculationResult {
  final double buyPrice;
  final double sellPrice;
  final int shares;
  final TradeTaxType taxType;
  final BrokerSetting broker;

  // 買進端
  final int buyAmount;
  final int buyFeeOriginal;
  final int buyFee;
  final int totalBuyCost;

  // 賣出端
  final int sellAmount;
  final int sellFeeOriginal;
  final int sellFee;
  final int sellTax;
  final int totalSellExpenses;
  final int netSellIncome;

  // 損益與報酬率
  final int netProfit;
  final double roi;

  // 損益兩平
  final double breakevenPrice;
  final double safeBreakevenPriceTick;
  final int profitAtSafeTick;

  const FeeCalculationResult({
    required this.buyPrice,
    required this.sellPrice,
    required this.shares,
    required this.taxType,
    required this.broker,
    required this.buyAmount,
    required this.buyFeeOriginal,
    required this.buyFee,
    required this.totalBuyCost,
    required this.sellAmount,
    required this.sellFeeOriginal,
    required this.sellFee,
    required this.sellTax,
    required this.totalSellExpenses,
    required this.netSellIncome,
    required this.netProfit,
    required this.roi,
    required this.breakevenPrice,
    required this.safeBreakevenPriceTick,
    required this.profitAtSafeTick,
  });

  bool get isProfitable => netProfit > 0;
  bool get isLoss => netProfit < 0;
}
