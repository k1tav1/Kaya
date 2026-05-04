import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/supabase_service.dart';
import '../services/theme_controller.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  final String memberId;
  final String chamaId;
  final String memberName;
  final String memberRole;
  final String chamaName;

  const SettingsScreen({
    super.key,
    required this.memberId,
    required this.chamaId,
    required this.memberName,
    required this.memberRole,
    required this.chamaName,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool darkMode = false;
  bool meetingReminders = true;
  bool contributionReminders = true;
  bool loanReminders = false;

  bool _loading = true;

  Map<String, dynamic>? _chama;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _memberChamas = [];

  bool get isLeader {
    final role = widget.memberRole.toLowerCase();
    return role == "chairperson" || role == "secretary" || role == "treasurer";
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getChamaById(widget.chamaId),
        SupabaseService.getMemberProfile(widget.memberId),
        SupabaseService.getMemberChamas(widget.memberId),
        SupabaseService.getMemberSettings(memberId: widget.memberId),
      ]);

      _chama = results[0] as Map<String, dynamic>;
      _profile = results[1] as Map<String, dynamic>?;
      _memberChamas = results[2] as List<Map<String, dynamic>>;

      final settings = results[3] as Map<String, dynamic>;
      darkMode = settings['dark_mode'] == true;
      meetingReminders = settings['meeting_reminders'] == true;
      contributionReminders = settings['contribution_reminders'] == true;
      loanReminders = settings['loan_reminders'] == true;
    } catch (e) {
      _snack("Failed to load settings: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePreferenceSettings() async {
    try {
      await SupabaseService.saveMemberSettings(
        memberId: widget.memberId,
        darkMode: darkMode,
        meetingReminders: meetingReminders,
        contributionReminders: contributionReminders,
        loanReminders: loanReminders,
      );
    } catch (e) {
      _snack("Failed to save settings: $e");
    }
  }

  Future<void> _editChamaInformation() async {
    if (!isLeader) {
      _snack("Only chama leaders can edit chama information.");
      return;
    }

    final chama = _chama ?? {};
    final nameCtrl = TextEditingController(
      text: (chama['name'] ?? '').toString(),
    );
    final purposeCtrl = TextEditingController(
      text: (chama['purpose'] ?? '').toString(),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Chama Information"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Chama Name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: purposeCtrl,
              decoration: const InputDecoration(labelText: "Purpose"),
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

    try {
      await SupabaseService.updateChama(
        chamaId: widget.chamaId,
        updates: {
          'name': nameCtrl.text.trim(),
          'purpose': purposeCtrl.text.trim(),
        },
      );
      _snack("Chama information updated ✅");
      _loadData();
    } catch (e) {
      _snack("Failed to update chama information: $e");
    }
  }

  Future<void> _editPaymentSetup() async {
    if (!isLeader) {
      _snack("Only chama leaders can edit payment setup.");
      return;
    }

    final chama = _chama ?? {};

    final paymentModeCtrl = TextEditingController(
      text: (chama['payment_mode'] ?? '').toString(),
    );
    final paybillNumberCtrl = TextEditingController(
      text: (chama['paybill_number'] ?? '').toString(),
    );
    final paybillAccountCtrl = TextEditingController(
      text: (chama['paybill_account'] ?? '').toString(),
    );
    final tillNumberCtrl = TextEditingController(
      text: (chama['till_number'] ?? '').toString(),
    );
    final bankNameCtrl = TextEditingController(
      text: (chama['bank_name'] ?? '').toString(),
    );
    final bankAccountCtrl = TextEditingController(
      text: (chama['bank_account'] ?? '').toString(),
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              "Payment Setup",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paymentModeCtrl,
              decoration: const InputDecoration(
                labelText: "Payment Mode",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: paybillNumberCtrl,
              decoration: const InputDecoration(
                labelText: "Paybill Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: paybillAccountCtrl,
              decoration: const InputDecoration(
                labelText: "Paybill Account",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tillNumberCtrl,
              decoration: const InputDecoration(
                labelText: "Till Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bankNameCtrl,
              decoration: const InputDecoration(
                labelText: "Bank Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bankAccountCtrl,
              decoration: const InputDecoration(
                labelText: "Bank Account",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Save Payment Setup"),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      await SupabaseService.updateChama(
        chamaId: widget.chamaId,
        updates: {
          'payment_mode': paymentModeCtrl.text.trim(),
          'paybill_number': paybillNumberCtrl.text.trim(),
          'paybill_account': paybillAccountCtrl.text.trim(),
          'till_number': tillNumberCtrl.text.trim(),
          'bank_name': bankNameCtrl.text.trim(),
          'bank_account': bankAccountCtrl.text.trim(),
        },
      );
      _snack("Payment setup updated ✅");
      _loadData();
    } catch (e) {
      _snack("Failed to update payment setup: $e");
    }
  }

  Future<void> _editRules() async {
    if (!isLeader) {
      _snack("Only chama leaders can update rules.");
      return;
    }

    final rulesCtrl = TextEditingController(
      text: (_chama?['rules'] ?? '').toString(),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Chama Rules"),
        content: TextField(
          controller: rulesCtrl,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: "Rules",
            hintText: "Write the chama rules here...",
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

    try {
      await SupabaseService.updateChama(
        chamaId: widget.chamaId,
        updates: {'rules': rulesCtrl.text.trim()},
      );
      _snack("Rules updated ✅");
      _loadData();
    } catch (e) {
      _snack("Failed to update rules: $e");
    }
  }

  Future<void> _editProfile() async {
    final profile = _profile ?? {};

    final phoneCtrl = TextEditingController(
      text: (profile['phone'] ?? '').toString(),
    );
    final emailCtrl = TextEditingController(
      text: (profile['email'] ?? '').toString(),
    );
    final genderCtrl = TextEditingController(
      text: (profile['gender'] ?? '').toString(),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit My Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: "Phone"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: genderCtrl,
              decoration: const InputDecoration(labelText: "Gender"),
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

    try {
      await SupabaseService.saveMemberProfile(
        memberId: widget.memberId,
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        gender: genderCtrl.text.trim(),
        password: (_profile?['password'] ?? '').toString(),
        activeChamaId: (_profile?['active_chama_id'] ?? widget.chamaId)
            .toString(),
      );
      _snack("Profile updated ✅");
      _loadData();
    } catch (e) {
      _snack("Failed to update profile: $e");
    }
  }

  Future<void> _changePassword() async {
    final passwordCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Change Password / PIN"),
        content: TextField(
          controller: passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: "New password / PIN"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Update"),
          ),
        ],
      ),
    );

    if (saved != true) return;
    if (passwordCtrl.text.trim().isEmpty) {
      _snack("Password cannot be empty.");
      return;
    }

    try {
      await SupabaseService.changeMemberPassword(
        memberId: widget.memberId,
        newPassword: passwordCtrl.text.trim(),
      );
      _snack("Password updated ✅");
      _loadData();
    } catch (e) {
      _snack("Failed to update password: $e");
    }
  }

  Future<void> _switchChama() async {
    if (_memberChamas.isEmpty) {
      _snack("No chama options found.");
      return;
    }

    String? selectedChamaId = (_profile?['active_chama_id'] ?? widget.chamaId)
        .toString();

    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Switch Active Chama"),
        content: StatefulBuilder(
          builder: (context, setModalState) {
            return DropdownButtonFormField<String>(
              value:
                  _memberChamas.any(
                    (c) => c['chama_id'].toString() == selectedChamaId,
                  )
                  ? selectedChamaId
                  : null,
              items: _memberChamas.map((c) {
                return DropdownMenuItem<String>(
                  value: c['chama_id'].toString(),
                  child: Text(
                    "${c['chama_name']} (${c['role']})",
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setModalState(() {
                  selectedChamaId = value;
                });
              },
              decoration: const InputDecoration(
                labelText: "Choose active chama",
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Switch"),
          ),
        ],
      ),
    );

    if (changed != true || selectedChamaId == null) return;

    try {
      await SupabaseService.updateActiveChama(
        memberId: widget.memberId,
        chamaId: selectedChamaId!,
      );
      _snack("Active chama switched ✅");
      _loadData();
    } catch (e) {
      _snack("Failed to switch chama: $e");
    }
  }

  Future<void> _showInviteInfo() async {
    if (!isLeader) {
      _snack("Only chama leaders can invite members.");
      return;
    }

    final chamaName = (_chama?['name'] ?? widget.chamaName).toString();
    final inviteCode = (_chama?['invite_code'] ?? '').toString().trim();

    if (inviteCode.isEmpty) {
      _snack("No invite code found for this chama.");
      return;
    }

    final inviteMessage =
        "Join my chama on Kaya.\n\n"
        "Chama: $chamaName\n"
        "Invite Code: $inviteCode\n\n"
        "Open Kaya and use this invite code to join.";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Invite Members"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Chama: $chamaName"),
            const SizedBox(height: 12),
            const Text(
              "Permanent Invite Code",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: SelectableText(
                inviteCode,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Share this invite code with members so they can join your chama.",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: inviteCode));
              if (mounted) _snack("Invite code copied ✅");
            },
            child: const Text("Copy Code"),
          ),
          TextButton(
            onPressed: () async {
              await Share.share(inviteMessage);
            },
            child: const Text("Share"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _showRolesInfo() async {
    final members = await SupabaseService.getMembersByChama(widget.chamaId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Roles & Permissions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...members.map((m) {
            return ListTile(
              leading: CircleAvatar(
                child: Text((m['name'] ?? 'M').toString()[0].toUpperCase()),
              ),
              title: Text((m['name'] ?? 'Member').toString()),
              subtitle: Text((m['phone'] ?? '').toString()),
              trailing: Text((m['role'] ?? 'Member').toString()),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chamaName = (_chama?['name'] ?? widget.chamaName).toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            color: Colors.green,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.memberName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.memberRole,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                chamaName,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  const _SectionHeader("Chama Settings"),
                  _SettingsTile(
                    icon: Icons.group,
                    title: "Chama Information",
                    subtitle: "View and edit chama details",
                    onTap: _editChamaInformation,
                  ),
                  _SettingsTile(
                    icon: Icons.payments,
                    title: "Payment Setup",
                    subtitle: "Paybill, Till number, or Bank account",
                    onTap: _editPaymentSetup,
                  ),
                  _SettingsTile(
                    icon: Icons.rule,
                    title: "Chama Rules",
                    subtitle: "Update contribution and participation rules",
                    onTap: _editRules,
                  ),

                  const SizedBox(height: 18),

                  const _SectionHeader("Notifications"),
                  SwitchListTile(
                    value: meetingReminders,
                    onChanged: (value) async {
                      setState(() => meetingReminders = value);
                      await _savePreferenceSettings();
                      _snack("Meeting reminder setting updated.");
                    },
                    secondary: const Icon(Icons.notifications_active),
                    title: const Text("Meeting Reminders"),
                    subtitle: const Text("Get notified before meetings"),
                  ),
                  SwitchListTile(
                    value: contributionReminders,
                    onChanged: (value) async {
                      setState(() => contributionReminders = value);
                      await _savePreferenceSettings();
                      _snack("Contribution reminder setting updated.");
                    },
                    secondary: const Icon(Icons.attach_money),
                    title: const Text("Contribution Reminders"),
                    subtitle: const Text(
                      "Get notified before contribution due date",
                    ),
                  ),
                  SwitchListTile(
                    value: loanReminders,
                    onChanged: (value) async {
                      setState(() => loanReminders = value);
                      await _savePreferenceSettings();
                      _snack("Loan reminder setting updated.");
                    },
                    secondary: const Icon(Icons.account_balance_wallet),
                    title: const Text("Loan Reminders"),
                    subtitle: const Text("Get loan repayment alerts"),
                  ),

                  const SizedBox(height: 18),

                  const _SectionHeader("Appearance"),
                  SwitchListTile(
                    value: darkMode,
                    onChanged: (value) async {
                      setState(() => darkMode = value);
                      await _savePreferenceSettings();
                      if (context.mounted) {
                        Provider.of<ThemeController>(context, listen: false)
                            .setSettings({
                          'dark_mode': value,
                          'meeting_reminders': meetingReminders,
                          'contribution_reminders': contributionReminders,
                          'loan_reminders': loanReminders,
                        });
                      }
                      _snack("Dark mode preference saved.");
                    },
                    secondary: const Icon(Icons.dark_mode),
                    title: const Text("Dark Mode"),
                    subtitle: const Text("Switch app appearance"),
                  ),

                  const SizedBox(height: 18),

                  const _SectionHeader("Management"),
                  _SettingsTile(
                    icon: Icons.person_add_alt_1,
                    title: "Invite Members",
                    subtitle: "View, copy, and share invite code",
                    onTap: _showInviteInfo,
                  ),
                  _SettingsTile(
                    icon: Icons.admin_panel_settings,
                    title: "Roles & Permissions",
                    subtitle: "View current member roles",
                    onTap: _showRolesInfo,
                  ),
                  _SettingsTile(
                    icon: Icons.swap_horiz,
                    title: "Switch Active Chama",
                    subtitle: "Change the chama you are working in",
                    onTap: _switchChama,
                  ),
                  _SettingsTile(
                    icon: Icons.edit,
                    title: "Edit My Profile",
                    subtitle: "Update phone, email and gender",
                    onTap: _editProfile,
                  ),

                  const SizedBox(height: 18),

                  const _SectionHeader("Security"),
                  _SettingsTile(
                    icon: Icons.lock,
                    title: "Change Password / PIN",
                    subtitle: "Manage account security",
                    onTap: _changePassword,
                  ),
                  _SettingsTile(
                    icon: Icons.logout,
                    title: "Logout",
                    subtitle: "Sign out from this device",
                    onTap: () => Navigator.pop(context),
                  ),

                  const SizedBox(height: 18),

                  const _SectionHeader("About"),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: "About Kaya",
                    subtitle: "Chama management made easy",
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: "Kaya",
                      applicationVersion: "v1.0 Demo",
                      applicationLegalese: "Kaya Chama Management App",
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.12),
          child: Icon(icon, color: Colors.green),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
