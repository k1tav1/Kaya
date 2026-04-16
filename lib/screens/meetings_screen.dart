import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'meeting_details_screen.dart';

class MeetingsScreen extends StatefulWidget {
  final String chamaId;
  final String memberId;
  final String memberName;
  final String memberRole;

  const MeetingsScreen({
    super.key,
    required this.chamaId,
    required this.memberId,
    required this.memberName,
    required this.memberRole,
  });

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  late Future<List<Map<String, dynamic>>> _meetingsFuture;
  late Future<List<Map<String, dynamic>>> _membersFuture;

  bool _saving = false;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  bool get canManageMeeting {
    final role = widget.memberRole.toLowerCase();
    return role == 'chairperson' || role == 'secretary';
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _meetingsFuture = SupabaseService.fetchMeetingsByChama(
      chamaId: widget.chamaId,
    );
    _membersFuture = SupabaseService.getMembersByChama(widget.chamaId);
    if (mounted) setState(() {});
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createMeeting() async {
    if (!canManageMeeting) {
      _snack("Only the Chairperson or Secretary can create meetings.");
      return;
    }

    final members = await _membersFuture;
    if (!mounted) return;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF4F5F7),
      builder: (_) => _CreateMeetingSheet(
        members: members,
        currentMemberId: widget.memberId,
        memberRole: widget.memberRole,
        onSave:
            ({
              required String title,
              required DateTime meetingDate,
              required String? startTime,
              required String? endTime,
              required String? venue,
              required String? secretaryId,
              required String? chairpersonId,
            }) async {
              setState(() => _saving = true);
              try {
                await SupabaseService.createMeeting(
                  title: title,
                  meetingDate: meetingDate,
                  startTime: startTime,
                  endTime: endTime,
                  venue: venue,
                  createdBy: widget.memberId,
                  secretaryId: secretaryId,
                  chairpersonId: chairpersonId,
                  status: 'draft',
                );
                if (mounted) Navigator.pop(context, true);
              } catch (e) {
                _snack("Failed to create meeting: $e");
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
      ),
    );

    if (created == true) {
      _snack("Meeting created successfully ✅");
      _reload();
    }
  }

  Future<void> _openMeeting(Map<String, dynamic> meeting) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingDetailsScreen(
          chamaId: widget.chamaId,
          meetingId: meeting['id'].toString(),
          currentMemberId: widget.memberId,
          currentMemberName: widget.memberName,
          currentMemberRole: widget.memberRole,
        ),
      ),
    );

    _reload();
  }

  Map<String, dynamic>? _findUpcoming(List<Map<String, dynamic>> meetings) {
    if (meetings.isEmpty) return null;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final upcoming = meetings.where((m) {
      final raw = m['meeting_date'];
      if (raw == null) return false;
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return false;
      return !dt.isBefore(todayOnly);
    }).toList();

    if (upcoming.isEmpty) return meetings.first;

    upcoming.sort((a, b) {
      final da =
          DateTime.tryParse(a['meeting_date'].toString()) ?? DateTime(2100);
      final db =
          DateTime.tryParse(b['meeting_date'].toString()) ?? DateTime(2100);
      return da.compareTo(db);
    });

    return upcoming.first;
  }

  List<Map<String, dynamic>> _previousMeetings(
    List<Map<String, dynamic>> meetings,
    Map<String, dynamic>? upcoming,
  ) {
    if (upcoming == null) return meetings;
    return meetings.where((m) => m['id'] != upcoming['id']).toList();
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> meetings) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    List<Map<String, dynamic>> filtered = meetings.where((m) {
      return (m['status'] ?? '').toString().toLowerCase() != 'archived';
    }).toList();

    switch (_selectedFilter) {
      case 'Upcoming':
        filtered = filtered.where((m) {
          final raw = m['meeting_date'];
          final dt = raw == null ? null : DateTime.tryParse(raw.toString());
          return dt != null && !dt.isBefore(todayOnly);
        }).toList();
        break;

      case 'Draft':
        filtered = filtered.where((m) {
          return (m['status'] ?? '').toString().toLowerCase() == 'draft';
        }).toList();
        break;

      case 'Approved':
        filtered = filtered.where((m) {
          return m['approved'] == true;
        }).toList();
        break;

      case 'All':
      default:
        break;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((m) {
        final title = (m['title'] ?? '').toString().toLowerCase();
        final venue = (m['venue'] ?? '').toString().toLowerCase();
        return title.contains(q) || venue.contains(q);
      }).toList();
    }

    return filtered;
  }

  int _countUpcoming(List<Map<String, dynamic>> meetings) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    return meetings.where((m) {
      final raw = m['meeting_date'];
      final dt = raw == null ? null : DateTime.tryParse(raw.toString());
      return dt != null && !dt.isBefore(todayOnly);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Meetings",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => _reload(),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _meetingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: const [
                      _MeetingsHeaderCardPlaceholder(),
                      SizedBox(height: 12),
                      _LoadingCard(height: 170),
                      SizedBox(height: 12),
                      _LoadingCard(height: 220),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _MeetingsHeaderCard(
                        memberName: widget.memberName,
                        memberRole: widget.memberRole,
                        canManageMeeting: canManageMeeting,
                        onCreateMeeting: _createMeeting,
                      ),
                      const SizedBox(height: 12),
                      _ErrorCard(
                        title: "Failed to load meetings",
                        message: "${snapshot.error}",
                        onRetry: _reload,
                      ),
                    ],
                  );
                }

                final meetings = snapshot.data ?? [];
                final upcoming = _findUpcoming(meetings);
                final previous = _previousMeetings(meetings, upcoming);
                final filteredMeetings = _applyFilter(meetings);

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _MeetingsHeaderCard(
                      memberName: widget.memberName,
                      memberRole: widget.memberRole,
                      canManageMeeting: canManageMeeting,
                      onCreateMeeting: _createMeeting,
                    ),
                    const SizedBox(height: 12),
                    _UpcomingMeetingCard(
                      meeting: upcoming,
                      onTap: upcoming == null
                          ? null
                          : () => _openMeeting(upcoming),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: "Meeting Overview",
                      child: Row(
                        children: [
                          Expanded(
                            child: _MiniStatCard(
                              label: "Total",
                              value: meetings.length.toString(),
                              icon: Icons.event_note,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MiniStatCard(
                              label: "Upcoming",
                              value: _countUpcoming(meetings).toString(),
                              icon: Icons.upcoming,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MiniStatCard(
                              label: "History",
                              value: previous.length.toString(),
                              icon: Icons.history,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: "Search Meetings",
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Search by meeting title or venue...",
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: "Filters",
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChipButton(
                            label: 'All',
                            selected: _selectedFilter == 'All',
                            onTap: () =>
                                setState(() => _selectedFilter = 'All'),
                          ),
                          _FilterChipButton(
                            label: 'Upcoming',
                            selected: _selectedFilter == 'Upcoming',
                            onTap: () =>
                                setState(() => _selectedFilter = 'Upcoming'),
                          ),
                          _FilterChipButton(
                            label: 'Draft',
                            selected: _selectedFilter == 'Draft',
                            onTap: () =>
                                setState(() => _selectedFilter = 'Draft'),
                          ),
                          _FilterChipButton(
                            label: 'Approved',
                            selected: _selectedFilter == 'Approved',
                            onTap: () =>
                                setState(() => _selectedFilter = 'Approved'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: "Meetings (${filteredMeetings.length})",
                      child: filteredMeetings.isEmpty
                          ? const Text(
                              "No meetings found for this search or filter.",
                              style: TextStyle(color: Colors.black54),
                            )
                          : Column(
                              children: filteredMeetings.map((meeting) {
                                return _MeetingProgressTile(
                                  meeting: meeting,
                                  onTap: () => _openMeeting(meeting),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: "Quick Meeting Guide",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _BulletLine("Create a meeting first"),
                          _BulletLine("Record attendance for all members"),
                          _BulletLine("Add agenda items and resolutions"),
                          _BulletLine("Assign action items with due dates"),
                          _BulletLine("Save minutes and approve the meeting"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _CreateMeetingSheet extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final String currentMemberId;
  final String memberRole;
  final Future<void> Function({
    required String title,
    required DateTime meetingDate,
    required String? startTime,
    required String? endTime,
    required String? venue,
    required String? secretaryId,
    required String? chairpersonId,
  })
  onSave;

  const _CreateMeetingSheet({
    required this.members,
    required this.currentMemberId,
    required this.memberRole,
    required this.onSave,
  });

  @override
  State<_CreateMeetingSheet> createState() => _CreateMeetingSheetState();
}

class _CreateMeetingSheetState extends State<_CreateMeetingSheet> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController();
  final _endTimeCtrl = TextEditingController();

  DateTime? _meetingDate;
  String? _secretaryId;
  String? _chairpersonId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    for (final m in widget.members) {
      final role = (m['role'] ?? '').toString().toLowerCase();
      if (role == 'secretary') _secretaryId ??= m['id'].toString();
      if (role == 'chairperson') _chairpersonId ??= m['id'].toString();
    }

    if (widget.memberRole.toLowerCase() == 'secretary') {
      _secretaryId = widget.currentMemberId;
    }
    if (widget.memberRole.toLowerCase() == 'chairperson') {
      _chairpersonId = widget.currentMemberId;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _venueCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _meetingDate ?? today,
      firstDate: today,
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() => _meetingDate = picked);
    }
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  TimeOfDay? _parse24HourTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _isEndAfterStart(String start, String end) {
    final startTime = _parse24HourTime(start);
    final endTime = _parse24HourTime(end);

    if (startTime == null || endTime == null) return true;

    final startMinutes = (startTime.hour * 60) + startTime.minute;
    final endMinutes = (endTime.hour * 60) + endTime.minute;

    return endMinutes > startMinutes;
  }

  Future<void> _pickTime(
    TextEditingController controller, {
    bool isEndTime = false,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked == null) return;

    final hour = picked.hour.toString().padLeft(2, '0');
    final minute = picked.minute.toString().padLeft(2, '0');
    final selected = "$hour:$minute";

    final now = DateTime.now();

    if (!isEndTime && _meetingDate != null && _isSameDate(_meetingDate!, now)) {
      final selectedMinutes = (picked.hour * 60) + picked.minute;
      final currentMinutes = (now.hour * 60) + now.minute;

      if (selectedMinutes <= currentMinutes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Start time must be later than the current time."),
            ),
          );
        }
        return;
      }
    }

    if (isEndTime && _startTimeCtrl.text.trim().isNotEmpty) {
      final valid = _isEndAfterStart(_startTimeCtrl.text.trim(), selected);
      if (!valid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("End time must be later than start time."),
            ),
          );
        }
        return;
      }
    }

    setState(() {
      controller.text = selected;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_meetingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a meeting date.")),
      );
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(
      _meetingDate!.year,
      _meetingDate!.month,
      _meetingDate!.day,
    );

    if (selectedDate.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meeting date cannot be in the past.")),
      );
      return;
    }

    final start = _startTimeCtrl.text.trim();
    final end = _endTimeCtrl.text.trim();

    if (start.isNotEmpty) {
      final startTime = _parse24HourTime(start);

      if (startTime == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invalid start time.")));
        return;
      }

      if (_isSameDate(_meetingDate!, now)) {
        final startMinutes = (startTime.hour * 60) + startTime.minute;
        final currentMinutes = (now.hour * 60) + now.minute;

        if (startMinutes <= currentMinutes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Start time must be later than the current time."),
            ),
          );
          return;
        }
      }
    }

    if (start.isNotEmpty && end.isNotEmpty && !_isEndAfterStart(start, end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("End time must be later than start time."),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onSave(
        title: _titleCtrl.text.trim(),
        meetingDate: _meetingDate!,
        startTime: start.isEmpty ? null : start,
        endTime: end.isEmpty ? null : end,
        venue: _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
        secretaryId: _secretaryId,
        chairpersonId: _chairpersonId,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleMembers = widget.members.where((m) {
      final role = (m['role'] ?? '').toString().toLowerCase();
      return role == 'chairperson' || role == 'secretary';
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              "Create Meeting",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Meeting title",
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? "Enter meeting title" : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: "Meeting date",
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _meetingDate == null
                      ? "Select date"
                      : "${_meetingDate!.year}-${_meetingDate!.month.toString().padLeft(2, '0')}-${_meetingDate!.day.toString().padLeft(2, '0')}",
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startTimeCtrl,
                    readOnly: true,
                    onTap: () => _pickTime(_startTimeCtrl),
                    decoration: const InputDecoration(
                      labelText: "Start time",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _endTimeCtrl,
                    readOnly: true,
                    onTap: () => _pickTime(_endTimeCtrl, isEndTime: true),
                    decoration: const InputDecoration(
                      labelText: "End time",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _venueCtrl,
              decoration: const InputDecoration(
                labelText: "Venue",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: roleMembers.any((m) => m['id'].toString() == _secretaryId)
                  ? _secretaryId
                  : null,
              items: roleMembers.map((m) {
                return DropdownMenuItem<String>(
                  value: m['id'].toString(),
                  child: Text(
                    "${m['name']} (${m['role']})",
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _secretaryId = v),
              decoration: const InputDecoration(
                labelText: "Secretary",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value:
                  roleMembers.any((m) => m['id'].toString() == _chairpersonId)
                  ? _chairpersonId
                  : null,
              items: roleMembers.map((m) {
                return DropdownMenuItem<String>(
                  value: m['id'].toString(),
                  child: Text(
                    "${m['name']} (${m['role']})",
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _chairpersonId = v),
              decoration: const InputDecoration(
                labelText: "Chairperson",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.save),
                label: Text(_submitting ? "Saving..." : "Save Meeting"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetingsHeaderCard extends StatelessWidget {
  final String memberName;
  final String memberRole;
  final bool canManageMeeting;
  final VoidCallback onCreateMeeting;

  const _MeetingsHeaderCard({
    required this.memberName,
    required this.memberRole,
    required this.canManageMeeting,
    required this.onCreateMeeting,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: "Hi, $memberName",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Role: $memberRole",
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          const Text(
            "Manage and review chama meetings, attendance, agenda items and action items.",
            style: TextStyle(color: Colors.black87),
          ),
          if (canManageMeeting) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCreateMeeting,
                icon: const Icon(Icons.add),
                label: const Text("New Meeting"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingMeetingCard extends StatelessWidget {
  final Map<String, dynamic>? meeting;
  final VoidCallback? onTap;

  const _UpcomingMeetingCard({required this.meeting, this.onTap});

  String _fmt(dynamic raw, {String fallback = "Not set"}) {
    if (raw == null) return fallback;
    final s = raw.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: "Upcoming Meeting",
      trailing: meeting == null
          ? null
          : TextButton(onPressed: onTap, child: const Text("Open")),
      child: meeting == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _MeetingInfoRow(
                  label: "Title",
                  value: "No meeting scheduled yet",
                ),
                SizedBox(height: 8),
                _MeetingInfoRow(label: "Date", value: "Not set"),
                SizedBox(height: 8),
                _MeetingInfoRow(label: "Venue", value: "Not set"),
                SizedBox(height: 8),
                _MeetingInfoRow(label: "Status", value: "draft"),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MeetingInfoRow(
                  label: "Title",
                  value: _fmt(meeting!['title'], fallback: "Untitled meeting"),
                ),
                const SizedBox(height: 8),
                _MeetingInfoRow(
                  label: "Date",
                  value: _fmt(meeting!['meeting_date']),
                ),
                const SizedBox(height: 8),
                _MeetingInfoRow(label: "Venue", value: _fmt(meeting!['venue'])),
                const SizedBox(height: 8),
                _MeetingInfoRow(
                  label: "Status",
                  value: _fmt(meeting!['status'], fallback: "draft"),
                ),
              ],
            ),
    );
  }
}

class _MeetingProgressTile extends StatelessWidget {
  final Map<String, dynamic> meeting;
  final VoidCallback onTap;

  const _MeetingProgressTile({required this.meeting, required this.onTap});

  String _fmt(dynamic raw, {String fallback = "Not set"}) {
    if (raw == null) return fallback;
    final s = raw.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  int _calculateProgress(Map<String, dynamic> details) {
    int score = 0;

    final attendance = (details['attendance'] as List?) ?? [];
    final agendaItems = (details['agendaItems'] as List?) ?? [];
    final actionItems = (details['actionItems'] as List?) ?? [];
    final meetingData = (details['meeting'] as Map<String, dynamic>?) ?? {};

    final hasAttendance = attendance.isNotEmpty;
    final hasAgenda = agendaItems.isNotEmpty;
    final hasActionItems = actionItems.isNotEmpty;
    final hasMinutes = (meetingData['minutes_text'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;

    if (hasAttendance) score += 25;
    if (hasAgenda) score += 25;
    if (hasActionItems) score += 25;
    if (hasMinutes) score += 25;

    return score;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: SupabaseService.getMeetingDetails(
        meetingId: meeting['id'].toString(),
      ),
      builder: (context, snapshot) {
        final attendanceCount =
            ((snapshot.data?['attendance'] as List?)?.length ?? 0);
        final agendaCount =
            ((snapshot.data?['agendaItems'] as List?)?.length ?? 0);
        final actionCount =
            ((snapshot.data?['actionItems'] as List?)?.length ?? 0);
        final progress = snapshot.hasData
            ? _calculateProgress(snapshot.data!)
            : 0;

        final approved = meeting['approved'] == true;
        final status = _fmt(meeting['status'], fallback: "draft");

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.event_note, color: Color(0xFF2E7D32)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fmt(
                              meeting['title'],
                              fallback: "Untitled meeting",
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${_fmt(meeting['meeting_date'])} • ${_fmt(meeting['venue'])}",
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SmallPill(
                        label: status,
                        background: const Color(0xFFE8F5E9),
                        textColor: const Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SmallPill(
                        label: approved ? "approved" : "pending approval",
                        background: approved
                            ? const Color(0xFFE3F2FD)
                            : const Color(0xFFFFF3E0),
                        textColor: approved
                            ? const Color(0xFF0D47A1)
                            : const Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStatCard(
                        label: "Attendance",
                        value: attendanceCount.toString(),
                        icon: Icons.people,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatCard(
                        label: "Agenda",
                        value: agendaCount.toString(),
                        icon: Icons.list_alt,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatCard(
                        label: "Tasks",
                        value: actionCount.toString(),
                        icon: Icons.task_alt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Completion: $progress%",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      progress == 100 ? "Complete" : "In progress",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: progress == 100
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 8,
                    backgroundColor: Colors.black12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;

  const _SmallPill({
    required this.label,
    required this.background,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E7D32) : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _MeetingsHeaderCardPlaceholder extends StatelessWidget {
  const _MeetingsHeaderCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const _LoadingCard(height: 150);
  }
}

class _MeetingInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _MeetingInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
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

class _BulletLine extends StatelessWidget {
  final String text;

  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• "),
          Expanded(child: Text(text)),
        ],
      ),
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
      decoration: BoxDecoration(
        color: Colors.white,
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
