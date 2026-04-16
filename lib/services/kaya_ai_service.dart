class KayaAIService {
  static Map<String, dynamic> analyzeInvestment({
    required double amount,
    required int months,
    required String riskProfile,
  }) {
    const safeRate = 0.0075;
    const balancedRate = 0.0100;
    const aggressiveRate = 0.0150;

    final safeReturn = amount * (1 + safeRate * months);
    final balancedReturn = amount * (1 + balancedRate * months);
    final aggressiveReturn = amount * (1 + aggressiveRate * months);

    String recommendation;
    String reason;
    String riskLevel;
    String allocation;

    switch (riskProfile) {
      case 'Conservative':
        recommendation = 'Treasury Bills / Fixed Income';
        reason =
            'This fits a conservative profile because it focuses more on protecting capital and reducing volatility.';
        riskLevel = 'Low';
        allocation = '70% safe, 20% balanced, 10% aggressive';
        break;
      case 'Aggressive':
        recommendation = 'Stocks / ETF Basket';
        reason =
            'This fits an aggressive profile because it targets stronger growth and accepts larger market fluctuations.';
        riskLevel = 'High';
        allocation = '20% safe, 30% balanced, 50% aggressive';
        break;
      default:
        recommendation = 'Money Market Fund';
        reason =
            'This fits a balanced profile because it offers a middle ground between growth, flexibility, and stability.';
        riskLevel = 'Moderate';
        allocation = '30% safe, 50% balanced, 20% aggressive';
    }

    return {
      'recommendation': recommendation,
      'reason': reason,
      'riskLevel': riskLevel,
      'allocation': allocation,
      'safeReturn': safeReturn,
      'balancedReturn': balancedReturn,
      'aggressiveReturn': aggressiveReturn,
    };
  }
}
