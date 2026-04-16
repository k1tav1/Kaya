import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MeetingDetailsScreen extends StatefulWidget {
  final String chamaId;
  final String meetingId;
  final String currentMemberId;
  final String currentMemberName;
  final String currentMemberRole;

  const MeetingDetailsScreen({
    super.key,
    required this.chamaId,
    required this.meetingId,
    required this.currentMemberId,
    required this.currentMemberName,
    required this.currentMemberRole,
  });

  @override
  State<MeetingDetailsScreen> createState() => _MeetingDetailsScreenState();
}

class _MeetingDetailsScreenState extends State<MeetingDetailsScreen> {
  late Future<Map<String, dynamic>> _meetingFuture;
  late Future<List<Map<String, dynamic>>> _membersFuture;

  bool get isChairperson =>
      widget.currentMemberRole.toLowerCase() == "chairperson";

  bool get canManage =>
      widget.currentMemberRole.toLowerCase() == "chairperson" ||
      widget.currentMemberRole.toLowerCase() == "secretary";

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _meetingFuture = SupabaseService.getMeetingDetails(
      meetingId: widget.meetingId,
    );
    _membersFuture = SupabaseService.getMembersByChama(widget.chamaId);
    setState(() {});
  }

  bool _isDraft(Map<String, dynamic> meeting) {
    return (meeting['status'] ?? '').toString().toLowerCase() == 'draft';
  }

  bool _isPublished(Map<String, dynamic> meeting) {
    return (meeting['status'] ?? '').toString().toLowerCase() == 'published';
  }

  Future<void> _approveMeeting() async {
    await SupabaseService.approveMeeting(
      meetingId: widget.meetingId,
      approvedBy: widget.currentMemberId,
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Meeting approved ✅")));
    }

    _load();
  }

  Future<void> _publishMeeting() async {
    await SupabaseService.publishMeeting(meetingId: widget.meetingId);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Meeting published ✅")));
    }

    _load();
  }

  Future<void> _revertToDraft() async {
    await SupabaseService.revertMeetingToDraft(meetingId: widget.meetingId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meeting moved back to draft ✅")),
      );
    }

    _load();
  }

  Future<void> _deleteMeeting() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete draft meeting?"),
        content: const Text(
          "This will permanently delete the meeting and its related attendance, agenda items, action items, and minutes.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await SupabaseService.deleteMeetingSafe(meetingId: widget.meetingId);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Draft meeting deleted ✅")));
      Navigator.pop(context);
    }
  }

  Future<void> _archiveMeeting() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Archive meeting?"),
        content: const Text(
          "This meeting will be hidden from the main meetings list but kept in the database.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Archive"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await SupabaseService.archiveMeeting(meetingId: widget.meetingId);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Meeting archived ✅")));
      Navigator.pop(context);
    }
  }

  Future<void> _editMeetingInfo({
    required Map<String, dynamic> meeting,
    required List<Map<String, dynamic>> members,
  }) async {
    if (!canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only the Chairperson or Secretary can do this."),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditMeetingInfoSheet(meeting: meeting, members: members),
    );

    if (result == null) return;

    await SupabaseService.updateMeetingDetails(
      meetingId: widget.meetingId,
      title: result['title'] as String,
      meetingDate: result['meeting_date'] as DateTime,
      startTime: result['start_time'] as String?,
      endTime: result['end_time'] as String?,
      venue: result['venue'] as String?,
      secretaryId: result['secretary_id'] as String?,
      chairpersonId: result['chairperson_id'] as String?,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meeting details updated ✅")),
      );
    }

    _load();
  }

  Future<void> _recordAttendance({
    required List<Map<String, dynamic>> members,
    required List<Map<String, dynamic>> existingAttendance,
  }) async {
    if (!canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only the Chairperson or Secretary can do this."),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AttendanceSheet(
        members: members,
        existingAttendance: existingAttendance,
        currentMemberId: widget.currentMemberId,
      ),
    );

    if (result == null) return;

    await SupabaseService.saveMeetingAttendance(
      meetingId: widget.meetingId,
      attendanceRows: result,
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Attendance saved ✅")));
    }

    _load();
  }

  Future<void> _editAgenda({
    required List<Map<String, dynamic>> existingAgendaItems,
  }) async {
    if (!canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only the Chairperson or Secretary can do this."),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AgendaItemsSheet(existingItems: existingAgendaItems),
    );

    if (result == null) return;

    await SupabaseService.saveMeetingAgendaItems(
      meetingId: widget.meetingId,
      createdBy: widget.currentMemberId,
      items: result,
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Agenda items saved ✅")));
    }

    _load();
  }

  Future<void> _editActionItems({
    required List<Map<String, dynamic>> existingActionItems,
    required List<Map<String, dynamic>> members,
    required List<Map<String, dynamic>> agendaItems,
  }) async {
    if (!canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only the Chairperson or Secretary can do this."),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ActionItemsSheet(
        existingItems: existingActionItems,
        members: members,
        agendaItems: agendaItems,
      ),
    );

    if (result == null) return;

    await SupabaseService.saveMeetingActionItems(
      meetingId: widget.meetingId,
      createdBy: widget.currentMemberId,
      items: result,
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Action items saved ✅")));
    }

    _load();
  }

  Future<void> _editMinutes({
    required Map<String, dynamic> meeting,
    required List<Map<String, dynamic>> attendance,
    required List<Map<String, dynamic>> agendaItems,
    required List<Map<String, dynamic>> actionItems,
  }) async {
    if (!canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only the Chairperson or Secretary can do this."),
        ),
      );
      return;
    }

    final generated = _buildMinutesTemplate(
      meeting: meeting,
      attendance: attendance,
      agendaItems: agendaItems,
      actionItems: actionItems,
    );

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MinutesEditorSheet(
        initialMinutes:
            (meeting["minutes_text"] ?? "").toString().trim().isEmpty
            ? generated
            : (meeting["minutes_text"] ?? "").toString(),
        initialAob: (meeting["any_other_business"] ?? "").toString(),
      ),
    );

    if (result == null) return;

    await SupabaseService.saveMeetingMinutes(
      meetingId: widget.meetingId,
      minutesText: result["minutes_text"] ?? "",
      anyOtherBusiness: result["any_other_business"],
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Minutes saved ✅")));
    }

    _load();
  }

  Future<void> _exportMinutesPdf({
    required Map<String, dynamic> meeting,
    required List<Map<String, dynamic>> attendance,
    required List<Map<String, dynamic>> agendaItems,
    required List<Map<String, dynamic>> actionItems,
  }) async {
    try {
      final pdf = pw.Document();

      final title = (meeting["title"] ?? "Meeting").toString();
      final date = (meeting["meeting_date"] ?? "Not set").toString();
      final start = (meeting["start_time"] ?? "Not set").toString();
      final end = (meeting["end_time"] ?? "Not set").toString();
      final venue = (meeting["venue"] ?? "Not set").toString();
      final status = (meeting["status"] ?? "draft").toString();
      final approved = meeting["approved"] == true ? "Yes" : "No";

      final minutesText = (meeting["minutes_text"] ?? "").toString().trim();
      final aob = (meeting["any_other_business"] ?? "").toString().trim();

      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text(
              "Meeting Minutes",
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            pw.Text("Title: $title"),
            pw.Text("Date: $date"),
            pw.Text("Start Time: $start"),
            pw.Text("End Time: $end"),
            pw.Text("Venue: $venue"),
            pw.Text("Status: $status"),
            pw.Text("Approved: $approved"),
            pw.SizedBox(height: 20),

            pw.Text(
              "Attendance",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (attendance.isEmpty)
              pw.Text("No attendance recorded yet.")
            else
              ...attendance.map((row) {
                final member = row["member"] as Map<String, dynamic>?;
                final name = member?["name"]?.toString() ?? "Member";
                final attendanceStatus = (row["attendance_status"] ?? "Not set")
                    .toString()
                    .replaceAll("_", " ");
                return pw.Bullet(text: "$name: $attendanceStatus");
              }),

            pw.SizedBox(height: 20),

            pw.Text(
              "Agenda Items",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (agendaItems.isEmpty)
              pw.Text("No agenda items added yet.")
            else
              ...agendaItems.map((item) {
                final itemOrder = (item["item_order"] ?? "-").toString();
                final itemTitle = (item["item_title"] ?? "Untitled item")
                    .toString();
                final discussion = (item["discussion_notes"] ?? "")
                    .toString()
                    .trim();
                final resolution = (item["resolution"] ?? "").toString().trim();

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "$itemOrder. $itemTitle",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (discussion.isNotEmpty)
                      pw.Text("Discussion: $discussion"),
                    if (resolution.isNotEmpty)
                      pw.Text("Resolution: $resolution"),
                    pw.SizedBox(height: 8),
                  ],
                );
              }),

            pw.SizedBox(height: 20),

            pw.Text(
              "Action Items",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (actionItems.isEmpty)
              pw.Text("No action items recorded yet.")
            else
              ...actionItems.map((item) {
                final assignee = item["assignee"] as Map<String, dynamic>?;
                final assigneeName =
                    assignee?["name"]?.toString() ?? "Unassigned";

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      (item["task_title"] ?? "Untitled task").toString(),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if ((item["task_description"] ?? "")
                        .toString()
                        .trim()
                        .isNotEmpty)
                      pw.Text(item["task_description"].toString()),
                    pw.Text("Assigned to: $assigneeName"),
                    pw.Text(
                      "Due: ${(item["due_date"] ?? "Not set").toString()}",
                    ),
                    pw.Text(
                      "Status: ${(item["status"] ?? "pending").toString().replaceAll("_", " ")}",
                    ),
                    pw.SizedBox(height: 8),
                  ],
                );
              }),

            pw.SizedBox(height: 20),

            pw.Text(
              "Minutes",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              minutesText.isEmpty
                  ? _buildMinutesTemplate(
                      meeting: meeting,
                      attendance: attendance,
                      agendaItems: agendaItems,
                      actionItems: actionItems,
                    )
                  : minutesText,
            ),

            pw.SizedBox(height: 20),

            pw.Text(
              "Any Other Business",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(aob.isEmpty ? "No AOB recorded." : aob),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: "${title.replaceAll(' ', '_')}_minutes.pdf",
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to export PDF: $e")));
      }
    }
  }

  String _buildMinutesTemplate({
    required Map<String, dynamic> meeting,
    required List<Map<String, dynamic>> attendance,
    required List<Map<String, dynamic>> agendaItems,
    required List<Map<String, dynamic>> actionItems,
  }) {
    final buffer = StringBuffer();

    buffer.writeln("MEETING MINUTES");
    buffer.writeln("");
    buffer.writeln("Title: ${meeting["title"] ?? "Meeting"}");
    buffer.writeln("Date: ${meeting["meeting_date"] ?? "Not set"}");
    buffer.writeln("Venue: ${meeting["venue"] ?? "Not set"}");
    buffer.writeln("");

    buffer.writeln("1. Attendance");
    if (attendance.isEmpty) {
      buffer.writeln("No attendance recorded yet.");
    } else {
      for (final row in attendance) {
        final member = row["member"] as Map<String, dynamic>?;
        final name = member?["name"]?.toString() ?? "Member";
        final status =
            row["attendance_status"]?.toString().replaceAll("_", " ") ??
            "Not set";
        buffer.writeln("- $name: $status");
      }
    }

    buffer.writeln("");
    buffer.writeln("2. Agenda Items");
    if (agendaItems.isEmpty) {
      buffer.writeln("No agenda items added yet.");
    } else {
      for (final item in agendaItems) {
        buffer.writeln(
          "${item["item_order"] ?? "-"} . ${item["item_title"] ?? "Untitled item"}",
        );

        final notes = (item["discussion_notes"] ?? "").toString().trim();
        final resolution = (item["resolution"] ?? "").toString().trim();

        if (notes.isNotEmpty) {
          buffer.writeln(" Discussion: $notes");
        }
        if (resolution.isNotEmpty) {
          buffer.writeln(" Resolution: $resolution");
        }
      }
    }

    buffer.writeln("");
    buffer.writeln("3. Action Items");
    if (actionItems.isEmpty) {
      buffer.writeln("No action items recorded yet.");
    } else {
      for (final item in actionItems) {
        final assignee = item["assignee"] as Map<String, dynamic>?;
        final assigneeName = assignee?["name"]?.toString() ?? "Unassigned";

        buffer.writeln("- ${item["task_title"] ?? "Untitled task"}");
        buffer.writeln(" Assigned to: $assigneeName");
        buffer.writeln(" Due: ${item["due_date"] ?? "Not set"}");
        buffer.writeln(
          " Status: ${(item["status"] ?? "pending").toString().replaceAll("_", " ")}",
        );
      }
    }

    buffer.writeln("");
    buffer.writeln("4. Any Other Business");
    buffer.writeln(
      (meeting["any_other_business"] ?? "No AOB recorded.").toString(),
    );

    buffer.writeln("");
    buffer.writeln("5. Approval");
    buffer.writeln(
      meeting["approved"] == true ? "Approved" : "Pending approval",
    );

    return buffer.toString();
  }

  Color _statusBg(String status) {
    switch (status) {
      case "completed":
        return const Color(0xFFE8F5E9);
      case "in_progress":
        return const Color(0xFFE3F2FD);
      default:
        return const Color(0xFFFFF3E0);
    }
  }

  Color _statusText(String status) {
    switch (status) {
      case "completed":
        return const Color(0xFF1B5E20);
      case "in_progress":
        return const Color(0xFF0D47A1);
      default:
        return const Color(0xFFE65100);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meeting Details"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([_meetingFuture, _membersFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final details = snapshot.data![0] as Map<String, dynamic>;
          final members = snapshot.data![1] as List<Map<String, dynamic>>;

          final meeting =
              (details["meeting"] as Map<String, dynamic>?) ??
              <String, dynamic>{};
          final attendance =
              (details["attendance"] as List<Map<String, dynamic>>?) ?? [];
          final agendaItems =
              (details["agendaItems"] as List<Map<String, dynamic>>?) ?? [];
          final actionItems =
              (details["actionItems"] as List<Map<String, dynamic>>?) ?? [];

          final generatedMinutes = _buildMinutesTemplate(
            meeting: meeting,
            attendance: attendance,
            agendaItems: agendaItems,
            actionItems: actionItems,
          );

          final displayedMinutes =
              (meeting["minutes_text"] ?? "").toString().trim().isEmpty
              ? generatedMinutes
              : (meeting["minutes_text"] ?? "").toString();

          final totalTasks = actionItems.length;
          final completedTasks = actionItems.where((e) {
            return (e["status"] ?? "").toString() == "completed";
          }).length;
          final pendingTasks = actionItems.where((e) {
            final s = (e["status"] ?? "").toString();
            return s == "pending" || s == "in_progress";
          }).length;

          final isDraft =
              (meeting["status"] ?? "").toString().toLowerCase() == "draft";
          final isPublished =
              (meeting["status"] ?? "").toString().toLowerCase() == "published";

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                meeting["title"]?.toString() ?? "Meeting",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _row("Date", meeting["meeting_date"]),
              _row("Start", meeting["start_time"]),
              _row("End", meeting["end_time"]),
              _row("Venue", meeting["venue"]),
              _row("Status", meeting["status"] ?? "draft"),
              _row("Approved", meeting["approved"] == true ? "Yes" : "No"),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    label: (meeting["status"] ?? "draft").toString(),
                    background: isDraft
                        ? const Color(0xFFFFF3E0)
                        : const Color(0xFFE3F2FD),
                    textColor: isDraft
                        ? const Color(0xFFE65100)
                        : const Color(0xFF0D47A1),
                  ),
                  _StatusChip(
                    label: meeting["approved"] == true
                        ? "approved"
                        : "not approved",
                    background: meeting["approved"] == true
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFF1F3F4),
                    textColor: meeting["approved"] == true
                        ? const Color(0xFF1B5E20)
                        : Colors.black87,
                  ),
                ],
              ),

              if (canManage) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () =>
                      _editMeetingInfo(meeting: meeting, members: members),
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit Meeting Info"),
                ),
              ],

              const SizedBox(height: 24),

              const Text(
                "Attendance",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              if (attendance.isEmpty)
                const Text(
                  "No attendance recorded yet.",
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...attendance.map((row) {
                  final member = row["member"] as Map<String, dynamic>?;
                  final name = member?["name"]?.toString() ?? "Member";
                  final status =
                      row["attendance_status"]?.toString().replaceAll(
                        "_",
                        " ",
                      ) ??
                      "Not set";

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : "M",
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(status),
                    ),
                  );
                }),

              const SizedBox(height: 20),

              if (canManage)
                ElevatedButton.icon(
                  icon: const Icon(Icons.people),
                  label: const Text("Record Attendance"),
                  onPressed: () => _recordAttendance(
                    members: members,
                    existingAttendance: attendance,
                  ),
                ),

              const SizedBox(height: 24),

              const Text(
                "Agenda Items",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              if (agendaItems.isEmpty)
                const Text(
                  "No agenda items added yet.",
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...agendaItems.map((item) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${item["item_order"] ?? "-"} . ${item["item_title"] ?? "Untitled item"}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if ((item["discussion_notes"] ?? "")
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text("Discussion: ${item["discussion_notes"]}"),
                          ],
                          if ((item["resolution"] ?? "")
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text("Resolution: ${item["resolution"]}"),
                          ],
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),

              if (canManage)
                ElevatedButton.icon(
                  icon: const Icon(Icons.list),
                  label: const Text("Edit Agenda"),
                  onPressed: () =>
                      _editAgenda(existingAgendaItems: agendaItems),
                ),

              const SizedBox(height: 24),

              const Text(
                "Action Items",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: "Total",
                      value: totalTasks.toString(),
                      icon: Icons.task_alt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: "Completed",
                      value: completedTasks.toString(),
                      icon: Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: "Pending",
                      value: pendingTasks.toString(),
                      icon: Icons.pending_actions,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (actionItems.isEmpty)
                const Text(
                  "No action items added yet.",
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...actionItems.map((item) {
                  final assignee = item["assignee"] as Map<String, dynamic>?;
                  final assigneeName =
                      assignee?["name"]?.toString() ?? "Unassigned";
                  final status = (item["status"] ?? "pending").toString();
                  final completed = status == "completed";

                  return Opacity(
                    opacity: completed ? 0.8 : 1,
                    child: Card(
                      color: completed ? const Color(0xFFF1F8E9) : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item["task_title"]?.toString() ??
                                        "Untitled task",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      decoration: completed
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusBg(status),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    status.replaceAll("_", " "),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _statusText(status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if ((item["task_description"] ?? "")
                                .toString()
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(item["task_description"].toString()),
                            ],
                            const SizedBox(height: 6),
                            Text("Assigned to: $assigneeName"),
                            const SizedBox(height: 4),
                            Text("Due: ${item["due_date"] ?? "Not set"}"),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),

              if (canManage)
                ElevatedButton.icon(
                  icon: const Icon(Icons.task),
                  label: const Text("Manage Action Items"),
                  onPressed: () => _editActionItems(
                    existingActionItems: actionItems,
                    members: members,
                    agendaItems: agendaItems,
                  ),
                ),

              const SizedBox(height: 24),

              const Text(
                "Minutes",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    displayedMinutes,
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (canManage)
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit_document),
                  label: const Text("Edit & Save Minutes"),
                  onPressed: () => _editMinutes(
                    meeting: meeting,
                    attendance: attendance,
                    agendaItems: agendaItems,
                    actionItems: actionItems,
                  ),
                ),

              const SizedBox(height: 10),

              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Export Minutes to PDF"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _exportMinutesPdf(
                  meeting: meeting,
                  attendance: attendance,
                  agendaItems: agendaItems,
                  actionItems: actionItems,
                ),
              ),

              const SizedBox(height: 20),

              if (canManage && isDraft)
                ElevatedButton.icon(
                  icon: const Icon(Icons.publish),
                  label: const Text("Publish Meeting"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await SupabaseService.publishMeeting(
                      meetingId: widget.meetingId,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Meeting published ✅")),
                      );
                    }

                    _load();
                  },
                ),

              if (canManage && isPublished && meeting["approved"] != true) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text("Move Back to Draft"),
                  onPressed: () async {
                    await SupabaseService.revertMeetingToDraft(
                      meetingId: widget.meetingId,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Meeting moved back to draft ✅"),
                        ),
                      );
                    }

                    _load();
                  },
                ),
              ],

              const SizedBox(height: 12),

              if (canManage && isDraft)
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    "Delete Draft Meeting",
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Delete draft meeting?"),
                        content: const Text(
                          "This will permanently delete the meeting and its related attendance, agenda items, action items, and minutes.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text("Delete"),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true) return;

                    await SupabaseService.deleteMeetingSafe(
                      meetingId: widget.meetingId,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Draft meeting deleted ✅"),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                ),

              if (canManage && !isDraft) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text("Archive Meeting"),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Archive meeting?"),
                        content: const Text(
                          "This meeting will be hidden from the main meetings list but kept in the database.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Archive"),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true) return;

                    await SupabaseService.archiveMeeting(
                      meetingId: widget.meetingId,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Meeting archived ✅")),
                      );
                      Navigator.pop(context);
                    }
                  },
                ),
              ],

              const SizedBox(height: 20),

              if (isChairperson && meeting["approved"] != true)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _approveMeeting,
                  child: const Text("Approve Meeting"),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? "Not set",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;

  const _StatusChip({
    required this.label,
    required this.background,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: textColor,
        ),
      ),
    );
  }
}

