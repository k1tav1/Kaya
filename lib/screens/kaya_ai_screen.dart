import 'package:flutter/material.dart';
import 'kaya_learning_detail_screen.dart';
import '../services/market_service.dart';
import 'kaya_market_detail_screen.dart';
import 'kaya_chat_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/kaya_ai_service.dart';
import '../services/kaya_chama_ai_service.dart';
import '../services/supabase_service.dart';

class KayaAIScreen extends StatefulWidget {
  final String memberName;
  final String chamaName;
  final String chamaId;

  const KayaAIScreen({
    super.key,
    required this.memberName,
    required this.chamaName,
    required this.chamaId,
  });

  @override
  State<KayaAIScreen> createState() => _KayaAIScreenState();
}

class _KayaAIScreenState extends State<KayaAIScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _durationCtrl = TextEditingController();
  final GlobalKey _marketKey = GlobalKey();
  final GlobalKey _comparisonKey = GlobalKey();
  final GlobalKey _learningKey = GlobalKey();
  final TextEditingController _quickAskCtrl = TextEditingController();
  final GlobalKey _amountFieldKey = GlobalKey();
  late Future<Map<String, dynamic>> _chamaFinanceFuture;

  String _riskProfile = 'Balanced';
  Map<String, dynamic>? _comparisonResult;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _durationCtrl.dispose();
    _quickAskCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _chamaFinanceFuture = SupabaseService.getChamaFinanceSummary(
      chamaId: widget.chamaId, // temporary wrong if using name
    );
  }

  void _openKayaChat({String? initialQuestion}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KayaChatScreen(
          memberName: widget.memberName,
          chamaName: widget.chamaName,
          chamaId: widget.chamaId,
          initialQuestion: initialQuestion,
        ),
      ),
    );
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  List<FlSpot> _buildProjectionSpots(
    double principal,
    double monthlyRate,
    int months,
  ) {
    final spots = <FlSpot>[];

    for (int i = 0; i <= months; i++) {
      final value = principal * (1 + (monthlyRate * i));
      spots.add(FlSpot(i.toDouble(), value));
    }

    return spots;
  }

  Widget _buildChamaInsightsCard() {
    String money(num value) => "KES ${value.toStringAsFixed(2)}";

    return FutureBuilder<Map<String, dynamic>>(
      future: _chamaFinanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _WhiteCard(
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return _WhiteCard(
            child: Text(
              'Failed to load chama insights: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final targetAmount = (data['targetAmount'] as num?)?.toDouble() ?? 0.0;
        final currentSaved = (data['currentSaved'] as num?)?.toDouble() ?? 0.0;
        final targetMonths = (data['targetMonths'] as num?)?.toInt() ?? 0;

        final analysis = KayaChamaAIService.analyzeGoalProgress(
          targetAmount: targetAmount,
          currentAmount: currentSaved,
          targetMonths: targetMonths,
        );

        return _WhiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Chama AI insights",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _MiniInfoRow(label: "Target amount", value: money(targetAmount)),
              _MiniInfoRow(label: "Current saved", value: money(currentSaved)),
              _MiniInfoRow(
                label: "Target months",
                value: targetMonths.toString(),
              ),
              _MiniInfoRow(
                label: "Progress",
                value:
                    "${(analysis['progressPercent'] as num).toStringAsFixed(1)}%",
              ),
              _MiniInfoRow(
                label: "Still needed",
                value: money(analysis['remainingAmount'] as num),
              ),
              _MiniInfoRow(
                label: "Monthly need",
                value: money(analysis['requiredMonthly'] as num),
              ),
              _MiniInfoRow(
                label: "Status",
                value: analysis['status'].toString(),
              ),
              const SizedBox(height: 10),
              Text(
                analysis['advice'].toString(),
                style: const TextStyle(color: Colors.black87, height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showQuickAskDialog() async {
    _quickAskCtrl.clear();

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ask Kaya"),
        content: TextField(
          controller: _quickAskCtrl,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText:
                "Type your question about investments, savings or markets...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ask"),
          ),
        ],
      ),
    );

    if (shouldOpen == true && _quickAskCtrl.text.trim().isNotEmpty) {
      _openKayaChat(initialQuestion: _quickAskCtrl.text.trim());
    }
  }

  String _buildAiSummary() {
    final data = _comparisonResult;
    if (data == null) return "";

    final amount = (data['amount'] as num).toDouble();
    final months = data['months'] as int;
    final bestFit = data['bestFit'] as String;

    String profileText;
    String recommendation;

    switch (bestFit) {
      case 'safe':
        profileText = "Conservative";
        recommendation =
            "Treasury Bills / Fixed Income looks most suitable because your profile prioritizes stability and lower risk.";
        break;
      case 'aggressive':
        profileText = "Aggressive";
        recommendation =
            "Stocks / ETF Basket looks most suitable because your profile accepts higher volatility in exchange for stronger growth potential.";
        break;
      default:
        profileText = "Balanced";
        recommendation =
            "Money Market Fund looks most suitable because it offers a middle ground between growth, flexibility, and risk control.";
    }

    return "Based on your $profileText risk preference, an investment of KES ${amount.toStringAsFixed(0)} over $months month(s) suggests that $recommendation Always remember these are learning projections, not guaranteed returns.";
  }

  void _runComparison() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final months = int.tryParse(_durationCtrl.text.trim()) ?? 0;

    if (amount <= 0 || months <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter a valid amount and duration in months."),
        ),
      );
      return;
    }

    final safeRate = _monthlyRateFor('safe');
    final balancedRate = _monthlyRateFor('balanced');
    final aggressiveRate = _monthlyRateFor('aggressive');

    final safeFinal = _futureValue(amount, safeRate, months);
    final balancedFinal = _futureValue(amount, balancedRate, months);
    final aggressiveFinal = _futureValue(amount, aggressiveRate, months);
    final aiAnalysis = KayaAIService.analyzeInvestment(
      amount: amount,
      months: months,
      riskProfile: _riskProfile,
    );

    String bestFit;
    if (_riskProfile == 'Conservative') {
      bestFit = 'safe';
    } else if (_riskProfile == 'Aggressive') {
      bestFit = 'aggressive';
    } else {
      bestFit = 'balanced';
    }

    setState(() {
      _comparisonResult = {
        'amount': amount,
        'months': months,
        'bestFit': bestFit,
        'aiAnalysis': aiAnalysis,
        'safe': {
          'title': 'Treasury Bills / Fixed Income',
          'subtitle': 'Stable and lower-risk option',
          'monthlyRate': safeRate,
          'finalValue': safeFinal,
          'profit': safeFinal - amount,
          'risk': 'Low',
          'liquidity': 'Medium',
          'color': const Color(0xFF1B5E20),
          'bg': const Color(0xFFE8F5E9),
        },
        'balanced': {
          'title': 'Money Market Fund',
          'subtitle': 'Balanced growth with flexibility',
          'monthlyRate': balancedRate,
          'finalValue': balancedFinal,
          'profit': balancedFinal - amount,
          'risk': 'Moderate',
          'liquidity': 'High',
          'color': const Color(0xFF0D47A1),
          'bg': const Color(0xFFE3F2FD),
        },
        'aggressive': {
          'title': 'Stocks / ETF Basket',
          'subtitle': 'Higher upside with more volatility',
          'monthlyRate': aggressiveRate,
          'finalValue': aggressiveFinal,
          'profit': aggressiveFinal - amount,
          'risk': 'High',
          'liquidity': 'High',
          'color': const Color(0xFFE65100),
          'bg': const Color(0xFFFFF3E0),
        },
      };
    });
  }

  double _monthlyRateFor(String type) {
    switch (type) {
      case 'safe':
        return 0.0075; // 0.75% monthly
      case 'balanced':
        return 0.0100; // 1.0% monthly
      case 'aggressive':
        return 0.0150; // 1.5% monthly
      default:
        return 0.0;
    }
  }

  double _futureValue(double principal, double monthlyRate, int months) {
    return principal * (1 + (monthlyRate * months));
  }

  String _money(num value) {
    return "KES ${value.toStringAsFixed(2)}";
  }

  Widget _buildComparisonResults() {
    final data = _comparisonResult;
    if (data == null) return const SizedBox.shrink();

    final safe = data['safe'] as Map<String, dynamic>;
    final balanced = data['balanced'] as Map<String, dynamic>;
    final aggressive = data['aggressive'] as Map<String, dynamic>;
    final bestFit = data['bestFit'];
    final aiAnalysis = data['aiAnalysis'] as Map<String, dynamic>;

    return Column(
      children: [
        const SizedBox(height: 14),
        _RecommendationCard(
          badge: bestFit == 'safe' ? 'Best for you' : 'Safest',
          title: safe['title'],
          subtitle: safe['subtitle'],
          finalValue: _money(safe['finalValue']),
          profit: _money(safe['profit']),
          risk: safe['risk'],
          liquidity: safe['liquidity'],
          bg: safe['bg'],
          color: safe['color'],
        ),
        const SizedBox(height: 10),
        _RecommendationCard(
          badge: bestFit == 'balanced' ? 'Best for you' : 'Balanced',
          title: balanced['title'],
          subtitle: balanced['subtitle'],
          finalValue: _money(balanced['finalValue']),
          profit: _money(balanced['profit']),
          risk: balanced['risk'],
          liquidity: balanced['liquidity'],
          bg: balanced['bg'],
          color: balanced['color'],
        ),
        const SizedBox(height: 10),
        _RecommendationCard(
          badge: bestFit == 'aggressive' ? 'Best for you' : 'Aggressive',
          title: aggressive['title'],
          subtitle: aggressive['subtitle'],
          finalValue: _money(aggressive['finalValue']),
          profit: _money(aggressive['profit']),
          risk: aggressive['risk'],
          liquidity: aggressive['liquidity'],
          bg: aggressive['bg'],
          color: aggressive['color'],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            "These projections are learning estimates, not guaranteed returns. Actual market results can be higher or lower depending on conditions.",
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
        ),
        const SizedBox(height: 12),
        _WhiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Kaya AI recommendation",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                "Recommended option: ${aiAnalysis['recommendation']}",
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                aiAnalysis['reason'].toString(),
                style: const TextStyle(color: Colors.black87, height: 1.5),
              ),
              const SizedBox(height: 10),
              _MiniInfoRow(
                label: "Risk level",
                value: aiAnalysis['riskLevel'].toString(),
              ),
              _MiniInfoRow(
                label: "Suggested mix",
                value: aiAnalysis['allocation'].toString(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ProjectionChartCard(
          amount: (data['amount'] as num).toDouble(),
          months: data['months'] as int,
          safeRate: (safe['monthlyRate'] as num).toDouble(),
          balancedRate: (balanced['monthlyRate'] as num).toDouble(),
          aggressiveRate: (aggressive['monthlyRate'] as num).toDouble(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F5F7),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Kaya AI",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Hi ${widget.memberName} — your intelligent finance assistant for ${widget.chamaName}",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  InkWell(
                    onTap: _showQuickAskDialog,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.search, color: Colors.black54),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Ask Kaya about investments, savings or markets...",
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                          Icon(Icons.auto_awesome, color: Color(0xFF2E7D32)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.8,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _ActionCard(
                  icon: Icons.compare_arrows_rounded,
                  title: "Compare",
                  subtitle: "Project safe vs risky returns",
                  onTap: () {
                    _scrollToSection(_comparisonKey);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Enter amount and duration to compare"),
                      ),
                    );
                  },
                ),
                _ActionCard(
                  icon: Icons.show_chart_rounded,
                  title: "Market",
                  subtitle: "Track Bitcoin and Gold live",
                  onTap: () {
                    _scrollToSection(_marketKey);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Jumped to Market Watch")),
                    );
                  },
                ),
                _ActionCard(
                  icon: Icons.school_rounded,
                  title: "Learn",
                  subtitle: "Read simple finance guides",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => KayaLearningDetailScreen(
                          title: "What is a Money Market Fund?",
                          category: "Savings & Investments",
                          level: "Beginner",
                          keyPoints: [
                            "A money market fund pools money and invests in relatively low-risk short-term instruments.",
                            "It is usually considered more stable than stocks.",
                            "It may be easier to access than some fixed-term investments.",
                          ],
                          explanation:
                              "A Money Market Fund, often called an MMF, is a type of pooled investment designed to preserve capital while generating modest returns. It is popular among beginners and groups like chamas because it can provide a balance between safety, flexibility, and growth.",
                          tips: [
                            "Use an MMF when your chama wants moderate growth with lower risk.",
                            "Compare fees, withdrawal rules, and consistency before choosing one.",
                            "Review the provider carefully before investing.",
                          ],
                          sources: [
                            "Kaya Finance Learning Base",
                            "Provider fact sheets",
                          ],
                        ),
                      ),
                    );
                  },
                ),
                _ActionCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: "Ask Kaya",
                  subtitle: "Chat with your finance assistant",
                  onTap: () => _openKayaChat(),
                ),
              ],
            ),
          ),

          Padding(
            key: _marketKey,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const _SectionTitle(title: "Market Watch"),
          ),

          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _MarketWatchCard(),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _SectionTitle(title: "Chama Insights"),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildChamaInsightsCard(),
          ),
          const SizedBox(height: 14),
          Padding(
            key: _comparisonKey,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const _SectionTitle(title: "Investment Comparison"),
          ),

          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _WhiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Quick AI comparison",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    key: _amountFieldKey,
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Amount (KES)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Duration (months)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _riskProfile,
                    decoration: const InputDecoration(
                      labelText: "Risk preference",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shield_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Conservative',
                        child: Text('Conservative'),
                      ),
                      DropdownMenuItem(
                        value: 'Balanced',
                        child: Text('Balanced'),
                      ),
                      DropdownMenuItem(
                        value: 'Aggressive',
                        child: Text('Aggressive'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _riskProfile = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _runComparison,
                      icon: const Icon(Icons.auto_graph_rounded),
                      label: const Text("Compare with Kaya AI"),
                    ),
                  ),
                  _buildComparisonResults(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          Padding(
            key: _learningKey,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const _SectionTitle(title: "Learning Hub"),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _LearningHubCard(),
          ),

          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _SectionTitle(title: "Ask Kaya"),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ChatPreviewCard(
              onOpenChat: (initialQuestion) =>
                  _openKayaChat(initialQuestion: initialQuestion),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ProjectionChartCard extends StatelessWidget {
  final double amount;
  final int months;
  final double safeRate;
  final double balancedRate;
  final double aggressiveRate;

  const _ProjectionChartCard({
    required this.amount,
    required this.months,
    required this.safeRate,
    required this.balancedRate,
    required this.aggressiveRate,
  });

  List<FlSpot> _spots(double principal, double monthlyRate, int months) {
    final spots = <FlSpot>[];
    for (int i = 0; i <= months; i++) {
      final value = principal * (1 + (monthlyRate * i));
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }

  double _maxY() {
    final safeMax = amount * (1 + (safeRate * months));
    final balancedMax = amount * (1 + (balancedRate * months));
    final aggressiveMax = amount * (1 + (aggressiveRate * months));

    final maxValue = [
      safeMax,
      balancedMax,
      aggressiveMax,
    ].reduce((a, b) => a > b ? a : b);

    return maxValue * 1.1;
  }

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Projection chart",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            "Visual estimate of how each option may grow over time",
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: months.toDouble(),
                minY: 0,
                maxY: _maxY(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _maxY() / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.15),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text("Months"),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: months <= 6 ? 1 : (months / 6).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text("KES"),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: _maxY() / 5,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text("0");
                        return Text(
                          "${(value / 1000).toStringAsFixed(0)}k",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _spots(amount, safeRate, months),
                    isCurved: true,
                    barWidth: 3,
                    color: const Color(0xFF1B5E20), // Green
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF1B5E20).withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: _spots(amount, balancedRate, months),
                    isCurved: true,
                    barWidth: 3,
                    color: const Color(0xFF0D47A1), // Blue
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF0D47A1).withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: _spots(amount, aggressiveRate, months),
                    isCurved: true,
                    barWidth: 3,
                    color: const Color(0xFFE65100), // Orange
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFE65100).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _LegendChip(label: "Safe", color: Color(0xFF1B5E20)),
              _LegendChip(label: "Balanced", color: Color(0xFF0D47A1)),
              _LegendChip(label: "Aggressive", color: Color(0xFFE65100)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE8F5E9),
              child: Icon(icon, color: const Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.3,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            const Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    );
  }
}

