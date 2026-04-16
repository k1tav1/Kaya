import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/supabase_service.dart';
import '../services/theme_controller.dart';
import 'finance_screen.dart';
import 'kaya_ai_screen.dart';
import 'meetings_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String chamaId;
  final String memberName;
  final String memberRole;
  final String memberPhone;
  final String memberId;

  const HomeScreen({
    super.key,
    required this.chamaId,
    required this.memberName,
    required this.memberRole,
    required this.memberPhone,
    required this.memberId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> _chamaFuture;
  late Future<List<Map<String, dynamic>>> _membersFuture;
  late Future<Map<String, dynamic>> _financeSummaryFuture;

  int _selectedIndex = 0;

  bool get isChairperson => widget.memberRole.toLowerCase() == "chairperson";

  @override
  void initState() {
    super.initState();
    _reload();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ThemeController>(
        context,
        listen: false,
      ).loadTheme(widget.memberId);
    });
  }

  void _reload() {
    _chamaFuture = SupabaseService.getChamaById(widget.chamaId);
    _membersFuture = SupabaseService.getMembersByChama(widget.chamaId);
    _financeSummaryFuture = SupabaseService.getChamaFinanceSummary(
      chamaId: widget.chamaId,
    );
    setState(() {});
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openFinancePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinanceScreen(
          chamaId: widget.chamaId,
          currentMemberRole: widget.memberRole,
          currentMemberId: widget.memberId,
        ),
      ),
    );
    _reload();
  }

  Future<void> _openMeetingsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingsScreen(
          chamaId: widget.chamaId,
          memberId: widget.memberId,
          memberName: widget.memberName,
          memberRole: widget.memberRole,
        ),
      ),
    );
    _reload();
  }

  Future<void> _openSettingsPage([String? chamaName]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          memberId: widget.memberId,
          chamaId: widget.chamaId,
          memberName: widget.memberName,
          memberRole: widget.memberRole,
          chamaName: chamaName ?? "Chama",
        ),
      ),
    );
    _reload();
  }

  Future<void> _openProfilePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          memberId: widget.memberId,
          memberName: widget.memberName,
          memberRole: widget.memberRole,
          memberPhone: widget.memberPhone,
          chamaId: widget.chamaId,
        ),
      ),
    );
    _reload();
  }

  Future<void> _editChamaOverview(Map<String, dynamic> chama) async {
    if (!isChairperson) {
      _snack("Only the Chairperson can do this action.");
      return;
    }

    final nameCtrl = TextEditingController(
      text: (chama['name'] ?? '').toString(),
    );
    final purposeCtrl = TextEditingController(
      text: (chama['purpose'] ?? '').toString(),
    );
    final paymentModeCtrl = TextEditingController(
      text: (chama['payment_mode'] ?? '').toString(),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Chama Overview"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Chama name"),
            ),
            TextField(
              controller: purposeCtrl,
              decoration: const InputDecoration(labelText: "Purpose"),
            ),
            TextField(
              controller: paymentModeCtrl,
              decoration: const InputDecoration(labelText: "Payment mode"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (saved != true) return;

    await SupabaseService.updateChama(
      chamaId: widget.chamaId,
      updates: {
        'name': nameCtrl.text.trim(),
        'purpose': purposeCtrl.text.trim(),
        'payment_mode': paymentModeCtrl.text.trim(),
      },
    );

    _snack("Chama updated successfully ✅");
    _reload();
  }

  Future<void> _editRules(Map<String, dynamic> chama) async {
    if (!isChairperson) {
      _snack("Only the Chairperson can do this action.");
      return;
    }

    final rulesCtrl = TextEditingController(
      text: (chama['rules'] ?? '').toString(),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Rules"),
        content: TextField(
          controller: rulesCtrl,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: "Rules",
            hintText: "Write your chama rules here...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (saved != true) return;

    await SupabaseService.updateChama(
      chamaId: widget.chamaId,
      updates: {'rules': rulesCtrl.text.trim()},
    );

    _snack("Rules updated successfully ✅");
    _reload();
  }

  String _money(num value) => "KES ${value.toStringAsFixed(0)}";

  Widget _buildHomeTab() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _TopBar(
                name: widget.memberName,
                role: widget.memberRole,
                onProfileTap: _openProfilePage,
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4F5F7),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        FutureBuilder<Map<String, dynamic>>(
                          future:
                              Future.wait([
                                _chamaFuture,
                                _membersFuture,
                                _financeSummaryFuture,
                              ]).then(
                                (value) => {
                                  'chama': value[0] as Map<String, dynamic>,
                                  'members':
                                      value[1] as List<Map<String, dynamic>>,
                                  'finance': value[2] as Map<String, dynamic>,
                                },
                              ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const _LoadingCard(height: 220);
                            }

                            if (snapshot.hasError) {
                              return _ErrorCard(
                                title: "Failed to load dashboard",
                                message: "${snapshot.error}",
                                onRetry: _reload,
                              );
                            }

                            final data = snapshot.data ?? {};
                            final chama =
                                data['chama'] as Map<String, dynamic>? ??
                                <String, dynamic>{};
                            final members =
                                data['members']
                                    as List<Map<String, dynamic>>? ??
                                <Map<String, dynamic>>[];
                            final finance =
                                data['finance'] as Map<String, dynamic>? ??
                                <String, dynamic>{};

                            final chamaName = (chama["name"] ?? "Your Chama")
                                .toString();
                            final purpose =
                                (chama["purpose"] ?? "Purpose not set yet")
                                    .toString();
                            final paymentMode =
                                (chama["payment_mode"] ?? "Not set").toString();
                            final rules =
                                (chama["rules"] ??
                                        "Rules will appear here. Example: Contributions are due every Friday. Late payments attract a penalty. Meeting attendance is mandatory unless excused.")
                                    .toString();

                            final targetAmount =
                                (finance['targetAmount'] as num?)?.toDouble() ??
                                0.0;
                            final currentSaved =
                                (finance['currentSaved'] as num?)?.toDouble() ??
                                0.0;
                            final targetMonths =
                                (finance['targetMonths'] as num?)?.toInt() ?? 0;
                            final remaining = (targetAmount - currentSaved) < 0
                                ? 0.0
                                : (targetAmount - currentSaved);
                            final progress = targetAmount > 0
                                ? (currentSaved / targetAmount).clamp(0.0, 1.0)
                                : 0.0;

                            String statusText;
                            Color statusColor;

                            if (progress >= 0.75) {
                              statusText = "On track";
                              statusColor = const Color(0xFF1B5E20);
                            } else if (progress >= 0.35) {
                              statusText = "Moderate progress";
                              statusColor = const Color(0xFFE65100);
                            } else {
                              statusText = "Needs attention";
                              statusColor = Colors.red;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle(
                                  title: "Welcome to $chamaName",
                                  subtitle:
                                      "A smarter overview of your chama at a glance",
                                ),
                                const SizedBox(height: 12),

                                _HeroDashboardCard(
                                  chamaName: chamaName,
                                  role: widget.memberRole,
                                  savedAmount: _money(currentSaved),
                                  targetAmount: _money(targetAmount),
                                  progress: progress,
                                  statusText: statusText,
                                  statusColor: statusColor,
                                  onOpenFinance: _openFinancePage,
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _MiniStatCard(
                                        title: "Members",
                                        value: members.length.toString(),
                                        icon: Icons.groups_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MiniStatCard(
                                        title: "Duration",
                                        value: targetMonths > 0
                                            ? "$targetMonths mo"
                                            : "Not set",
                                        icon: Icons.schedule_rounded,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _MiniStatCard(
                                        title: "Remaining",
                                        value: _money(remaining),
                                        icon: Icons.trending_up_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MiniStatCard(
                                        title: "Payment mode",
                                        value: paymentMode,
                                        icon: Icons.payments_rounded,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                _InfoCard(
                                  title: "Chama Overview",
                                  trailing: isChairperson
                                      ? TextButton(
                                          onPressed: () =>
                                              _editChamaOverview(chama),
                                          child: const Text("Edit"),
                                        )
                                      : null,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _InfoRow(
                                        label: "Purpose",
                                        value: purpose,
                                      ),
                                      const SizedBox(height: 10),
                                      _InfoRow(
                                        label: "Role",
                                        value: widget.memberRole,
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                _InfoCard(
                                  title: "Finance Snapshot",
                                  trailing: TextButton(
                                    onPressed: _openFinancePage,
                                    child: const Text("Open Finance"),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _InfoRow(
                                        label: "Saved",
                                        value: _money(currentSaved),
                                      ),
                                      const SizedBox(height: 10),
                                      _InfoRow(
                                        label: "Target",
                                        value: _money(targetAmount),
                                      ),
                                      const SizedBox(height: 10),
                                      _InfoRow(
                                        label: "Remaining",
                                        value: _money(remaining),
                                      ),
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 10,
                                          backgroundColor: Colors.black12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "${(progress * 100).round()}% completed",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                _InsightCard(
                                  title: "Kaya Insight",
                                  message: targetAmount <= 0
                                      ? "You have not created a finance goal yet. Add one in Finance so Kaya can track your progress."
                                      : progress >= 0.75
                                      ? "Your chama is making strong progress. Staying consistent may be more important than taking extra risk right now."
                                      : progress >= 0.35
                                      ? "Your chama is progressing, but you still need ${_money(remaining)} to hit the goal. Keep contributions steady."
                                      : "Your chama is still early in the journey. You may need higher monthly contributions or a clearer savings plan.",
                                  actionLabel: "Ask Kaya AI",
                                  onTap: () =>
                                      setState(() => _selectedIndex = 3),
                                ),

                                const SizedBox(height: 12),

                                _InfoCard(
                                  title: "Members (${members.length})",
                                  trailing: TextButton(
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        showDragHandle: true,
                                        builder: (_) =>
                                            _MembersSheet(members: members),
                                      );
                                    },
                                    child: const Text("View All"),
                                  ),
                                  child: Column(
                                    children: members.take(4).map((m) {
                                      final name = (m["name"] ?? "Member")
                                          .toString();
                                      final phone = (m["phone"] ?? "")
                                          .toString();
                                      final role = (m["role"] ?? "Member")
                                          .toString();

                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          backgroundColor: const Color(
                                            0xFFC8E6C9,
                                          ),
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : "M",
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(phone),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            role,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                _InfoCard(
                                  title: "Rules",
                                  trailing: isChairperson
                                      ? TextButton(
                                          onPressed: () => _editRules(chama),
                                          child: const Text("Edit"),
                                        )
                                      : null,
                                  child: _ExpandableText(text: rules),
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _DashboardActionButton(
                                        icon: Icons.account_balance_wallet,
                                        label: "Finance",
                                        onTap: _openFinancePage,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _DashboardActionButton(
                                        icon: Icons.event_note_rounded,
                                        label: "Meetings",
                                        onTap: _openMeetingsPage,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _DashboardActionButton(
                                        icon: Icons.auto_awesome_rounded,
                                        label: "Kaya AI",
                                        onTap: () =>
                                            setState(() => _selectedIndex = 3),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _DashboardActionButton(
                                        icon: Icons.settings_rounded,
                                        label: "Settings",
                                        onTap: () =>
                                            _openSettingsPage(chamaName),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 18),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          setState(() => _selectedIndex = 0);
          await _openFinancePage();
        });
        return _buildHomeTab();
      case 2:
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          setState(() => _selectedIndex = 0);
          await _openMeetingsPage();
        });
        return _buildHomeTab();
      case 3:
        return FutureBuilder<Map<String, dynamic>>(
          future: _chamaFuture,
          builder: (context, snapshot) {
            final chamaName = (snapshot.data?["name"] ?? "Kaya Chama")
                .toString();
            return KayaAIScreen(
              memberName: widget.memberName,
              chamaName: chamaName,
              chamaId: widget.chamaId,
            );
          },
        );
      case 4:
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          setState(() => _selectedIndex = 0);
          await _openSettingsPage();
        });
        return _buildHomeTab();
      default:
        return _buildHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildSelectedTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.black54,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: "Finance",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_rounded),
            label: "Meetings",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_rounded),
            label: "Kaya AI",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String name;
  final String role;
  final VoidCallback onProfileTap;

  const _TopBar({
    required this.name,
    required this.role,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hi, $name 👋",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: TextStyle(color: Colors.white.withOpacity(0.88)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onProfileTap,
            icon: const Icon(Icons.person, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _HeroDashboardCard extends StatelessWidget {
  final String chamaName;
  final String role;
  final String savedAmount;
  final String targetAmount;
  final double progress;
  final String statusText;
  final Color statusColor;
  final VoidCallback onOpenFinance;

  const _HeroDashboardCard({
    required this.chamaName,
    required this.role,
    required this.savedAmount,
    required this.targetAmount,
    required this.progress,
    required this.statusText,
    required this.statusColor,
    required this.onOpenFinance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                chamaName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  role,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            "Savings Progress",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            "$savedAmount / $targetAmount",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onOpenFinance,
                child: const Text(
                  "View finance",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

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
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE8F5E9),
            child: Icon(icon, color: const Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  const _InsightCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Text(
                "Kaya Insight",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _DashboardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DashboardActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _InfoCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ExpandableText extends StatefulWidget {
  final String text;

  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: expanded ? 20 : 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => setState(() => expanded = !expanded),
          child: Text(
            expanded ? "Show less" : "Show more",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _MembersSheet extends StatelessWidget {
  final List<Map<String, dynamic>> members;

  const _MembersSheet({required this.members});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "All Members",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        ...members.map((m) {
          final name = (m["name"] ?? "Member").toString();
          final phone = (m["phone"] ?? "").toString();
          final role = (m["role"] ?? "Member").toString();

          return ListTile(
            leading: CircleAvatar(
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : "M"),
            ),
            title: Text(name),
            subtitle: Text(phone),
            trailing: Text(role),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final double height;

  const _LoadingCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: onRetry, child: const Text("Retry")),
        ],
      ),
    );
  }
}
