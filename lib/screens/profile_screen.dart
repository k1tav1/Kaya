import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'change_password.dart';
import 'home_screen.dart';
import 'join_login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String memberId;
  final String memberName;
  final String memberRole;
  final String memberPhone;
  final String chamaId;

  const ProfileScreen({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.memberRole,
    required this.memberPhone,
    required this.chamaId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _switching = false;
  String? _error;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _memberChamas = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final profile = await SupabaseService.getMemberProfile(widget.memberId);
      final chamas = await SupabaseService.getMemberChamas(widget.memberId);

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _memberChamas = chamas;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _switchChama(String newChamaId) async {
    try {
      setState(() => _switching = true);

      await SupabaseService.updateActiveChama(
        memberId: widget.memberId,
        chamaId: newChamaId,
      );

      final chamas = await SupabaseService.getMemberChamas(widget.memberId);

      final selected = chamas.cast<Map<String, dynamic>?>().firstWhere(
        (c) => c?['chama_id']?.toString() == newChamaId,
        orElse: () => null,
      );

      if (selected == null) {
        throw Exception('Selected chama membership not found.');
      }

      final refreshedProfile = await SupabaseService.getMemberProfile(
        widget.memberId,
      );

      final memberName = (refreshedProfile?['name'] ?? widget.memberName)
          .toString();
      final memberPhone = (refreshedProfile?['phone'] ?? widget.memberPhone)
          .toString();
      final memberRole = (selected['role'] ?? widget.memberRole).toString();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chama switched successfully')),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            chamaId: newChamaId,
            memberName: memberName,
            memberRole: memberRole,
            memberPhone: memberPhone,
            memberId: widget.memberId,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to switch chama: $e')));
    } finally {
      if (mounted) {
        setState(() => _switching = false);
      }
    }
  }

  Future<void> _openEditProfile({
    required String fullName,
    required String email,
    required String gender,
  }) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          memberId: widget.memberId,
          currentName: fullName,
          currentEmail: email == 'No email' ? '' : email,
          currentGender: gender == 'Not set' ? '' : gender,
        ),
      ),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const JoinLoginChamaPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = (_profile?['email'] ?? 'No email').toString();
    final gender = (_profile?['gender'] ?? 'Not set').toString();
    final fullName = (_profile?['name'] ?? widget.memberName).toString();
    final phone = (_profile?['phone'] ?? widget.memberPhone).toString();
    final activeChamaId = (_profile?['active_chama_id'] ?? widget.chamaId)
        .toString();

    final activeChama = _memberChamas.cast<Map<String, dynamic>?>().firstWhere(
      (c) => c?['chama_id']?.toString() == activeChamaId,
      orElse: () => null,
    );

    final activeRole = (activeChama?['role'] ?? widget.memberRole).toString();
    final activeChamaName = (activeChama?['chama_name'] ?? 'Current Chama')
        .toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const CircleAvatar(
                                radius: 38,
                                backgroundColor: Colors.green,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                activeRole,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Chip(label: Text('Active: $activeChamaName')),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _openEditProfile(
                                  fullName: fullName,
                                  email: email,
                                  gender: gender,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit Profile'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.email_outlined),
                                title: const Text('Email'),
                                subtitle: Text(email),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.phone_outlined),
                                title: const Text('Phone Number'),
                                subtitle: Text(phone),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.person_outline),
                                title: const Text('Gender'),
                                subtitle: Text(gender),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My Chamas',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_memberChamas.isEmpty)
                                const Text(
                                  'This member has not joined any chamas yet.',
                                )
                              else
                                ..._memberChamas.map((chama) {
                                  final chamaId = chama['chama_id'].toString();
                                  final isActive = chamaId == activeChamaId;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: ListTile(
                                      title: Text(
                                        (chama['chama_name'] ?? 'Unnamed Chama')
                                            .toString(),
                                      ),
                                      subtitle: Text(
                                        'Role: ${(chama['role'] ?? 'Member').toString()}',
                                      ),
                                      trailing: isActive
                                          ? const Chip(label: Text('Active'))
                                          : ElevatedButton(
                                              onPressed: _switching
                                                  ? null
                                                  : () => _switchChama(chamaId),
                                              child: const Text('Switch'),
                                            ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.lock_outline),
                              title: const Text('Change Password'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChangePasswordScreen(
                                      memberId: widget.memberId,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.logout,
                                color: Colors.red,
                              ),
                              title: const Text('Logout'),
                              onTap: _logout,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (_switching)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}