class _MarketWatchCard extends StatefulWidget {
  const _MarketWatchCard();

  @override
  State<_MarketWatchCard> createState() => _MarketWatchCardState();
}

class _MarketWatchCardState extends State<_MarketWatchCard> {
  late Future<List<Map<String, dynamic>>> _marketFuture;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _marketFuture = MarketService.fetchMarketWatch();
    _lastUpdated = DateTime.now();
  }

  void _loadMarketData({bool forceRefresh = false}) {
    setState(() {
      _marketFuture = MarketService.fetchMarketWatch(
        forceRefresh: forceRefresh,
      );
      _lastUpdated = DateTime.now();
    });
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return "Not updated yet";

    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';

    return "$hour:$minute $period";
  }

  String? _symbolForAsset(String name) {
    switch (name) {
      case 'Bitcoin':
        return 'BTC/USD';
      case 'Gold':
        return 'XAU/USD';
      default:
        return null;
    }
  }

  void _openStaticDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const KayaMarketDetailScreen(
          assetName: "Treasury Bills",
          category: "Government Securities",
          price: "12.50%",
          change: "+0.40%",
          riskLevel: "Low",
          summary:
              "Treasury bills are short-term government securities commonly used for capital preservation and relatively stable returns. They are often attractive to conservative investors and chamas that prioritize safety over aggressive growth.",
          keyPoints: [
            "They are generally considered lower-risk than stocks.",
            "They are useful for short-term to medium-term capital allocation.",
            "Returns are usually steadier than more volatile assets.",
          ],
          useCases: [
            "When a chama wants to preserve capital while still earning a return.",
            "When the group has funds that should not be exposed to large price swings.",
            "When predictability matters more than aggressive upside.",
          ],
          notes: [
            "Lower risk often means lower return than high-growth assets.",
            "They may be less suitable when the main goal is aggressive long-term growth.",
          ],
          liveSymbol: null,
        ),
      ),
    );
  }

  void _openLiveDetail(
    BuildContext context, {
    required String name,
    required String price,
    required String assetType,
  }) {
    String category = "Market Asset";
    String riskLevel = "Moderate";
    String summary = "Live market asset being tracked by Kaya AI.";
    List<String> keyPoints = [];
    List<String> useCases = [];
    List<String> notes = [];

    switch (name) {
      case "Bitcoin":
        category = "Digital Asset";
        riskLevel = "High";
        summary =
            "Bitcoin is a digital asset known for high volatility and strong speculative interest. It can produce strong gains in some periods, but it also carries significant downside risk.";
        keyPoints = [
          "Bitcoin is more volatile than many traditional assets.",
          "It may offer high upside, but prices can swing sharply.",
          "It is usually better suited to investors who can tolerate risk.",
        ];
        useCases = [
          "For a small aggressive allocation, not for core chama capital.",
          "When the group clearly accepts large price movements.",
          "When diversification into digital assets is intentional and limited.",
        ];
        notes = [
          "Bitcoin is not suitable for every investor or every chama.",
          "It should rarely be the majority holding for group funds.",
        ];
        break;

      case "Gold":
        category = "Commodity";
        riskLevel = "Moderate";
        summary =
            "Gold is often used as a store of value and a diversification asset. It may behave differently from stocks during uncertainty, though it still rises and falls in price.";
        keyPoints = [
          "Gold is commonly used for diversification.",
          "It can behave differently from equities in uncertain periods.",
          "It does not always produce regular income like interest-bearing assets.",
        ];
        useCases = [
          "When reducing reliance on stock-only exposure.",
          "When diversification outside traditional assets is needed.",
          "When protecting purchasing power is part of the strategy.",
        ];
        notes = [
          "Gold prices can still be volatile.",
          "Gold is usually better as part of a wider portfolio, not the only holding.",
        ];
        break;

      default:
        category = assetType.toUpperCase();
        riskLevel = "Moderate";
        summary =
            "$name is being tracked live by Kaya AI for market awareness.";
        keyPoints = [
          "This asset is included in the live market watch list.",
          "Its price may move based on market conditions and sentiment.",
        ];
        useCases = ["For tracking broad market movement and awareness."];
        notes = [
          "Always compare live prices with your investment goal and time horizon.",
        ];
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KayaMarketDetailScreen(
          assetName: name,
          category: category,
          price: price,
          change: "Live",
          riskLevel: riskLevel,
          summary: summary,
          keyPoints: keyPoints,
          useCases: useCases,
          notes: notes,
          liveSymbol: _symbolForAsset(name),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _marketFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _WhiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Loading market data...",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: null,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _WhiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Failed to load live market data",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _loadMarketData(forceRefresh: true),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 8),
                Text(
                  "Last updated: ${_formatTime(_lastUpdated)}",
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final liveItems = snapshot.data ?? [];

        return _WhiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Live snapshot",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _loadMarketData(forceRefresh: true),
                    icon: const Icon(Icons.refresh),
                    tooltip: "Refresh market data",
                  ),
                ],
              ),
              Text(
                "Last updated: ${_formatTime(_lastUpdated)}",
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              _StaticMarketRow(
                name: "Treasury Bills",
                price: "12.50%",
                note: "Curated reference",
                onTap: () => _openStaticDetail(context),
              ),
              if (liveItems.isNotEmpty) const Divider(),
              ...liveItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;

                return Column(
                  children: [
                    _LiveMarketRow(
                      name:
                          item['label']?.toString() ??
                          item['symbol'].toString(),
                      price: item['price']?.toString() ?? 'N/A',
                      assetType: item['assetType']?.toString() ?? 'market',
                      onTap: () => _openLiveDetail(
                        context,
                        name:
                            item['label']?.toString() ??
                            item['symbol'].toString(),
                        price: item['price']?.toString() ?? 'N/A',
                        assetType: item['assetType']?.toString() ?? 'market',
                      ),
                    ),
                    if (i != liveItems.length - 1) const Divider(),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _StaticMarketRow extends StatelessWidget {
  final String name;
  final String price;
  final String note;
  final VoidCallback onTap;

  const _StaticMarketRow({
    required this.name,
    required this.price,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(price, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Text(
              note,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

class _LiveMarketRow extends StatelessWidget {
  final String name;
  final String price;
  final String assetType;
  final VoidCallback onTap;

  const _LiveMarketRow({
    required this.name,
    required this.price,
    required this.assetType,
    required this.onTap,
  });

  String _formatPrice() {
    if (price == 'N/A') return price;

    if (name == 'USD/KES') return price;

    switch (assetType) {
      case 'crypto':
      case 'commodity':
      case 'stock':
        return '\$$price';
      default:
        return price;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              _formatPrice(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                assetType.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final String finalValue;
  final String profit;
  final String risk;
  final String liquidity;
  final Color bg;
  final Color color;

  const _RecommendationCard({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.finalValue,
    required this.profit,
    required this.risk,
    required this.liquidity,
    required this.bg,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          _MiniInfoRow(label: "Projected value", value: finalValue),
          _MiniInfoRow(label: "Estimated profit", value: profit),
          _MiniInfoRow(label: "Risk", value: risk),
          _MiniInfoRow(label: "Liquidity", value: liquidity),
        ],
      ),
    );
  }
}

class _MiniInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningHubCard extends StatelessWidget {
  const _LearningHubCard();

  void _openLesson(
    BuildContext context, {
    required String title,
    required String category,
    required String level,
    required List<String> keyPoints,
    required String explanation,
    required List<String> tips,
    required List<String> sources,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KayaLearningDetailScreen(
          title: title,
          category: category,
          level: level,
          keyPoints: keyPoints,
          explanation: explanation,
          tips: tips,
          sources: sources,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        children: [
          _LearnItem(
            title: "What is a Money Market Fund?",
            onTap: () => _openLesson(
              context,
              title: "What is a Money Market Fund?",
              category: "Savings & Investments",
              level: "Beginner",
              keyPoints: [
                "A money market fund pools money and invests in relatively low-risk short-term instruments.",
                "It is usually considered more stable than stocks.",
                "It may be easier to access than some fixed-term investments.",
              ],
              explanation:
                  "A Money Market Fund, often called an MMF, is a type of pooled investment designed to preserve capital while generating modest returns. It is popular among beginners and groups like chamas because it can provide a balance between safety, flexibility, and growth. While it does not usually deliver the highest returns, it can be a strong choice for funds that may need to remain relatively accessible.",
              tips: [
                "Use an MMF when your chama wants moderate growth with lower risk.",
                "Compare fees, withdrawal rules, and historical consistency before choosing one.",
                "Do not assume every MMF performs the same — review the provider carefully.",
              ],
              sources: [
                "Kaya Finance Learning Base",
                "Provider fact sheets",
                "General money market education resources",
              ],
            ),
          ),
          const Divider(),
          _LearnItem(
            title: "How Treasury Bills Work",
            onTap: () => _openLesson(
              context,
              title: "How Treasury Bills Work",
              category: "Government Securities",
              level: "Beginner",
              keyPoints: [
                "Treasury bills are short-term government securities.",
                "They are often viewed as lower-risk compared to stocks.",
                "They are commonly used for capital preservation and predictable returns.",
              ],
              explanation:
                  "Treasury bills are short-term investments issued by the government. When you invest in a treasury bill, you are effectively lending money to the government for a specific period. In return, you earn a return at maturity. They are attractive to conservative investors and groups that want safety and structure, especially when protecting capital is more important than chasing aggressive profits.",
              tips: [
                "Treasury bills are useful when safety matters more than high returns.",
                "Check the investment term so it matches your group’s cash-flow needs.",
                "Use treasury bills as part of a diversified strategy, not always as the only option.",
              ],
              sources: [
                "Kaya Finance Learning Base",
                "Central Bank educational material",
              ],
            ),
          ),
          const Divider(),
          _LearnItem(
            title: "Stocks for Beginners",
            onTap: () => _openLesson(
              context,
              title: "Stocks for Beginners",
              category: "Equities",
              level: "Beginner",
              keyPoints: [
                "Stocks represent ownership in a company.",
                "They can grow strongly over time but also fluctuate more.",
                "They are better suited to longer-term and higher-risk investing.",
              ],
              explanation:
                  "When you buy a stock, you are buying a small ownership share in a company. If the company grows and becomes more valuable, your investment can rise. Some companies may also pay dividends. However, stocks can move up and down sharply, so they are not usually the best place for money that must remain stable in the short term.",
              tips: [
                "Do not put all your chama funds into stocks unless the group clearly accepts the risk.",
                "Diversify instead of betting on one company.",
                "Stocks usually make more sense over a longer horizon than a very short one.",
              ],
              sources: [
                "Kaya Finance Learning Base",
                "Basic equity investing education resources",
              ],
            ),
          ),
          const Divider(),
          _LearnItem(
            title: "How Chamas Can Invest Safely",
            onTap: () => _openLesson(
              context,
              title: "How Chamas Can Invest Safely",
              category: "Chama Strategy",
              level: "Practical",
              keyPoints: [
                "A chama should define goals, risk level, and time horizon first.",
                "Diversification reduces concentration risk.",
                "Safer investments may bring lower returns, but they help protect group capital.",
              ],
              explanation:
                  "For a chama, investing safely starts with clarity. The group should know why the money is being invested, when it may be needed, and how much risk members are willing to accept. A safer strategy usually blends capital-preservation instruments with some moderate-growth options, instead of putting all the money into a single aggressive asset. Good governance and member understanding are also important parts of investing safely.",
              tips: [
                "Agree as a group on goals before choosing an investment.",
                "Keep some money liquid for emergencies or short-term needs.",
                "Avoid putting all funds into high-risk assets just because returns look attractive.",
              ],
              sources: [
                "Kaya Finance Learning Base",
                "General savings and investment planning resources",
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _LearnItem({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE8F5E9),
        child: Icon(Icons.menu_book_rounded, color: Color(0xFF2E7D32)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _ChatPreviewCard extends StatelessWidget {
  final void Function(String? initialQuestion) onOpenChat;

  const _ChatPreviewCard({required this.onOpenChat});

  @override
  Widget build(BuildContext context) {
    final questions = const [
      "What is a treasury bill?",
      "How can our chama invest 100k?",
      "MMF vs stocks",
      "Explain bonds simply",
    ];

    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Suggested questions",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: questions.map((q) {
              return InkWell(
                onTap: () => onOpenChat(q),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    q,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onOpenChat(null),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text("Open Kaya Chat"),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionChip extends StatelessWidget {
  final String text;

  const _QuestionChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;

  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: child,
    );
  }
}