class _EditMeetingInfoSheet extends StatefulWidget {
  final Map<String, dynamic> meeting;
  final List<Map<String, dynamic>> members;

  const _EditMeetingInfoSheet({required this.meeting, required this.members});

  @override
  State<_EditMeetingInfoSheet> createState() => _EditMeetingInfoSheetState();
}

class _EditMeetingInfoSheetState extends State<_EditMeetingInfoSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _venueCtrl;
  late final TextEditingController _startTimeCtrl;
  late final TextEditingController _endTimeCtrl;

  DateTime? _meetingDate;
  String? _secretaryId;
  String? _chairpersonId;

  @override
  void initState() {
    super.initState();

    _titleCtrl = TextEditingController(
      text: (widget.meeting['title'] ?? '').toString(),
    );
    _venueCtrl = TextEditingController(
      text: (widget.meeting['venue'] ?? '').toString(),
    );
    _startTimeCtrl = TextEditingController(
      text: (widget.meeting['start_time'] ?? '').toString(),
    );
    _endTimeCtrl = TextEditingController(
      text: (widget.meeting['end_time'] ?? '').toString(),
    );

    final rawDate = widget.meeting['meeting_date'];
    if (rawDate != null) {
      _meetingDate = DateTime.tryParse(rawDate.toString());
    }

    _secretaryId = widget.meeting['secretary_id']?.toString();
    _chairpersonId = widget.meeting['chairperson_id']?.toString();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _venueCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Start time must be later than the current time."),
          ),
        );
        return;
      }
    }

    if (isEndTime && _startTimeCtrl.text.trim().isNotEmpty) {
      final valid = _isEndAfterStart(_startTimeCtrl.text.trim(), selected);
      if (!valid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("End time must be later than start time."),
          ),
        );
        return;
      }
    }

    setState(() {
      controller.text = selected;
    });
  }

  void _submit() {
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

    Navigator.pop(context, {
      'title': _titleCtrl.text.trim(),
      'meeting_date': _meetingDate!,
      'start_time': start.isEmpty ? null : start,
      'end_time': end.isEmpty ? null : end,
      'venue': _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
      'secretary_id': _secretaryId,
      'chairperson_id': _chairpersonId,
    });
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
        8,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              "Edit Meeting Info",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
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
                onPressed: _submit,
                icon: const Icon(Icons.save),
                label: const Text("Update Meeting"),
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

class _AttendanceSheet extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> existingAttendance;
  final String currentMemberId;

  const _AttendanceSheet({
    required this.members,
    required this.existingAttendance,
    required this.currentMemberId,
  });

  @override
  State<_AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends State<_AttendanceSheet> {
  late List<Map<String, dynamic>> rows;

  @override
  void initState() {
    super.initState();

    rows = widget.members.map((member) {
      Map<String, dynamic>? existing;

      for (final item in widget.existingAttendance) {
        if ((item["member_id"] ?? "").toString() ==
            (member["id"] ?? "").toString()) {
          existing = item;
          break;
        }
      }

      return {
        "member_id": member["id"].toString(),
        "name": (member["name"] ?? "Member").toString(),
        "attendance_status": (existing?["attendance_status"] ?? "present")
            .toString(),
        "remarks": (existing?["remarks"] ?? "").toString(),
        "recorded_by": widget.currentMemberId,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              "Record Attendance",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ...rows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        row["name"].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: row["attendance_status"].toString(),
                      decoration: const InputDecoration(
                        labelText: "Attendance Status",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "present",
                          child: Text("Present"),
                        ),
                        DropdownMenuItem(
                          value: "absent_with_apology",
                          child: Text("Absent with apology"),
                        ),
                        DropdownMenuItem(
                          value: "absent",
                          child: Text("Absent"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          rows[index]["attendance_status"] = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: row["remarks"].toString(),
                      decoration: const InputDecoration(
                        labelText: "Remarks",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        rows[index]["remarks"] = value;
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, rows),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Save Attendance"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaItemsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> existingItems;

  const _AgendaItemsSheet({required this.existingItems});

  @override
  State<_AgendaItemsSheet> createState() => _AgendaItemsSheetState();
}

class _AgendaItemsSheetState extends State<_AgendaItemsSheet> {
  late List<Map<String, dynamic>> rows;

  @override
  void initState() {
    super.initState();

    rows = widget.existingItems.isEmpty
        ? [
            {
              "item_order": 1,
              "item_title": "",
              "discussion_notes": "",
              "resolution": "",
            },
          ]
        : widget.existingItems.map((item) {
            return {
              "item_order": item["item_order"] ?? 1,
              "item_title": (item["item_title"] ?? "").toString(),
              "discussion_notes": (item["discussion_notes"] ?? "").toString(),
              "resolution": (item["resolution"] ?? "").toString(),
            };
          }).toList();
  }

  void _addItem() {
    setState(() {
      rows.add({
        "item_order": rows.length + 1,
        "item_title": "",
        "discussion_notes": "",
        "resolution": "",
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              "Edit Agenda Items",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ...rows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Agenda Item ${index + 1}",
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: rows.length == 1
                              ? null
                              : () {
                                  setState(() => rows.removeAt(index));
                                },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    TextFormField(
                      initialValue: row["item_order"].toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Order",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        rows[index]["item_order"] =
                            int.tryParse(value) ?? (index + 1);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: row["item_title"].toString(),
                      decoration: const InputDecoration(
                        labelText: "Item title",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        rows[index]["item_title"] = value;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: row["discussion_notes"].toString(),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Discussion notes",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        rows[index]["discussion_notes"] = value;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: row["resolution"].toString(),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Resolution",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        rows[index]["resolution"] = value;
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Item"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final cleaned = rows.where((row) {
                    return (row["item_title"] ?? "")
                        .toString()
                        .trim()
                        .isNotEmpty;
                  }).toList();

                  Navigator.pop(context, cleaned);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Save Agenda Items"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItemsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> existingItems;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> agendaItems;

  const _ActionItemsSheet({
    required this.existingItems,
    required this.members,
    required this.agendaItems,
  });

  @override
  State<_ActionItemsSheet> createState() => _ActionItemsSheetState();
}

class _ActionItemsSheetState extends State<_ActionItemsSheet> {
  late List<Map<String, dynamic>> rows;

  @override
  void initState() {
    super.initState();

    rows = widget.existingItems.isEmpty
        ? [
            {
              "agenda_item_id": "",
              "task_title": "",
              "task_description": "",
              "assigned_to": null,
              "due_date": null,
              "status": "pending",
            },
          ]
        : widget.existingItems.map((item) {
            return {
              "agenda_item_id": item["agenda_item_id"]?.toString() ?? "",
              "task_title": (item["task_title"] ?? "").toString(),
              "task_description": (item["task_description"] ?? "").toString(),
              "assigned_to": item["assigned_to"]?.toString(),
              "due_date": item["due_date"],
              "status": (item["status"] ?? "pending").toString(),
            };
          }).toList();
  }

  void _addItem() {
    setState(() {
      rows.add({
        "agenda_item_id": "",
        "task_title": "",
        "task_description": "",
        "assigned_to": null,
        "due_date": null,
        "status": "pending",
      });
    });
  }

  Future<void> _pickDate(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (picked != null) {
      setState(() {
        rows[index]["due_date"] =
            "${picked.year.toString().padLeft(4, '0')}-"
            "${picked.month.toString().padLeft(2, '0')}-"
            "${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              "Manage Action Items",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ...rows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Task ${index + 1}",
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: rows.length == 1
                              ? null
                              : () => setState(() => rows.removeAt(index)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      value: row["agenda_item_id"].toString(),
                      decoration: const InputDecoration(
                        labelText: "Linked agenda item",
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: "",
                          child: Text("None"),
                        ),
                        ...widget.agendaItems.map((agenda) {
                          return DropdownMenuItem<String>(
                            value: agenda["id"].toString(),
                            child: Text(
                              "${agenda["item_order"]}. ${agenda["item_title"]}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          rows[index]["agenda_item_id"] = value ?? "";
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: row["task_title"].toString(),
                      decoration: const InputDecoration(
                        labelText: "Task title",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        rows[index]["task_title"] = value;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: row["task_description"].toString(),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Task description",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        rows[index]["task_description"] = value;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: row["assigned_to"]?.toString(),
                      decoration: const InputDecoration(
                        labelText: "Assigned to",
                        border: OutlineInputBorder(),
                      ),
                      items: widget.members.map((member) {
                        return DropdownMenuItem<String>(
                          value: member["id"].toString(),
                          child: Text(
                            "${member["name"]} (${member["role"] ?? "Member"})",
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          rows[index]["assigned_to"] = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _pickDate(index),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Due date",
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          (row["due_date"] ?? "Select due date").toString(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: row["status"].toString(),
                      decoration: const InputDecoration(
                        labelText: "Status",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "pending",
                          child: Text("Pending"),
                        ),
                        DropdownMenuItem(
                          value: "in_progress",
                          child: Text("In Progress"),
                        ),
                        DropdownMenuItem(
                          value: "completed",
                          child: Text("Completed"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          rows[index]["status"] = value;
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Task"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final cleaned = rows
                      .where((row) {
                        return (row["task_title"] ?? "")
                            .toString()
                            .trim()
                            .isNotEmpty;
                      })
                      .map((row) {
                        final copy = Map<String, dynamic>.from(row);
                        if ((copy["agenda_item_id"] ?? "") == "") {
                          copy["agenda_item_id"] = null;
                        }
                        return copy;
                      })
                      .toList();

                  Navigator.pop(context, cleaned);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Save Action Items"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinutesEditorSheet extends StatefulWidget {
  final String initialMinutes;
  final String initialAob;

  const _MinutesEditorSheet({
    required this.initialMinutes,
    required this.initialAob,
  });

  @override
  State<_MinutesEditorSheet> createState() => _MinutesEditorSheetState();
}

class _MinutesEditorSheetState extends State<_MinutesEditorSheet> {
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _aobCtrl;

  @override
  void initState() {
    super.initState();
    _minutesCtrl = TextEditingController(text: widget.initialMinutes);
    _aobCtrl = TextEditingController(text: widget.initialAob);
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    _aobCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              "Edit Minutes",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _minutesCtrl,
              maxLines: 14,
              decoration: const InputDecoration(
                labelText: "Minutes",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aobCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Any Other Business",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    "minutes_text": _minutesCtrl.text.trim(),
                    "any_other_business": _aobCtrl.text.trim(),
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Save Minutes"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
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
