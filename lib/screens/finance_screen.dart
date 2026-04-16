import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';

class FinanceScreen extends StatefulWidget {
  final String chamaId;
  final String? currentMemberRole;
  final String? currentMemberId;

  const FinanceScreen({
    super.key,
    required this.chamaId,
    this.currentMemberRole,
    this.currentMemberId,
  });

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  bool _loading = true;
  String? _error;

  double _balance = 0.0;
  Map<String, dynamic>? _goal;
  double _totalContributed = 0.0;
  double _overallProgress = 0.0;
  double _perMemberTotal = 0.0;
  double _perMemberMonthly = 0.0;
  double _myContributed = 0.0;
  double _myProgress = 0.0;
  String _frequency = 'monthly';

  Map<String, dynamic>? _myLoan;

  List<Map<String, dynamic>> _fully = [];
  List<Map<String, dynamic>> _notFully = [];
  List<Map<String, dynamic>> _trend = [];
  List<Map<String, dynamic>> _loanRequests = [];

  bool get _isTreasurer =>
      SupabaseService.isTreasurerRole(widget.currentMemberRole);

  bool get _isChairperson =>
      SupabaseService.isChairpersonRole(widget.currentMemberRole);

  bool get _canManageFinance => _isTreasurer || _isChairperson;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dash = await SupabaseService.getFinanceDashboardV2(
        chamaId: widget.chamaId,
        currentMemberId: widget.currentMemberId,
      );

      final loans = await SupabaseService.fetchLoanRequests(
        chamaId: widget.chamaId,
      );

