import '../models/broker_setting.dart';
import '../models/fee_calculation.dart';

class FeeCalculator {
  static const double baseFeeRate = 0.001425; // 0.1425%

  /// 取得台股股價對應的升降單位 (Tick Size)
  static double getTickSize(double price) {
    if (price < 10.0) {
      return 0.01;
    } else if (price < 50.0) {
      return 0.05;
    } else if (price < 100.0) {
      return 0.10;
    } else if (price < 500.0) {
      return 0.50;
    } else if (price < 1000.0) {
      return 1.00;
    } else {
      return 5.00;
    }
  }

  /// 向上跳動至下一個合法的檔位 (依台股升降單位規則)
  static double roundUpToNextTick(double price) {
    if (price <= 0) return 0.0;
    double current = (price * 100).round() / 100.0;
    double tick = getTickSize(current);
    // 依 tick 向上微調
    double steps = (current / tick).ceilToDouble();
    double result = steps * tick;
    return double.parse(result.toStringAsFixed(2));
  }

  /// 計算單次手續費
  static int calculateFee({
    required double tradeAmount,
    required double discountRate,
    required int minFee,
    required FeeRoundingMethod roundingMethod,
  }) {
    if (tradeAmount <= 0) return 0;
    double rawFee = tradeAmount * baseFeeRate * discountRate;
    int calculatedFee = roundingMethod == FeeRoundingMethod.round
        ? rawFee.round()
        : rawFee.floor();

    if (calculatedFee < minFee) {
      return minFee;
    }
    return calculatedFee;
  }

  /// 計算證券交易稅 (賣出收取)
  static int calculateTax({
    required double tradeAmount,
    required TradeTaxType taxType,
  }) {
    if (tradeAmount <= 0) return 0;
    return (tradeAmount * taxType.rate).round();
  }

  /// 完整計算損益與手續費明細
  static FeeCalculationResult calculate({
    required double buyPrice,
    required double sellPrice,
    required int shares,
    required BrokerSetting broker,
    required TradeTaxType taxType,
  }) {
    final double rawBuyAmount = buyPrice * shares;
    final int buyAmount = rawBuyAmount.round();
    final int buyFeeOriginal = (rawBuyAmount * baseFeeRate).round();
    final int buyFee = calculateFee(
      tradeAmount: rawBuyAmount,
      discountRate: broker.discountRate,
      minFee: broker.minFee,
      roundingMethod: broker.roundingMethod,
    );
    final int totalBuyCost = buyAmount + buyFee;

    final double rawSellAmount = sellPrice * shares;
    final int sellAmount = rawSellAmount.round();
    final int sellFeeOriginal = (rawSellAmount * baseFeeRate).round();
    final int sellFee = calculateFee(
      tradeAmount: rawSellAmount,
      discountRate: broker.discountRate,
      minFee: broker.minFee,
      roundingMethod: broker.roundingMethod,
    );
    final int sellTax = calculateTax(
      tradeAmount: rawSellAmount,
      taxType: taxType,
    );
    final int totalSellExpenses = sellFee + sellTax;
    final int netSellIncome = sellAmount - totalSellExpenses;

    final int netProfit = netSellIncome - totalBuyCost;
    final double roi = totalBuyCost > 0 ? (netProfit / totalBuyCost) * 100 : 0.0;

    // 計算損益兩平價
    final double breakeven = calculateBreakevenPrice(
      buyPrice: buyPrice,
      shares: shares,
      broker: broker,
      taxType: taxType,
    );

    // 計算合乎台股跳動檔位且淨損益 >= 0 的保證獲利賣出價
    final safeTickResult = findProfitableTick(
      buyPrice: buyPrice,
      shares: shares,
      broker: broker,
      taxType: taxType,
      startingPrice: breakeven,
    );

    return FeeCalculationResult(
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      shares: shares,
      taxType: taxType,
      broker: broker,
      buyAmount: buyAmount,
      buyFeeOriginal: buyFeeOriginal,
      buyFee: buyFee,
      totalBuyCost: totalBuyCost,
      sellAmount: sellAmount,
      sellFeeOriginal: sellFeeOriginal,
      sellFee: sellFee,
      sellTax: sellTax,
      totalSellExpenses: totalSellExpenses,
      netSellIncome: netSellIncome,
      netProfit: netProfit,
      roi: roi,
      breakevenPrice: breakeven,
      safeBreakevenPriceTick: safeTickResult.key,
      profitAtSafeTick: safeTickResult.value,
    );
  }

