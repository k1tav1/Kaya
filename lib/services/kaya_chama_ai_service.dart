class KayaChamaAIService {
  static Map<String, dynamic> analyzeGoalProgress({
    required double targetAmount,
    required double currentAmount,
    required int targetMonths,
  }) {
    final remainingAmount = (targetAmount - currentAmount).clamp(
      0,
      double.infinity,
    );
    final requiredMonthly = targetMonths > 0
        ? remainingAmount / targetMonths
        : 0.0;
    final progressPercent = targetAmount > 0
        ? ((currentAmount / targetAmount) * 100).clamp(0, 100)
        : 0.0;

    String status;
    String advice;

    if (progressPercent >= 75) {
      status = "Strong progress";
      advice =
          "Your chama is making strong progress toward the goal. Staying consistent may be more important than taking extra risk.";
    } else if (progressPercent >= 40) {
      status = "Moderate progress";
      advice =
          "Your chama is progressing, but consistency matters. A balanced strategy may help you grow while keeping risk controlled.";
    } else {
      status = "Slow progress";
      advice =
          "Your chama is still early in the journey. You may need either higher monthly contributions, a longer timeline, or a clearer investment plan.";
    }

    return {
      'remainingAmount': remainingAmount,
      'requiredMonthly': requiredMonthly,
      'progressPercent': progressPercent,
      'status': status,
      'advice': advice,
    };
  }
}