      setState(() {
        _balance = (dash['balance'] as num?)?.toDouble() ?? 0.0;
        _goal = dash['goal'] == null
            ? null
            : Map<String, dynamic>.from(dash['goal']);
        _frequency = (dash['contributionFrequency'] ?? 'monthly').toString();
        _totalContributed =
            (dash['totalContributed'] as num?)?.toDouble() ?? 0.0;
        _overallProgress =
            ((dash['overallProgress'] as num?)?.toDouble() ?? 0.0).clamp(
              0.0,
              1.0,
            );
        _perMemberTotal = (dash['perMemberTotal'] as num?)?.toDouble() ?? 0.0;
        _perMemberMonthly = calculateExpected(
          totalGoal: (_goal?['total_goal_amount'] as num?)?.toDouble() ?? 0,
          members: (_goal?['member_count_snapshot'] as num?)?.toInt() ?? 1,
          months: (_goal?['duration_months'] as num?)?.toInt() ?? 1,
          frequency: _frequency,
        );
        _myContributed = (dash['myContributed'] as num?)?.toDouble() ?? 0.0;
        _myProgress = ((dash['myProgress'] as num?)?.toDouble() ?? 0.0).clamp(
          0.0,
          1.0,
        );

        _myLoan = dash['myLoan'] == null
            ? null
            : Map<String, dynamic>.from(dash['myLoan']);

        _fully = List<Map<String, dynamic>>.from(dash['fully'] ?? const []);
        _notFully = List<Map<String, dynamic>>.from(
          dash['notFully'] ?? const [],
        );
        _trend = List<Map<String, dynamic>>.from(dash['trend'] ?? const []);
        _loanRequests = List<Map<String, dynamic>>.from(loans);

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _showCreateGoalDialog() async {
    final amountCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    String selectedFrequency = 'monthly';
    DateTime selectedStartDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text('Create Finance Goal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Total goal amount (KSh)',
                        hintText: 'e.g. 20000',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration in months',
                        hintText: 'e.g. 10',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Contribution Frequency',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setInnerState(() {
                            selectedFrequency = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start date'),
                      subtitle: Text(_dateLabel(selectedStartDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedStartDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setInnerState(() {
                            selectedStartDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final totalGoalAmount = num.tryParse(
                            amountCtrl.text.trim(),
                          );
                          final durationMonths = int.tryParse(
                            durationCtrl.text.trim(),
                          );

                          if (totalGoalAmount == null || totalGoalAmount <= 0) {
                            _showSnack(
                              'Enter a valid total goal amount.',
                              isError: true,
                            );
                            return;
                          }

                          if (durationMonths == null || durationMonths <= 0) {
                            _showSnack(
                              'Enter a valid duration in months.',
                              isError: true,
                            );
                            return;
                          }

                          if (widget.currentMemberId == null ||
                              widget.currentMemberId!.isEmpty) {
                            _showSnack(
                              'Current member id is missing.',
                              isError: true,
                            );
                            return;
                          }

                          setInnerState(() {
                            saving = true;
                          });

                          try {
                            await SupabaseService.createFinanceGoal(
                              chamaId: widget.chamaId,
                              totalGoalAmount: totalGoalAmount,
                              durationMonths: durationMonths,
                              startDate: selectedStartDate,
                              createdBy: widget.currentMemberId!,
                              contributionFrequency: selectedFrequency,
                            );

                            if (!mounted) return;

                            Navigator.pop(dialogContext);
                            _showSnack('Finance goal created successfully.');
                            await _load();
                          } catch (e) {
                            if (!mounted) return;

                            setInnerState(() {
                              saving = false;
                            });

                            _showSnack(
                              'Failed to create goal: $e',
                              isError: true,
                            );
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Create Goal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showRecordContributionDialog() async {
    if (_goal == null) {
      _showSnack('Create a finance goal first.', isError: true);
      return;
    }

    final members = await SupabaseService.fetchMembers(chamaId: widget.chamaId);
    if (members.isEmpty) {
      _showSnack('No members found.', isError: true);
      return;
    }

    String? selectedMemberId = members.first['id']?.toString();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text('Record Contribution'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedMemberId,
                      decoration: const InputDecoration(labelText: 'Member'),
                      items: members.map((m) {
                        final id = m['id'].toString();
                        final name = (m['name'] ?? 'Unnamed').toString();
                        return DropdownMenuItem(value: id, child: Text(name));
                      }).toList(),
                      onChanged: (value) {
                        setInnerState(() {
                          selectedMemberId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount (KSh)',
                        hintText: 'e.g. 500',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Payment date'),
                      subtitle: Text(_dateLabel(selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setInnerState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final amount = num.tryParse(amountCtrl.text.trim());

                          if (selectedMemberId == null ||
                              selectedMemberId!.isEmpty) {
                            _showSnack(
                              'Please select a member.',
                              isError: true,
                            );
                            return;
                          }

                          if (amount == null || amount <= 0) {
                            _showSnack('Enter a valid amount.', isError: true);
                            return;
                          }

                          if (widget.currentMemberId == null ||
                              widget.currentMemberId!.isEmpty) {
                            _showSnack(
                              'Current member id is missing.',
                              isError: true,
                            );
                            return;
                          }

                          setInnerState(() {
                            saving = true;
                          });

                          try {
                            await SupabaseService.recordFinanceContribution(
                              chamaId: widget.chamaId,
                              goalId: _goal!['id'].toString(),
                              memberId: selectedMemberId!,
                              amount: amount,
                              recordedBy: widget.currentMemberId!,
                              note: noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                              paidAt: selectedDate,
                            );

                            if (mounted) Navigator.pop(context);
                            _showSnack('Contribution recorded successfully.');
                            await _load();
                          } catch (e) {
                            _showSnack(
                              'Failed to record contribution: $e',
                              isError: true,
                            );
                          } finally {
                            if (mounted) {
                              setInnerState(() {
                                saving = false;
                              });
                            }
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showRequestLoanDialog() async {
    if (widget.currentMemberId == null || widget.currentMemberId!.isEmpty) {
      _showSnack('Current member id is missing.', isError: true);
      return;
    }

    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text('Request Loan'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Requested amount (KSh)',
                        hintText: 'e.g. 3000',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Why do you need the loan?',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final amount = num.tryParse(amountCtrl.text.trim());

                          if (amount == null || amount <= 0) {
                            _showSnack(
                              'Enter a valid requested amount.',
                              isError: true,
                            );
                            return;
                          }

                          if (reasonCtrl.text.trim().isEmpty) {
                            _showSnack(
                              'Please provide a reason.',
                              isError: true,
                            );
                            return;
                          }

                          setInnerState(() {
                            saving = true;
                          });

                          try {
                            await SupabaseService.createLoanRequest(
                              chamaId: widget.chamaId,
                              memberId: widget.currentMemberId!,
                              goalId: _goal?['id']?.toString(),
                              requestedAmount: amount,
                              reason: reasonCtrl.text.trim(),
                            );

                            if (mounted) Navigator.pop(context);
                            _showSnack('Loan request submitted.');
                            await _load();
                          } catch (e) {
                            _showSnack(
                              'Failed to request loan: $e',
                              isError: true,
                            );
                          } finally {
                            if (mounted) {
                              setInnerState(() {
                                saving = false;
                              });
                            }
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showLoanDecisionDialog(Map<String, dynamic> loan) async {
    final approvedAmountCtrl = TextEditingController(
      text: ((loan['requested_amount'] as num?)?.toDouble() ?? 0.0)
          .toStringAsFixed(0),
    );
    final decisionNoteCtrl = TextEditingController(
      text: (loan['decision_note'] ?? '').toString(),
    );

    String selectedStatus =
        (loan['status'] ?? 'pending').toString().toLowerCase() == 'rejected'
        ? 'rejected'
        : 'approved';

    DateTime? dueDate = loan['due_date'] == null
        ? DateTime.now().add(const Duration(days: 30))
        : DateTime.tryParse(loan['due_date'].toString());

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text('Review Loan Request'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Decision'),
                      items: const [
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approve'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Reject'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setInnerState(() {
                            selectedStatus = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: approvedAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Approved amount (KSh)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: decisionNoteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Decision note (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Due date'),
                      subtitle: Text(
                        dueDate == null ? 'Not set' : _dateLabel(dueDate!),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate ?? DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setInnerState(() {
                            dueDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (widget.currentMemberId == null ||
                              widget.currentMemberId!.isEmpty) {
                            _showSnack(
                              'Current member id is missing.',
                              isError: true,
                            );
                            return;
                          }

                          final approvedAmount = num.tryParse(
                            approvedAmountCtrl.text.trim(),
                          );

                          if (selectedStatus == 'approved' &&
                              (approvedAmount == null || approvedAmount <= 0)) {
                            _showSnack(
                              'Enter a valid approved amount.',
                              isError: true,
                            );
                            return;
                          }

                          setInnerState(() {
                            saving = true;
                          });

                          try {
                            await SupabaseService.updateLoanRequestStatus(
                              loanRequestId: loan['id'].toString(),
                              status: selectedStatus,
                              approvedBy: widget.currentMemberId!,
                              approvedAmount: selectedStatus == 'approved'
                                  ? approvedAmount
                                  : null,
                              dueDate: selectedStatus == 'approved'
                                  ? dueDate
                                  : null,
                              decisionNote: decisionNoteCtrl.text.trim().isEmpty
                                  ? null
                                  : decisionNoteCtrl.text.trim(),
                            );

                            if (mounted) Navigator.pop(context);
                            _showSnack('Loan request updated.');
                            await _load();
                          } catch (e) {
                            _showSnack(
                              'Failed to update loan request: $e',
                              isError: true,
                            );
                          } finally {
                            if (mounted) {
                              setInnerState(() {
                                saving = false;
                              });
                            }
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showRepaymentDialog(Map<String, dynamic> loan) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime paidAt = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text('Record Loan Repayment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount paid (KSh)',
                        hintText: 'e.g. 1000',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Payment date'),
                      subtitle: Text(_dateLabel(paidAt)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: paidAt,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setInnerState(() {
                            paidAt = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final amount = num.tryParse(amountCtrl.text.trim());

                          if (amount == null || amount <= 0) {
                            _showSnack(
                              'Enter a valid repayment amount.',
                              isError: true,
                            );
                            return;
                          }

                          if (widget.currentMemberId == null ||
                              widget.currentMemberId!.isEmpty) {
                            _showSnack(
                              'Current member id is missing.',
                              isError: true,
                            );
                            return;
                          }

                          final memberId = (loan['member_id'] ?? '').toString();
                          if (memberId.isEmpty) {
                            _showSnack(
                              'Loan member id is missing.',
                              isError: true,
                            );
                            return;
                          }

                          setInnerState(() {
                            saving = true;
                          });

                          try {
                            await SupabaseService.recordLoanRepayment(
                              loanRequestId: loan['id'].toString(),
                              chamaId: widget.chamaId,
                              memberId: memberId,
                              amountPaid: amount,
                              recordedBy: widget.currentMemberId!,
                              note: noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                              paidAt: paidAt,
                            );

                            if (mounted) Navigator.pop(context);
                            _showSnack('Repayment recorded.');
                            await _load();
                          } catch (e) {
                            _showSnack(
                              'Failed to record repayment: $e',
                              isError: true,
                            );
                          } finally {
                            if (mounted) {
                              setInnerState(() {
                                saving = false;
                              });
                            }
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _loanRequests
        .where((e) => (e['status'] ?? '').toString().toLowerCase() == 'pending')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Finance',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: _canManageFinance
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_goal == null)
                  FloatingActionButton.extended(
                    heroTag: 'create_goal',
                    backgroundColor: const Color(0xFF9CCC65),
                    foregroundColor: Colors.black87,
                    onPressed: _showCreateGoalDialog,
                    icon: const Icon(Icons.flag),
                    label: const Text('Create Goal'),
                  ),
                if (_goal != null)
                  FloatingActionButton.extended(
                    heroTag: 'record_contribution',
                    backgroundColor: const Color(0xFF9CCC65),
                    foregroundColor: Colors.black87,
                    onPressed: _showRecordContributionDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Record Contribution'),
                  ),
              ],
            )
          : null,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Finance Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _goal == null
                        ? 'Track your chama balance, goals, loans and contributions'
                        : 'Manage contributions, progress, charts and loan activity',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              decoration: const BoxDecoration(
                color: Color(0xFFF4F5F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error: $_error',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 90),
                        children: [
                          _balanceCard(),
                          const SizedBox(height: 12),
                          if (_goal == null) ...[
                            _emptyGoalCard(),
                            const SizedBox(height: 12),
                            _presentationQuickStatsCard(),
                            const SizedBox(height: 12),
                            if (widget.currentMemberId != null &&
                                widget.currentMemberId!.isNotEmpty)
                              _loanRequestCard(),
                            const SizedBox(height: 12),
                            if (widget.currentMemberId != null &&
                                widget.currentMemberId!.isNotEmpty)
                              _myLoanCard(),
                            const SizedBox(height: 12),
                            if (_canManageFinance) _presentationActionsCard(),
                          ] else ...[
                            _goalSummaryCard(),
                            const SizedBox(height: 12),
                            _chartsRow(),
                            const SizedBox(height: 12),
                            _memberBarChartCard(),
                            const SizedBox(height: 12),
                            _overallProgressCard(),
                            const SizedBox(height: 12),
                            _trendLineChartCard(),
                            const SizedBox(height: 12),
                            _memberSection(
                              title: 'Fully contributed',
                              items: _fully,
                              emptyText: 'No one has fully contributed yet.',
                              showRemaining: false,
                            ),
                            const SizedBox(height: 12),
                            _memberSection(
                              title: 'Not fully contributed',
                              items: _notFully,
                              emptyText: 'Everyone has fully contributed 🎉',
                              showRemaining: true,
                            ),
                            const SizedBox(height: 12),
                            if (widget.currentMemberId != null &&
                                widget.currentMemberId!.isNotEmpty)
                              _loanRequestCard(),
                            const SizedBox(height: 12),
                            if (widget.currentMemberId != null &&
                                widget.currentMemberId!.isNotEmpty)
                              _myLoanCard(),
                            const SizedBox(height: 12),
                            if (_canManageFinance)
                              _loanManagementCard(pendingCount: pendingCount),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard() {
    return _statCard(
      title: 'Balance',
      value: 'KSh ${_fmt(_balance)}',
      subtitle: 'Current chama balance',
      icon: Icons.account_balance_wallet_outlined,
    );
  }

  Widget _emptyGoalCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.flag_outlined, size: 38),
            const SizedBox(height: 12),
            Text(
              'No active finance goal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _canManageFinance
                  ? 'Create a goal so the app can calculate each member’s share, progress, and overall contribution growth.'
                  : 'The treasurer or chairperson needs to create a finance goal first.',
              textAlign: TextAlign.center,
            ),
            if (_canManageFinance) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showCreateGoalDialog,
                icon: const Icon(Icons.flag),
                label: const Text('Create Goal'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _presentationQuickStatsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finance Overview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniStatTile(
                    'Members Paid',
                    '${_fully.length}',
                    Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStatTile(
                    'Pending Members',
                    '${_notFully.length}',
                    Icons.pending_actions_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _miniStatTile(
                    'Loan Requests',
                    '${_loanRequests.length}',
                    Icons.request_quote_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStatTile(
                    'Balance',
                    'KSh ${_fmt(_balance)}',
                    Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _presentationActionsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _showCreateGoalDialog,
                  icon: const Icon(Icons.flag),
                  label: const Text('Create Goal'),
                ),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStatTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _goalSummaryCard() {
    final totalGoal = (_goal?['total_goal_amount'] as num?)?.toDouble() ?? 0.0;
    final durationMonths = (_goal?['duration_months'] as num?)?.toInt() ?? 0;
    final memberCount = (_goal?['member_count_snapshot'] as num?)?.toInt() ?? 0;
    final startDate = _goal?['start_date']?.toString();
    final endDate = _goal?['end_date']?.toString();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goal Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _infoRow('Goal amount', 'KSh ${_fmt(totalGoal)}'),
            _infoRow('Duration', '$durationMonths month(s)'),
            _infoRow('Members', '$memberCount'),
            _infoRow('Per member total', 'KSh ${_fmt(_perMemberTotal)}'),
            _infoRow(_frequencyLabel(), 'KSh ${_fmt(_perMemberMonthly)}'),
            if (startDate != null) _infoRow('Start date', startDate),
            if (endDate != null) _infoRow('End date', endDate),
          ],
        ),
      ),
    );
  }

  Widget _chartsRow() {
    final hasMember =
        widget.currentMemberId != null && widget.currentMemberId!.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: _progressDonutCard(
            title: 'Overall Goal',
            progress: _overallProgress,
            mainValue:
                'KSh ${_fmt(_totalContributed)} / ${_fmt((_goal?['total_goal_amount'] as num?)?.toDouble() ?? 0)}',
            subValue: '${(_overallProgress * 100).toStringAsFixed(1)}%',
          ),
        ),
        if (hasMember) const SizedBox(width: 12),
        if (hasMember)
          Expanded(
            child: _progressDonutCard(
              title: 'My Progress',
              progress: _myProgress,
              mainValue:
                  'KSh ${_fmt(_myContributed)} / ${_fmt(_perMemberTotal)}',
              subValue: '${(_myProgress * 100).toStringAsFixed(1)}%',
            ),
          ),
      ],
    );
  }

  Widget _progressDonutCard({
    required String title,
    required double progress,
    required String mainValue,
    required String subValue,
  }) {
    final safeProgress = progress.clamp(0.0, 1.0);
    final remaining = 1 - safeProgress;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 42,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                      sections: [
                        PieChartSectionData(
                          value: safeProgress <= 0 ? 0.01 : safeProgress * 100,
                          radius: 16,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: remaining <= 0 ? 0.01 : remaining * 100,
                          radius: 16,
                          showTitle: false,
                          color: Colors.black12,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(safeProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Progress',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              mainValue,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(subValue, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _overallProgressCard() {
    final totalGoal = (_goal?['total_goal_amount'] as num?)?.toDouble() ?? 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _overallProgress.clamp(0.0, 1.0),
              minHeight: 12,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 12),
            Text(
              'KSh ${_fmt(_totalContributed)} / KSh ${_fmt(totalGoal)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${(_overallProgress * 100).toStringAsFixed(1)}% of the goal achieved',
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendLineChartCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contribution Growth Graph',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'This graph compares cumulative actual contributions against cumulative expected progress.',
            ),
            const SizedBox(height: 16),
            if (_trend.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('No contribution trend data yet.')),
              )
            else
              SizedBox(
                height: 260,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (_trend.length - 1).toDouble(),
                    minY: 0,
                    maxY: _maxTrendY(),
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: true),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= _trend.length) {
                              return const SizedBox.shrink();
                            }
                            final label = (_trend[index]['label'] ?? '')
                                .toString()
                                .split(' ')
                                .first;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 46,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              _compactMoney(value),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        barWidth: 4,
                        dotData: const FlDotData(show: true),
                        spots: List.generate(_trend.length, (index) {
                          final y =
                              (_trend[index]['cumulative_actual'] as num?)
                                  ?.toDouble() ??
                              0.0;
                          return FlSpot(index.toDouble(), y);
                        }),
                      ),
                      LineChartBarData(
                        isCurved: true,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        dashArray: [8, 4],
                        spots: List.generate(_trend.length, (index) {
                          final y =
                              (_trend[index]['cumulative_expected'] as num?)
                                  ?.toDouble() ??
                              0.0;
                          return FlSpot(index.toDouble(), y);
                        }),
                        color: Colors.black54,
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final index = spot.x.toInt();
                            final label = (_trend[index]['label'] ?? '')
                                .toString();

                            final actualY =
                                (_trend[index]['cumulative_actual'] as num?)
                                    ?.toDouble() ??
                                0.0;
                            final isActual = (spot.y - actualY).abs() < 0.001;

                            final seriesName = isActual ? 'Actual' : 'Expected';

                            return LineTooltipItem(
                              '$label\n$seriesName: KSh ${_fmt(spot.y)}',
                              const TextStyle(color: Colors.white),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            if (_trend.isNotEmpty) ...[
              const SizedBox(height: 16),
              _chartLegend(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chartLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: const [
        _LegendItem(label: 'Actual cumulative', color: null),
        _LegendItem(label: 'Expected cumulative', color: Colors.black54),
      ],
    );
  }

  Widget _memberSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required String emptyText,
    required bool showRemaining,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: items.isEmpty
                ? Text(emptyText)
                : Column(
                    children: items.map((m) {
                      final name = (m['name'] ?? '').toString();
                      final paid = (m['paid'] as num?)?.toDouble() ?? 0.0;
                      final expected =
                          (m['expected'] as num?)?.toDouble() ?? 0.0;
                      final remaining =
                          (m['remaining'] as num?)?.toDouble() ?? 0.0;
                      final progress =
                          ((m['progress'] as num?)?.toDouble() ?? 0.0).clamp(
                            0.0,
                            1.0,
                          );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(name),
                              subtitle: Text(
                                'KSh ${_fmt(paid)} / ${_fmt(expected)}',
                              ),
                              trailing: showRemaining
                                  ? Text('Remain: ${_fmt(remaining)}')
                                  : const Icon(Icons.check_circle),
                            ),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _loanRequestCard() {
    final hasPending = _loanRequests.any(
      (e) =>
          (e['member_id'] ?? '').toString() == widget.currentMemberId &&
          (e['status'] ?? '').toString().toLowerCase() == 'pending',
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loan Requests',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Request a loan and track its approval or repayment status here.',
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: hasPending ? null : _showRequestLoanDialog,
              icon: const Icon(Icons.request_quote),
              label: Text(
                hasPending ? 'Pending Request Exists' : 'Request Loan',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _myLoanCard() {
    if (_myLoan == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'My Loan Status',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('You have no recent loan request.'),
            ],
          ),
        ),
      );
    }

    final requested = (_myLoan!['requested_amount'] as num?)?.toDouble() ?? 0.0;
    final approved = (_myLoan!['approved_amount'] as num?)?.toDouble() ?? 0.0;
    final balance = (_myLoan!['balance'] as num?)?.toDouble() ?? 0.0;
    final status = (_myLoan!['status'] ?? 'unknown').toString();
    final dueDate = _myLoan!['due_date']?.toString();
    final reason = (_myLoan!['reason'] ?? '').toString();
    final decisionNote = (_myLoan!['decision_note'] ?? '').toString();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Loan Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [Chip(label: Text('Status: ${status.toUpperCase()}'))],
            ),
            const SizedBox(height: 12),
            _infoRow('Requested', 'KSh ${_fmt(requested)}'),
            _infoRow('Approved', 'KSh ${_fmt(approved)}'),
            _infoRow('Balance', 'KSh ${_fmt(balance)}'),
            if (dueDate != null) _infoRow('Due date', dueDate),
            if (reason.isNotEmpty) _infoRow('Reason', reason),
            if (decisionNote.isNotEmpty)
              _infoRow('Decision note', decisionNote),
          ],
        ),
      ),
    );
  }

  Widget _memberBarChartCard() {
    final members = [..._fully, ..._notFully];

    if (members.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No member contribution data yet.'),
        ),
      );
    }

    final sortedMembers = [...members];
    sortedMembers.sort((a, b) {
      final aPaid = (a['paid'] as num?)?.toDouble() ?? 0.0;
      final bPaid = (b['paid'] as num?)?.toDouble() ?? 0.0;
      return bPaid.compareTo(aPaid);
    });

    final maxY = sortedMembers.fold<double>(0.0, (prev, m) {
      final paid = (m['paid'] as num?)?.toDouble() ?? 0.0;
      final expected = (m['expected'] as num?)?.toDouble() ?? 0.0;
      final localMax = paid > expected ? paid : expected;
      return localMax > prev ? localMax : prev;
    });

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Member Contribution Comparison',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'This chart compares how much each member has contributed against their expected total.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  maxY: maxY <= 0 ? 1000 : maxY * 1.2,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final member = sortedMembers[group.x.toInt()];
                        final name = (member['name'] ?? '').toString();
                        final paid =
                            (member['paid'] as num?)?.toDouble() ?? 0.0;
                        final expected =
                            (member['expected'] as num?)?.toDouble() ?? 0.0;

                        final label = rodIndex == 0 ? 'Paid' : 'Expected';

                        return BarTooltipItem(
                          '$name\n$label: KSh ${_fmt(rod.toY)}\nPaid: KSh ${_fmt(paid)} / Expected: KSh ${_fmt(expected)}',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _compactMoney(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= sortedMembers.length) {
                            return const SizedBox.shrink();
                          }

                          final name = (sortedMembers[index]['name'] ?? '')
                              .toString();
                          final shortName = name.isEmpty
                              ? ''
                              : name.split(' ').first.length > 6
                              ? name.split(' ').first.substring(0, 6)
                              : name.split(' ').first;

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              shortName,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(sortedMembers.length, (index) {
                    final member = sortedMembers[index];
                    final paid = (member['paid'] as num?)?.toDouble() ?? 0.0;
                    final expected =
                        (member['expected'] as num?)?.toDouble() ?? 0.0;

                    return BarChartGroupData(
                      x: index,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: paid,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: expected,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.black26,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: const [
                _LegendItem(label: 'Paid', color: null),
                _LegendItem(label: 'Expected', color: Colors.black26),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _loanManagementCard({required int pendingCount}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loan Management',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Total requests: ${_loanRequests.length} • Pending: $pendingCount',
            ),
            const SizedBox(height: 12),
            if (_loanRequests.isEmpty)
              const Text('No loan requests yet.')
            else
              Column(
                children: _loanRequests.map((loan) {
                  final member = loan['member'] as Map<String, dynamic>?;
                  final memberName = (member?['name'] ?? 'Member').toString();
                  final requested =
                      (loan['requested_amount'] as num?)?.toDouble() ?? 0.0;
                  final approved =
                      (loan['approved_amount'] as num?)?.toDouble() ?? 0.0;
                  final status = (loan['status'] ?? '')
                      .toString()
                      .toLowerCase();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(memberName),
                          subtitle: Text(
                            'Requested: KSh ${_fmt(requested)}'
                            '${approved > 0 ? ' • Approved: KSh ${_fmt(approved)}' : ''}',
                          ),
                          trailing: Chip(label: Text(status.toUpperCase())),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: status == 'pending'
                                    ? () => _showLoanDecisionDialog(loan)
                                    : null,
                                icon: const Icon(Icons.rule),
                                label: const Text('Review'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    status == 'approved' || status == 'repaid'
                                    ? () => _showRepaymentDialog(loan)
                                    : null,
                                icon: const Icon(Icons.payments),
                                label: const Text('Repayment'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }

  double _maxTrendY() {
    if (_trend.isEmpty) return 1000;

    double maxY = 0;
    for (final item in _trend) {
      final actual = (item['cumulative_actual'] as num?)?.toDouble() ?? 0.0;
      final expected = (item['cumulative_expected'] as num?)?.toDouble() ?? 0.0;
      if (actual > maxY) maxY = actual;
      if (expected > maxY) maxY = expected;
    }

    if (maxY <= 0) return 1000;
    return maxY * 1.2;
  }

  String _frequencyLabel() {
    switch (_frequency) {
      case 'daily':
        return 'Per member daily';
      case 'weekly':
        return 'Per member weekly';
      default:
        return 'Per member monthly';
    }
  }

  String _compactMoney(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  final NumberFormat _currencyFormatter = NumberFormat('#,##0');

  String _fmt(num value) {
    return _currencyFormatter.format(value);
  }

  String _dateLabel(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

double calculateExpected({
  required double totalGoal,
  required int members,
  required int months,
  required String frequency,
}) {
  final perMemberTotal = totalGoal / members;

  switch (frequency) {
    case 'daily':
      return perMemberTotal / (months * 30);
    case 'weekly':
      return perMemberTotal / (months * 4);
    default:
      return perMemberTotal / months;
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color? color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: displayColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