  /// 數學反推損益兩平價 (小數點後兩位)
  static double calculateBreakevenPrice({
    required double buyPrice,
    required int shares,
    required BrokerSetting broker,
    required TradeTaxType taxType,
  }) {
    if (buyPrice <= 0 || shares <= 0) return 0.0;

    final double buyAmount = buyPrice * shares;
    final int buyFee = calculateFee(
      tradeAmount: buyAmount,
      discountRate: broker.discountRate,
      minFee: broker.minFee,
      roundingMethod: broker.roundingMethod,
    );
    final double targetTotalIncome = buyAmount + buyFee;

    // 假定手續費高於低消：
    // Net = S * [1 - (0.001425 * discount) - taxRate]
    final double effectiveFeeRate = baseFeeRate * broker.discountRate;
    final double divisor = 1.0 - effectiveFeeRate - taxType.rate;

    if (divisor <= 0) return buyPrice;

    double estimatedSellAmount = targetTotalIncome / divisor;
    double estimatedSellPrice = estimatedSellAmount / shares;

    // 檢查是否觸及賣出低消
    int checkSellFee = calculateFee(
      tradeAmount: estimatedSellAmount,
      discountRate: broker.discountRate,
      minFee: broker.minFee,
      roundingMethod: broker.roundingMethod,
    );

    if (checkSellFee == broker.minFee) {
      // 賣出手續費受限於低消 minFee:
      // Net = S * (1 - taxRate) - minFee = targetTotalIncome
      // S * (1 - taxRate) = targetTotalIncome + minFee
      double adjDivisor = 1.0 - taxType.rate;
      estimatedSellAmount = (targetTotalIncome + broker.minFee) / adjDivisor;
      estimatedSellPrice = estimatedSellAmount / shares;
    }

    return double.parse(estimatedSellPrice.toStringAsFixed(2));
  }

  /// 尋找最小符合台股升降檔位且損益 >= 0 的賣出價格
  static MapEntry<double, int> findProfitableTick({
    required double buyPrice,
    required int shares,
    required BrokerSetting broker,
    required TradeTaxType taxType,
    required double startingPrice,
  }) {
    if (buyPrice <= 0 || shares <= 0) return const MapEntry(0.0, 0);

    double candidate = roundUpToNextTick(startingPrice);
    final double buyAmount = buyPrice * shares;
    final int buyFee = calculateFee(
      tradeAmount: buyAmount,
      discountRate: broker.discountRate,
      minFee: broker.minFee,
      roundingMethod: broker.roundingMethod,
    );
    final int totalBuyCost = buyAmount.round() + buyFee;

    for (int i = 0; i < 50; i++) {
      double sellAmount = candidate * shares;
      int sellFee = calculateFee(
        tradeAmount: sellAmount,
        discountRate: broker.discountRate,
        minFee: broker.minFee,
        roundingMethod: broker.roundingMethod,
      );
      int sellTax = calculateTax(
        tradeAmount: sellAmount,
        taxType: taxType,
      );
      int netSell = sellAmount.round() - sellFee - sellTax;
      int profit = netSell - totalBuyCost;

      if (profit >= 0) {
        return MapEntry(candidate, profit);
      }
      double tick = getTickSize(candidate);
      candidate = double.parse((candidate + tick).toStringAsFixed(2));
    }

    return MapEntry(candidate, 0);
  }
}
