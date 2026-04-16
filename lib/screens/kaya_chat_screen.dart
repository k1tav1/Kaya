import 'package:flutter/material.dart';
import '../services/kaya_ai_service.dart';
import '../services/kaya_chama_ai_service.dart';
import '../services/supabase_service.dart';

class KayaChatScreen extends StatefulWidget {
  final String memberName;
  final String chamaName;
  final String chamaId;
  final String? initialQuestion;

  const KayaChatScreen({
    super.key,
    required this.memberName,
    required this.chamaName,
    required this.chamaId,
    this.initialQuestion,
  });

  @override
  State<KayaChatScreen> createState() => _KayaChatScreenState();
}

class _KayaChatScreenState extends State<KayaChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  final List<String> _suggestedQuestions = const [
    "What is a treasury bill?",
    "How can our chama invest 100k?",
    "MMF vs stocks",
    "Recommend an aggressive investment for 200k over 2 months",
    "Explain bonds simply",
    "Are we on track for our chama goal?",
    "How much has my chama saved so far?",
    "What monthly amount do we need to hit our target?",
    "What is Kaya?",
    "How do I invest safely?",
  ];

  @override
  void initState() {
    super.initState();

    _messages.add(
      _assistantReply(
        title: "Hello ${widget.memberName}, I’m Kaya 👋",
        text:
            "I can help you understand savings, investments, risk, treasury bills, bonds, money market funds, stocks, budgeting, inflation, and financial literacy in simple language.",
        related: const [
          "What is a money market fund?",
          "How can our chama invest safely?",
          "Explain treasury bills simply",
        ],
        sources: const ["Kaya Finance Learning Base"],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuestion != null &&
          widget.initialQuestion!.trim().isNotEmpty) {
        _sendMessage(widget.initialQuestion);
      }
    });
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<String?> _generateChamaDataReply(String rawInput) async {
    final input = rawInput.toLowerCase();

    final wantsChamaInsight =
        input.contains('my chama') ||
        input.contains('our chama') ||
        input.contains('goal progress') ||
        input.contains('how are we doing') ||
        input.contains('are we on track') ||
        input.contains('saved so far') ||
        input.contains('monthly need') ||
        input.contains('monthly amount') ||
        input.contains('hit our target') ||
        input.contains('reach our target') ||
        input.contains('what do we need per month') ||
        input.contains('how much do we need per month') ||
        input.contains('per month');

    if (!wantsChamaInsight) return null;

    final summary = await SupabaseService.getChamaFinanceSummary(
      chamaId: widget.chamaId,
    );

    final targetAmount = (summary['targetAmount'] as num?)?.toDouble() ?? 0.0;
    final currentSaved = (summary['currentSaved'] as num?)?.toDouble() ?? 0.0;
    final targetMonths = (summary['targetMonths'] as num?)?.toInt() ?? 0;

    if (targetAmount <= 0 || targetMonths <= 0) {
      return "I could not find a complete finance goal for your chama yet. Please create a finance goal first so I can analyze your progress.";
    }

    final analysis = KayaChamaAIService.analyzeGoalProgress(
      targetAmount: targetAmount,
      currentAmount: currentSaved,
      targetMonths: targetMonths,
    );

    final progressPercent = (analysis['progressPercent'] as num)
        .toStringAsFixed(1);
    final remainingAmount = (analysis['remainingAmount'] as num)
        .toStringAsFixed(2);
    final requiredMonthly = (analysis['requiredMonthly'] as num)
        .toStringAsFixed(2);
    final status = analysis['status'].toString();
    final advice = analysis['advice'].toString();

    if (input.contains('monthly amount') ||
        input.contains('monthly need') ||
        input.contains('hit our target') ||
        input.contains('reach our target') ||
        input.contains('what do we need per month') ||
        input.contains('how much do we need per month') ||
        input.contains('per month')) {
      return "To hit your chama target, you currently need about KES $requiredMonthly per month.\n\n"
          "Current saved: KES ${currentSaved.toStringAsFixed(2)}\n"
          "Target: KES ${targetAmount.toStringAsFixed(2)}\n"
          "Still needed: KES $remainingAmount\n"
          "Status: $status\n\n"
          "$advice";
    }

    if (input.contains('saved so far')) {
      return "Your chama has currently saved KES ${currentSaved.toStringAsFixed(2)} out of KES ${targetAmount.toStringAsFixed(2)}.\n\n"
          "Progress: $progressPercent%\n"
          "Still needed: KES $remainingAmount\n"
          "Status: $status";
    }

    if (input.contains('are we on track') ||
        input.contains('goal progress') ||
        input.contains('how are we doing')) {
      return "Your chama is currently at $progressPercent% progress toward the goal.\n\n"
          "Current saved: KES ${currentSaved.toStringAsFixed(2)}\n"
          "Target: KES ${targetAmount.toStringAsFixed(2)}\n"
          "Still needed: KES $remainingAmount\n"
          "Required monthly pace: KES $requiredMonthly\n"
          "Status: $status\n\n"
          "$advice";
    }

    return "Your chama has currently saved KES ${currentSaved.toStringAsFixed(2)} out of KES ${targetAmount.toStringAsFixed(2)}.\n\n"
        "Progress: $progressPercent%\n"
        "Still needed: KES $remainingAmount\n"
        "Required monthly pace: KES $requiredMonthly\n"
        "Status: $status\n\n"
        "$advice";
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _messageCtrl.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isTyping = true;
    });

    _messageCtrl.clear();
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 700));

    Map<String, dynamic> reply;

    final chamaReply = await _generateChamaDataReply(text);
    if (chamaReply != null) {
      reply = _assistantReply(
        title: "Monthly Target Analysis for Your Chama",
        text: chamaReply,
        related: const [
          "Are we on track for our chama goal?",
          "How much has my chama saved so far?",
          "What monthly amount do we need to hit our target?",
        ],
        sources: const ["Kaya Chama Finance Data"],
      );
    } else {
      reply = _generateReply(text);
    }

    if (!mounted) return;

    setState(() {
      _messages.add(reply);
      _isTyping = false;
    });

    _scrollToBottom();
  }

  double? _extractAmount(String input) {
    final regex = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(k|kes|thousand)?',
      caseSensitive: false,
    );
    final match = regex.firstMatch(input);

    if (match == null) return null;

    final rawNumber = match.group(1)?.replaceAll(',', '');
    final unit = match.group(2)?.toLowerCase();

    final value = double.tryParse(rawNumber ?? '');
    if (value == null) return null;

    if (unit == 'k' || unit == 'thousand') {
      return value * 1000;
    }

    return value;
  }

  int? _extractMonths(String input) {
    final monthRegex = RegExp(r'(\d+)\s*(month|months)', caseSensitive: false);
    final yearRegex = RegExp(r'(\d+)\s*(year|years)', caseSensitive: false);

    final monthMatch = monthRegex.firstMatch(input);
    if (monthMatch != null) {
      return int.tryParse(monthMatch.group(1) ?? '');
    }

    final yearMatch = yearRegex.firstMatch(input);
    if (yearMatch != null) {
      final years = int.tryParse(yearMatch.group(1) ?? '');
      if (years != null) return years * 12;
    }

    return null;
  }

  String _extractRiskProfile(String input) {
    final text = input.toLowerCase();

    if (text.contains('conservative') ||
        text.contains('safe') ||
        text.contains('low risk')) {
      return 'Conservative';
    }

    if (text.contains('aggressive') ||
        text.contains('high risk') ||
        text.contains('risky')) {
      return 'Aggressive';
    }

    return 'Balanced';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Map<String, dynamic> _assistantReply({
    required String title,
    required String text,
    List<String> related = const [],
    List<String> sources = const [],
  }) {
    return {
      "role": "assistant",
      "type": "rich",
      "title": title,
      "text": text,
      "related": related,
      "sources": sources,
    };
  }

  Map<String, dynamic> _generateReply(String rawInput) {
    final input = rawInput.toLowerCase();

    final detectedAmount = _extractAmount(rawInput);
    final detectedMonths = _extractMonths(rawInput);
    final detectedRisk = _extractRiskProfile(rawInput);

    final asksForInvestmentAdvice =
        input.contains('invest') ||
        input.contains('investment') ||
        input.contains('100k') ||
        input.contains('100,000') ||
        input.contains('compare') ||
        input.contains('recommend');

    if (asksForInvestmentAdvice && detectedAmount != null) {
      final months = detectedMonths ?? 12;

      final result = KayaAIService.analyzeInvestment(
        amount: detectedAmount,
        months: months,
        riskProfile: detectedRisk,
      );

      return _assistantReply(
        title: "Kaya AI Investment Recommendation",
        text:
            "Based on your input, Kaya recommends ${result['recommendation']}.\n\n"
            "Reason: ${result['reason']}\n"
            "Risk level: ${result['riskLevel']}\n"
            "Suggested mix: ${result['allocation']}\n\n"
            "Projected outcomes over $months month(s):\n"
            "• Safe option: KES ${(result['safeReturn'] as num).toStringAsFixed(2)}\n"
            "• Balanced option: KES ${(result['balancedReturn'] as num).toStringAsFixed(2)}\n"
            "• Aggressive option: KES ${(result['aggressiveReturn'] as num).toStringAsFixed(2)}\n\n"
            "These are educational estimates, not guaranteed returns.",
        related: const [
          "How do I invest safely?",
          "MMF vs stocks",
          "What is risk in investing?",
        ],
        sources: const ["Kaya AI Recommendation Engine"],
      );
    }

    if (input.contains("what is kaya") ||
        (input.contains("kaya") && input.contains("what"))) {
      return _assistantReply(
        title: "What Kaya is",
        text:
            "Kaya is a chama management and financial intelligence platform. It helps groups manage meetings, contributions, goals, loans, and also gives financial education, investment comparisons, and AI-powered support. The goal is to make group finance easier, smarter, and more understandable for every member.",
        related: const [
          "How can our chama invest safely?",
          "What is financial literacy?",
          "How does Kaya AI help?",
        ],
        sources: const ["Kaya Product Knowledge Base"],
      );
    }

    if (input.contains("treasury bill") || input.contains("t-bill")) {
      return _assistantReply(
        title: "Treasury Bills Explained",
        text:
            "A treasury bill is a short-term government investment. You lend money to the government for a fixed period, and when it matures, you earn a return. Treasury bills are generally considered lower-risk than stocks, so they can be suitable for conservative investors and chamas that want capital preservation more than aggressive growth.",
        related: const [
          "Treasury bills vs bonds",
          "How can our chama invest safely?",
          "What is risk in investing?",
        ],
        sources: const [
          "Central Bank learning sources",
          "Kaya Finance Learning Base",
        ],
      );
    }

    if (input.contains("bond")) {
      return _assistantReply(
        title: "Bonds in Simple Terms",
        text:
            "A bond is like a longer-term loan to a government or company. In return, the borrower pays interest over time. Bonds are often more stable than stocks, but their returns may be lower than high-growth investments. They can be useful when you want steadier income and lower volatility over time.",
        related: const [
          "Treasury bills vs bonds",
          "What is risk in investing?",
          "How do I invest safely?",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    if (input.contains("mmf") || input.contains("money market")) {
      return _assistantReply(
        title: "Money Market Fund (MMF)",
        text:
            "A Money Market Fund is a pooled investment vehicle that places money in relatively low-risk, short-term instruments. It is popular because it is usually easier to access than some fixed investments, more stable than stocks, and can suit chamas that want moderate growth with flexibility and liquidity.",
        related: const [
          "MMF vs stocks",
          "How can our chama invest safely?",
          "What is liquidity?",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    if (input.contains("stock") || input.contains("shares")) {
      return _assistantReply(
        title: "Stocks Explained",
        text:
            "Stocks represent ownership in a company. They can generate strong returns over time, but their prices can rise and fall more sharply than safer instruments like treasury bills or money market funds. Stocks are more suitable for investors who can tolerate volatility and stay invested for longer periods.",
        related: const [
          "MMF vs stocks",
          "What is diversification?",
          "What is risk in investing?",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    if (input.contains("100k") ||
        input.contains("100,000") ||
        ((input.contains("invest") || input.contains("investment")) &&
            input.contains("chama"))) {
      return _assistantReply(
        title: "How a Chama Can Invest KES 100,000",
        text:
            "For a chama investing KES 100,000, a balanced approach is usually stronger than putting everything in one place.\n\nA simple example:\n• 40% in treasury bills for safety\n• 40% in a money market fund for flexibility\n• 20% in diversified stocks or an ETF for growth\n\nThis approach helps protect part of the money while still giving some room for growth.",
        related: const [
          "How do I invest safely?",
          "What is diversification?",
          "MMF vs stocks",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    if (input.contains("safe") || input.contains("safest")) {
      return _assistantReply(
        title: "Safest Investment Options",
        text:
            "The safest investment options are usually government-backed or low-volatility instruments such as treasury bills, treasury bonds, or money market funds. These generally offer lower returns than aggressive assets, but they are more suitable when capital protection matters most.",
        related: const [
          "What is risk in investing?",
          "How can our chama invest 100k?",
          "What is a treasury bill?",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    if (input.contains("risk")) {
      return _assistantReply(
        title: "Understanding Investment Risk",
        text:
            "In investing, risk means the chance that the value of your money may go down, grow slowly, or become difficult to access when needed. Lower-risk investments usually give smaller but steadier returns, while higher-risk investments may give better profits but can also lose value faster.",
        related: const [
          "What is diversification?",
          "How do I invest safely?",
          "MMF vs stocks",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    if (input.contains("financial literacy") ||
        input.contains("learn finance")) {
      return _assistantReply(
        title: "Financial Literacy",
        text:
            "Financial literacy means understanding how money works — including saving, budgeting, borrowing, investing, and managing risk. For a chama, financial literacy helps members make better group decisions, reduce mistakes, and choose stronger financial opportunities.",
        related: const [
          "What is budgeting?",
          "What is inflation?",
          "How do I invest safely?",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    if (input.contains("invest safely")) {
      return _assistantReply(
        title: "How to Invest Safely",
        text:
            "To invest safely, start by defining your goal, time horizon, and risk level. Avoid putting all the money in one place. Keep an emergency reserve, favor diversified and lower-risk instruments first, and allocate only a smaller portion to aggressive assets if the group can tolerate fluctuations.",
        related: const [
          "What is diversification?",
          "How can our chama invest 100k?",
          "What is risk in investing?",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    if (input.contains("diversification") || input.contains("diversify")) {
      return _assistantReply(
        title: "Diversification",
        text:
            "Diversification means spreading money across different investments instead of putting everything in one place. The idea is to reduce the damage if one investment performs poorly. For example, a chama can combine treasury bills, money market funds, and selected growth assets instead of relying on only one option.",
        related: const [
          "How do I invest safely?",
          "MMF vs stocks",
          "How can our chama invest 100k?",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    if (input.contains("inflation")) {
      return _assistantReply(
        title: "What Inflation Means",
        text:
            "Inflation means the general increase in prices over time. When inflation rises, the same amount of money buys fewer goods and services than before. That is why saving alone may not be enough over long periods — some money may need to be invested so it has a chance to grow faster than inflation.",
        related: const [
          "Why should we invest?",
          "What is financial literacy?",
          "How do I invest safely?",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    if (input.contains("budget") || input.contains("budgeting")) {
      return _assistantReply(
        title: "Budgeting Basics",
        text:
            "Budgeting means planning how money will be used before it is spent. A good budget helps a chama control contributions, track expenses, set goals, and avoid confusion. In simple terms, it helps you decide what to save, what to spend, and what to invest.",
        related: const [
          "What is financial literacy?",
          "How do I invest safely?",
          "Why should our chama save?",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    if (input.contains("compound") || input.contains("compound interest")) {
      return _assistantReply(
        title: "Compound Interest",
        text:
            "Compound interest means your money earns returns, and then those returns also begin earning returns. Over time, this can make growth much stronger than simple interest. The earlier you start and the longer you stay invested, the more powerful compounding becomes.",
        related: const [
          "Why should we invest early?",
          "MMF vs stocks",
          "How do I invest safely?",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    if (input.contains("liquidity")) {
      return _assistantReply(
        title: "Liquidity",
        text:
            "Liquidity means how quickly and easily you can access your money without losing much value. Highly liquid investments are easier to convert into cash quickly. This matters for chamas because some money may be needed for emergencies, meetings, or short-term goals.",
        related: const [
          "MMF vs stocks",
          "How do I invest safely?",
          "What is risk in investing?",
        ],
        sources: const ["Kaya Finance Learning Base"],
      );
    }

    return _assistantReply(
      title: "Let’s explore that together",
      text:
          "That’s a good question. For now, I can best help with savings, treasury bills, bonds, money market funds, stocks, budgeting, inflation, diversification, compound interest, risk, and chama investment planning in simple language.\n\nLater, I can also support live research-backed answers and real market insights.",
      related: const [
        "What is a treasury bill?",
        "MMF vs stocks",
        "How do I invest safely?",
      ],
      sources: const ["Kaya Finance Learning Base"],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text(
          "Kaya Chat",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ask Kaya about savings, investments and financial literacy",
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestedQuestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final q = _suggestedQuestions[index];
                      return InkWell(
                        onTap: () => _sendMessage(q),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            q,
                            style: const TextStyle(
                              color: Color(0xFF1B5E20),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return const _TypingBubble();
                }

                final msg = _messages[index];
                final isUser = msg["role"] == "user";

                if (isUser) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        msg["text"].toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.45,
                        ),
                      ),
                    ),
                  );
                }

                return _AssistantMessageCard(
                  title: (msg["title"] ?? "Kaya").toString(),
                  text: (msg["text"] ?? "").toString(),
                  related: List<String>.from(msg["related"] ?? const []),
                  sources: List<String>.from(msg["sources"] ?? const []),
                  onRelatedTap: _sendMessage,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Type your question...",
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF2E7D32),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantMessageCard extends StatelessWidget {
  final String title;
  final String text;
  final List<String> related;
  final List<String> sources;
  final Future<void> Function(String question) onRelatedTap;

  const _AssistantMessageCard({
    required this.title,
    required this.text,
    required this.related,
    required this.sources,
    required this.onRelatedTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.90,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.black87, height: 1.5),
          ),
          if (related.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              "Related questions",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: related.map((q) {
                return InkWell(
                  onTap: () => onRelatedTap(q),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      q,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              "Sources",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            ...sources.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "• $s",
                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
          ],
        ),
        child: const Text(
          "Kaya is typing...",
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}
