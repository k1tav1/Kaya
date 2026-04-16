import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class SupabaseService {
  static final _db = Supabase.instance.client;

  // ==============================
  // INVITE CODE GENERATOR
  // ==============================

  static Future<String> generatePermanentInviteCode() async {
    final random = Random();

    while (true) {
      final number = random.nextInt(10000);
      final formatted = number.toString().padLeft(4, '0');
      final code = "KAYA-$formatted";

      final existing = await _db
          .from('chamas')
          .select('id')
          .eq('invite_code', code)
          .maybeSingle();

      if (existing == null) {
        return code;
      }
    }
  }

  // =========================
  // CHAMA
  // =========================

  static Future<String> createChama({
    required String chamaName,
    required String chairName,
    required String chairPhone,
    String? purpose,
    String? paymentMode,
    String? paybillNumber,
    String? paybillAccount,
    String? tillNumber,
    String? bankName,
    String? bankAccount,
  }) async {
    final inviteCode = await generatePermanentInviteCode();

    final chamaPayload = _cleanMap({
      'name': chamaName,
      'chair_phone': chairPhone,
      'purpose': purpose,
      'payment_mode': paymentMode,
      'paybill_number': paybillNumber,
      'paybill_account': paybillAccount,
      'till_number': tillNumber,
      'bank_name': bankName,
      'bank_account': bankAccount,
      'invite_code': inviteCode,
    });

    final chamaRes = await _db
        .from('chamas')
        .insert(chamaPayload)
        .select('id')
        .single();

    final chamaId = chamaRes['id'].toString();

    await addMember(
      name: chairName,
      phone: chairPhone,
      role: 'chairperson',
      chamaId: chamaId,
    );

    return chamaId;
  }

  static Future<Map<String, dynamic>> getChamaById(String chamaId) async {
    final res = await _db.from('chamas').select('*').eq('id', chamaId).single();
    return Map<String, dynamic>.from(res);
  }

  static Future<void> updateChama({
    required String chamaId,
    required Map<String, dynamic> updates,
  }) async {
    final cleaned = _cleanMap(updates);
    if (cleaned.isEmpty) return;
    await _db.from('chamas').update(cleaned).eq('id', chamaId);
  }

  static Future<Map<String, dynamic>?> getChamaByInviteCode({
    required String inviteCode,
  }) async {
    final res = await _db
        .from('chamas')
        .select('*')
        .eq('invite_code', inviteCode.trim().toUpperCase())
        .maybeSingle();

    return res == null ? null : Map<String, dynamic>.from(res);
  }

  // =========================
  // MEMBERS
  // =========================

  static Future<void> addMember({
    required String name,
    required String phone,
    required String role,
    required String chamaId,
  }) async {
    await _db
        .from('members')
        .insert(
          _cleanMap({
            'name': name,
            'phone': phone,
            'role': role,
            'chama_id': chamaId,
          }),
        );
  }

  static Future<Map<String, dynamic>?> findMember({
    required String chamaId,
    required String phone,
  }) async {
    final res = await _db
        .from('members')
        .select('id, name, phone, role, chama_id, created_at')
        .eq('chama_id', chamaId)
        .eq('phone', phone.trim())
        .maybeSingle();

    return res == null ? null : Map<String, dynamic>.from(res);
  }

  static Future<List<Map<String, dynamic>>> fetchMembers({
    required String chamaId,
  }) async {
    final res = await _db
        .from('members')
        .select('id, name, phone, role, chama_id, created_at')
        .eq('chama_id', chamaId)
        .order('created_at', ascending: true);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<List<Map<String, dynamic>>> getMembersByChama(String chamaId) {
    return fetchMembers(chamaId: chamaId);
  }

  static bool isChairpersonRole(String? role) {
    return (role ?? '').toLowerCase() == 'chairperson';
  }

  static bool isSecretaryOrChairperson(String? role) {
    final r = (role ?? '').toLowerCase();
    return r == 'chairperson' || r == 'secretary';
  }

  static bool isTreasurerRole(String? role) {
    return (role ?? '').toLowerCase() == 'treasurer';
  }

  static Future<Map<String, dynamic>?> getMemberProfile(String memberId) async {
    final res = await _db
        .from('members')
        .select(
          'id, name, phone, role, chama_id, email, gender, password, active_chama_id, created_at',
        )
        .eq('id', memberId)
        .maybeSingle();

    return res == null ? null : Map<String, dynamic>.from(res);
  }

  static Future<void> saveMemberProfile({
    required String memberId,
    required String phone,
    required String email,
    required String gender,
    required String password,
    required String activeChamaId,
  }) async {
    await _db
        .from('members')
        .update(
          _cleanMap({
            'phone': phone,
            'email': email,
            'gender': gender,
            'password': password,
            'active_chama_id': activeChamaId,
          }),
        )
        .eq('id', memberId);
  }

  static Future<List<Map<String, dynamic>>> getMemberChamas(
    String memberId,
  ) async {
    final member = await _db
        .from('members')
        .select('phone')
        .eq('id', memberId)
        .maybeSingle();

    if (member == null || member['phone'] == null) {
      return [];
    }

    final phone = member['phone'].toString();

    final rows = await _db
        .from('members')
        .select('id, name, phone, role, chama_id')
        .eq('phone', phone);

    final memberList = (rows as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (memberList.isEmpty) return [];

    final chamaIds = memberList
        .map((m) => m['chama_id'])
        .where((id) => id != null)
        .toList();

    if (chamaIds.isEmpty) {
      return memberList
          .map(
            (m) => {
              'member_id': m['id'],
              'chama_id': m['chama_id'],
              'role': m['role'],
              'chama_name': 'Unnamed Chama',
            },
          )
          .toList();
    }

    final chamaRows = await _db
        .from('chamas')
        .select('id, name')
        .inFilter('id', chamaIds);

    final chamaMap = <String, String>{};
    for (final row in chamaRows) {
      final id = row['id'].toString();
      final name = (row['name'] ?? 'Unnamed Chama').toString();
      chamaMap[id] = name;
    }

    return memberList.map((m) {
      final chamaId = m['chama_id']?.toString() ?? '';
      return {
        'member_id': m['id'],
        'chama_id': chamaId,
        'role': (m['role'] ?? 'member').toString(),
        'chama_name': chamaMap[chamaId] ?? 'Unnamed Chama',
      };
    }).toList();
  }

  static Future<void> updateMemberProfile({
    required String memberId,
    String? name,
    String? email,
    String? gender,
  }) async {
    final updates = _cleanMap({'name': name, 'email': email, 'gender': gender});

    if (updates.isEmpty) return;

    await _db.from('members').update(updates).eq('id', memberId);
  }

  static Future<void> updateActiveChama({
    required String memberId,
    required String chamaId,
  }) async {
    final member = await _db
        .from('members')
        .select('phone')
        .eq('id', memberId)
        .maybeSingle();

    if (member == null || member['phone'] == null) {
      throw Exception('Member not found.');
    }

    final phone = member['phone'].toString();

    final targetMember = await _db
        .from('members')
        .select('id')
        .eq('phone', phone)
        .eq('chama_id', chamaId)
        .maybeSingle();

    if (targetMember == null) {
      throw Exception('This member does not belong to the selected chama.');
    }

    await _db
        .from('members')
        .update({'active_chama_id': chamaId})
        .eq('phone', phone);
  }

  static Future<void> changeMemberPassword({
    required String memberId,
    required String newPassword,
  }) async {
    await _db
        .from('members')
        .update({'password': newPassword})
        .eq('id', memberId);
  }
  // =========================
  // MEMBER SETTINGS
  // =========================

  static Future<Map<String, dynamic>> getMemberSettings({
    required String memberId,
  }) async {
    final existing = await _db
        .from('member_settings')
        .select('*')
        .eq('member_id', memberId)
        .maybeSingle();

    if (existing != null) {
      return Map<String, dynamic>.from(existing);
    }

    final inserted = await _db
        .from('member_settings')
        .insert({
          'member_id': memberId,
          'dark_mode': false,
          'meeting_reminders': true,
          'contribution_reminders': true,
          'loan_reminders': false,
        })
        .select('*')
        .single();

    return Map<String, dynamic>.from(inserted);
  }

  static Future<void> saveMemberSettings({
    required String memberId,
    required bool darkMode,
    required bool meetingReminders,
    required bool contributionReminders,
    required bool loanReminders,
  }) async {
    final existing = await _db
        .from('member_settings')
        .select('id')
        .eq('member_id', memberId)
        .maybeSingle();

    final payload = {
      'member_id': memberId,
      'dark_mode': darkMode,
      'meeting_reminders': meetingReminders,
      'contribution_reminders': contributionReminders,
      'loan_reminders': loanReminders,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (existing == null) {
      await _db.from('member_settings').insert(payload);
    } else {
      await _db
          .from('member_settings')
          .update(payload)
          .eq('member_id', memberId);
    }
  }
  // =========================
  // CHAMA INVITES
  // =========================

  static Future<String> createChamaInvite({
    required String chamaId,
    required String createdBy,
    int? maxUses,
    DateTime? expiresAt,
  }) async {
    final code = _generateInviteCode();

    final res = await _db
        .from('chama_invites')
        .insert({
          'chama_id': chamaId,
          'invite_code': code,
          'created_by': createdBy,
          'max_uses': maxUses,
          'expires_at': expiresAt?.toUtc().toIso8601String(),
          'is_active': true,
        })
        .select('invite_code')
        .single();

    return res['invite_code'].toString();
  }

  static Future<Map<String, dynamic>?> getInviteByCode({
    required String inviteCode,
  }) async {
    final res = await _db
        .from('chama_invites')
        .select('*')
        .eq('invite_code', inviteCode.trim().toUpperCase())
        .eq('is_active', true)
        .maybeSingle();

    if (res == null) return null;

    final invite = Map<String, dynamic>.from(res);

    final expiresAtRaw = invite['expires_at'];
    if (expiresAtRaw != null) {
      final expiresAt = DateTime.tryParse(expiresAtRaw.toString());
      if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
        return null;
      }
    }

    final maxUses = invite['max_uses'] as int?;
    final usedCount = (invite['used_count'] as num?)?.toInt() ?? 0;

    if (maxUses != null && usedCount >= maxUses) {
      return null;
    }

    return invite;
  }

  static Future<void> incrementInviteUsage({required String inviteCode}) async {
    final invite = await _db
        .from('chama_invites')
        .select('used_count')
        .eq('invite_code', inviteCode.trim().toUpperCase())
        .maybeSingle();

    if (invite == null) return;

    final current = (invite['used_count'] as num?)?.toInt() ?? 0;

    await _db
        .from('chama_invites')
        .update({'used_count': current + 1})
        .eq('invite_code', inviteCode.trim().toUpperCase());
  }

  static String _generateInviteCode() {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    final tail = now.substring(now.length - 6);
    return 'KAYA$tail';
  }
  // =========================
  // MEMBER DEVICES / FCM TOKENS
  // =========================

  static Future<void> saveDeviceToken({
    required String memberId,
    required String chamaId,
    required String fcmToken,
    required String platform,
  }) async {
    final existing = await _db
        .from('member_devices')
        .select('id')
        .eq('fcm_token', fcmToken)
        .maybeSingle();

    final payload = {
      'member_id': memberId,
      'chama_id': chamaId,
      'fcm_token': fcmToken,
      'platform': platform,
      'notifications_enabled': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (existing == null) {
      await _db.from('member_devices').insert(payload);
    } else {
      await _db
          .from('member_devices')
          .update(payload)
          .eq('fcm_token', fcmToken);
    }
  }

  static Future<void> deleteDeviceToken({required String fcmToken}) async {
    await _db.from('member_devices').delete().eq('fcm_token', fcmToken);
  }

  static Future<List<Map<String, dynamic>>> getChamaDeviceTokens({
    required String chamaId,
  }) async {
    final res = await _db
        .from('member_devices')
        .select(
          'id, member_id, chama_id, fcm_token, platform, notifications_enabled',
        )
        .eq('chama_id', chamaId)
        .eq('notifications_enabled', true);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
  // =========================
  // TRANSACTIONS
  // =========================

  static Future<String> createTransaction({
    required String chamaId,
    required String memberId,
    required String type,
    required num amount,
    String? note,
    DateTime? createdAt,
  }) async {
    final payload = _cleanMap({
      'chama_id': chamaId,
      'member_id': memberId,
      'type': type.toLowerCase().trim(),
      'amount': amount,
      'note': note ?? '',
      if (createdAt != null) 'created_at': createdAt.toUtc().toIso8601String(),
    });

    final res = await _db
        .from('transactions')
        .insert(payload)
        .select('id')
        .single();

    return res['id'].toString();
  }

  static Future<List<Map<String, dynamic>>> fetchTransactions({
    required String chamaId,
    int limit = 500,
    DateTime? since,
  }) async {
    final base = _db
        .from('transactions')
        .select('id, chama_id, member_id, type, amount, note, created_at')
        .eq('chama_id', chamaId);

    final q = since == null
        ? base
        : base.gte('created_at', since.toUtc().toIso8601String());

    final res = await q.order('created_at', ascending: false).limit(limit);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<double> getChamaBalance({required String chamaId}) async {
    final res = await _db
        .from('transactions')
        .select('type, amount')
        .eq('chama_id', chamaId);

    double balance = 0.0;

    for (final row in res) {
      final type = (row['type'] ?? '').toString().toLowerCase();
      final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;

      if (type == 'contribution' || type == 'loan_repayment') {
        balance += amount;
      } else if (type == 'expense' ||
          type == 'withdrawal' ||
          type == 'loan_disbursed') {
        balance -= amount;
      }
    }

    return balance;
  }

  // =========================
  // LEGACY CONTRIBUTION TARGETS
  // Keep for compatibility with older screens
  // =========================

  static Future<bool> monthlyTargetsExist({
    required String chamaId,
    required int month,
    required int year,
  }) async {
    final res = await _db
        .from('contribution_target')
        .select('id')
        .eq('chama_id', chamaId)
        .eq('month', month)
        .eq('year', year)
        .limit(1);

    final list = res as List;
    return list.isNotEmpty;
  }

  static Future<int> ensureMonthlyTargets({
    required String chamaId,
    required int month,
    required int year,
    required num expectedAmount,
  }) async {
    final exists = await monthlyTargetsExist(
      chamaId: chamaId,
      month: month,
      year: year,
    );
    if (exists) return 0;

    final members = await fetchMembers(chamaId: chamaId);
    if (members.isEmpty) return 0;

    final payload = members.map((m) {
      return {
        'chama_id': chamaId,
        'member_id': m['id'],
        'month': month,
        'year': year,
        'expected_amount': expectedAmount,
      };
    }).toList();

    await _db.from('contribution_target').insert(payload);

    return payload.length;
  }

  static Future<double?> getMonthlyExpectedAmount({
    required String chamaId,
    required int month,
    required int year,
  }) async {
    final res = await _db
        .from('contribution_target')
        .select('expected_amount')
        .eq('chama_id', chamaId)
        .eq('month', month)
        .eq('year', year)
        .limit(1);

    final list = res as List;
    if (list.isEmpty) return null;

    final v = list.first['expected_amount'];
    if (v == null) return null;
    return (v as num).toDouble();
  }

  // =========================
  // FINANCE GOALS
  // =========================

  static Future<String> createFinanceGoal({
    required String chamaId,
    required num totalGoalAmount,
    required int durationMonths,
    required DateTime startDate,
    required String createdBy,
    required String contributionFrequency,
    String status = 'active',
  }) async {
    final members = await fetchMembers(chamaId: chamaId);
    if (members.isEmpty) {
      throw Exception('No members found for this chama.');
    }

    if (durationMonths <= 0) {
      throw Exception('Duration months must be greater than zero.');
    }

    if (totalGoalAmount <= 0) {
      throw Exception('Total goal amount must be greater than zero.');
    }

    final existingActiveGoal = await getActiveFinanceGoal(chamaId: chamaId);
    if (existingActiveGoal != null && status == 'active') {
      throw Exception(
        'This chama already has an active finance goal. Complete or close it first.',
      );
    }

    final memberCount = members.length;
    final perMemberTotal = totalGoalAmount / memberCount;
    final perMemberMonthly = perMemberTotal / durationMonths;

    final endDate = DateTime(
      startDate.year,
      startDate.month + durationMonths,
      startDate.day,
    );

    final goalRes = await _db
        .from('finance_goals')
        .insert({
          'chama_id': chamaId,
          'total_goal_amount': totalGoalAmount,
          'duration_months': durationMonths,
          'member_count_snapshot': memberCount,
          'per_member_total': perMemberTotal,
          'per_member_monthly': perMemberMonthly,
          'start_date': _dateOnly(startDate),
          'end_date': _dateOnly(endDate),
          'status': status,
          'created_by': createdBy,
        })
        .select('id')
        .single();

    final goalId = goalRes['id'].toString();

    final targetRows = members.map((m) {
      return {
        'goal_id': goalId,
        'chama_id': chamaId,
        'member_id': m['id'],
        'required_total': perMemberTotal,
        'required_per_month': perMemberMonthly,
      };
    }).toList();

    await _db.from('member_finance_targets').insert(targetRows);

    return goalId;
  }

  static Future<Map<String, dynamic>?> getActiveFinanceGoal({
    required String chamaId,
  }) async {
    final res = await _db
        .from('finance_goals')
        .select('*')
        .eq('chama_id', chamaId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .maybeSingle();

    return res == null ? null : Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>?> getFinanceGoalById({
    required String goalId,
  }) async {
    final res = await _db
        .from('finance_goals')
        .select('*')
        .eq('id', goalId)
        .maybeSingle();

    return res == null ? null : Map<String, dynamic>.from(res);
  }

  static Future<List<Map<String, dynamic>>> fetchFinanceGoals({
    required String chamaId,
  }) async {
    final res = await _db
        .from('finance_goals')
        .select('*')
        .eq('chama_id', chamaId)
        .order('created_at', ascending: false);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> updateFinanceGoal({
    required String goalId,
    required Map<String, dynamic> updates,
  }) async {
    final cleaned = _cleanMap(updates);
    if (cleaned.isEmpty) return;

    await _db.from('finance_goals').update(cleaned).eq('id', goalId);
  }

  static Future<void> closeFinanceGoal({required String goalId}) async {
    await _db
        .from('finance_goals')
        .update({'status': 'completed'})
        .eq('id', goalId);
  }

  static Future<List<Map<String, dynamic>>> getMemberFinanceTargets({
    required String goalId,
  }) async {
    final res = await _db
        .from('member_finance_targets')
        .select('''
          id,
          created_at,
          goal_id,
          chama_id,
          member_id,
          required_total,
          required_per_month,
          member:members!member_finance_targets_member_id_fkey(id, name, phone, role)
        ''')
        .eq('goal_id', goalId)
        .order('created_at', ascending: true);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // =========================
  // FINANCE CONTRIBUTIONS
  // =========================

  static Future<String> recordFinanceContribution({
    required String chamaId,
    required String goalId,
    required String memberId,
    required num amount,
    required String recordedBy,
    String? note,
    DateTime? paidAt,
  }) async {
    if (amount <= 0) {
      throw Exception('Contribution amount must be greater than zero.');
    }

    final when = paidAt ?? DateTime.now();

    final res = await _db
        .from('finance_contributions')
        .insert({
          'chama_id': chamaId,
          'goal_id': goalId,
          'member_id': memberId,
          'amount': amount,
          'contribution_month': when.month,
          'contribution_year': when.year,
          'paid_at': when.toUtc().toIso8601String(),
          'recorded_by': recordedBy,
          'note': note,
        })
        .select('id')
        .single();

    await createTransaction(
      chamaId: chamaId,
      memberId: memberId,
      type: 'contribution',
      amount: amount,
      note: note ?? 'Finance contribution',
      createdAt: when,
    );

    return res['id'].toString();
  }

  static Future<List<Map<String, dynamic>>> fetchFinanceContributions({
    required String goalId,
  }) async {
    final res = await _db
        .from('finance_contributions')
        .select('''
          id,
          created_at,
          chama_id,
          goal_id,
          member_id,
          amount,
          contribution_month,
          contribution_year,
          paid_at,
          recorded_by,
          note,
          member:members!finance_contributions_member_id_fkey(id, name, phone, role)
        ''')
        .eq('goal_id', goalId)
        .order('paid_at', ascending: false);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchMemberFinanceContributions({
    required String goalId,
    required String memberId,
  }) async {
    final res = await _db
        .from('finance_contributions')
        .select('*')
        .eq('goal_id', goalId)
        .eq('member_id', memberId)
        .order('paid_at', ascending: false);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<double> getGoalContributionTotal({
    required String goalId,
  }) async {
    final res = await _db
        .from('finance_contributions')
        .select('amount')
        .eq('goal_id', goalId);

    double total = 0.0;
    for (final row in res) {
      total += (row['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  static Future<double> getMemberContributionTotal({
    required String goalId,
    required String memberId,
  }) async {
    final res = await _db
        .from('finance_contributions')
        .select('amount')
        .eq('goal_id', goalId)
        .eq('member_id', memberId);

    double total = 0.0;
    for (final row in res) {
      total += (row['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  static Future<List<Map<String, dynamic>>> getContributionTrend({
    required String goalId,
  }) async {
    final goal = await _db
        .from('finance_goals')
        .select('start_date, duration_months, total_goal_amount')
        .eq('id', goalId)
        .single();

    final startDate = DateTime.parse(goal['start_date'].toString());
    final durationMonths = (goal['duration_months'] as num).toInt();
    final totalGoal = (goal['total_goal_amount'] as num).toDouble();
    final expectedPerMonth = durationMonths == 0
        ? 0.0
        : totalGoal / durationMonths;

    final rows = await _db
        .from('finance_contributions')
        .select('amount, contribution_month, contribution_year')
        .eq('goal_id', goalId);

    final actualMap = <String, double>{};

    for (final row in rows) {
      final month = (row['contribution_month'] as num).toInt();
      final year = (row['contribution_year'] as num).toInt();
      final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
      final key = '$year-$month';
      actualMap[key] = (actualMap[key] ?? 0.0) + amount;
    }

    final trend = <Map<String, dynamic>>[];
    double cumulativeActual = 0.0;

    for (int i = 0; i < durationMonths; i++) {
      final d = DateTime(startDate.year, startDate.month + i, 1);
      final key = '${d.year}-${d.month}';
      final actual = actualMap[key] ?? 0.0;
      cumulativeActual += actual;

      trend.add({
        'month': d.month,
        'year': d.year,
        'label': '${_monthShort(d.month)} ${d.year}',
        'actual': actual,
        'cumulative_actual': cumulativeActual,
        'cumulative_expected': expectedPerMonth * (i + 1),
      });
    }

    return trend;
  }

  // =========================
  // LOAN REQUESTS
  // =========================

  static Future<String> createLoanRequest({
    required String chamaId,
    required String memberId,
    String? goalId,
    required num requestedAmount,
    required String reason,
  }) async {
    if (requestedAmount <= 0) {
      throw Exception('Requested amount must be greater than zero.');
    }

    final res = await _db
        .from('loan_requests')
        .insert({
          'chama_id': chamaId,
          'member_id': memberId,
          'goal_id': goalId,
          'requested_amount': requestedAmount,
          'reason': reason,
          'status': 'pending',
        })
        .select('id')
        .single();

    return res['id'].toString();
  }

  static Future<List<Map<String, dynamic>>> fetchLoanRequests({
    required String chamaId,
    String? status,
  }) async {
    final base = _db.from('loan_requests').select('''
          id,
          created_at,
          chama_id,
          member_id,
          goal_id,
          requested_amount,
          approved_amount,
          reason,
          status,
          approved_by,
          approved_at,
          due_date,
          decision_note,
          member:members!loan_requests_member_id_fkey(id, name, phone, role),
          approver:members!loan_requests_approved_by_fkey(id, name, phone, role)
        ''');

    final res = status == null
        ? await base
              .eq('chama_id', chamaId)
              .order('created_at', ascending: false)
        : await base
              .eq('chama_id', chamaId)
              .eq('status', status)
              .order('created_at', ascending: false);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchMemberLoanRequests({
    required String memberId,
  }) async {
    final res = await _db
        .from('loan_requests')
        .select('*')
        .eq('member_id', memberId)
        .order('created_at', ascending: false);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>?> getLoanRequestById({
    required String loanRequestId,
  }) async {
    final res = await _db
        .from('loan_requests')
        .select('*')
        .eq('id', loanRequestId)
        .maybeSingle();

    return res == null ? null : Map<String, dynamic>.from(res);
  }

  static Future<void> updateLoanRequestStatus({
    required String loanRequestId,
    required String status,
    required String approvedBy,
    num? approvedAmount,
    DateTime? dueDate,
    String? decisionNote,
  }) async {
    final updates = _cleanMap({
      'status': status,
      'approved_by': approvedBy,
      'approved_at': DateTime.now().toUtc().toIso8601String(),
      'approved_amount': approvedAmount,
      'due_date': dueDate == null ? null : _dateOnly(dueDate),
      'decision_note': decisionNote,
    });

    await _db.from('loan_requests').update(updates).eq('id', loanRequestId);

    if (status.toLowerCase() == 'approved' && approvedAmount != null) {
      final loan = await getLoanRequestById(loanRequestId: loanRequestId);
      if (loan != null) {
        final chamaId = (loan['chama_id'] ?? '').toString();
        final memberId = (loan['member_id'] ?? '').toString();

        if (chamaId.isNotEmpty && memberId.isNotEmpty) {
          await createTransaction(
            chamaId: chamaId,
            memberId: memberId,
            type: 'loan_disbursed',
            amount: approvedAmount,
            note: 'Loan approved and disbursed',
            createdAt: DateTime.now(),
          );
        }
      }
    }
  }

  static Future<double> getLoanRepaymentTotal({
    required String loanRequestId,
  }) async {
    final res = await _db
        .from('loan_repayments')
        .select('amount_paid')
        .eq('loan_request_id', loanRequestId);

    double total = 0.0;
    for (final row in res) {
      total += (row['amount_paid'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  static Future<double> getLoanBalance({required String loanRequestId}) async {
    final loan = await getLoanRequestById(loanRequestId: loanRequestId);
    if (loan == null) return 0.0;

    final approvedAmount = (loan['approved_amount'] as num?)?.toDouble() ?? 0.0;
    final repaid = await getLoanRepaymentTotal(loanRequestId: loanRequestId);

    final balance = approvedAmount - repaid;
    return balance < 0 ? 0.0 : balance;
  }

  static Future<String> recordLoanRepayment({
    required String loanRequestId,
    required String chamaId,
    required String memberId,
    required num amountPaid,
    required String recordedBy,
    String? note,
    DateTime? paidAt,
  }) async {
    if (amountPaid <= 0) {
      throw Exception('Repayment amount must be greater than zero.');
    }

    final when = paidAt ?? DateTime.now();

    final res = await _db
        .from('loan_repayments')
        .insert({
          'loan_request_id': loanRequestId,
          'chama_id': chamaId,
          'member_id': memberId,
          'amount_paid': amountPaid,
          'paid_at': when.toUtc().toIso8601String(),
          'recorded_by': recordedBy,
          'note': note,
        })
        .select('id')
        .single();

    await createTransaction(
      chamaId: chamaId,
      memberId: memberId,
      type: 'loan_repayment',
      amount: amountPaid,
      note: note ?? 'Loan repayment',
      createdAt: when,
    );

    final balance = await getLoanBalance(loanRequestId: loanRequestId);
    if (balance <= 0) {
      await _db
          .from('loan_requests')
          .update({'status': 'repaid'})
          .eq('id', loanRequestId);
    }

    return res['id'].toString();
  }

  static Future<Map<String, dynamic>?> getMyLatestLoan({
    required String memberId,
  }) async {
    final res = await _db
        .from('loan_requests')
        .select('*')
        .eq('member_id', memberId)
        .order('created_at', ascending: false)
        .maybeSingle();

    return res == null ? null : Map<String, dynamic>.from(res);
  }

  static Future<List<Map<String, dynamic>>> fetchLoanRepayments({
    required String loanRequestId,
  }) async {
    final res = await _db
        .from('loan_repayments')
        .select('''
          id,
          created_at,
          loan_request_id,
          chama_id,
          member_id,
          amount_paid,
          paid_at,
          recorded_by,
          note,
          member:members!loan_repayments_member_id_fkey(id, name, phone, role)
        ''')
        .eq('loan_request_id', loanRequestId)
        .order('paid_at', ascending: false);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // =========================
  // INVESTMENT INSIGHTS
  // =========================

  static Future<List<Map<String, dynamic>>> fetchInvestmentInsights({
    required String chamaId,
  }) async {
    final res = await _db
        .from('investment_insights')
        .select('*')
        .eq('chama_id', chamaId)
        .order('rank_position', ascending: true);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // =========================
  // FINANCE DASHBOARD V2
  // =========================

  static Future<Map<String, dynamic>> getFinanceDashboardV2({
    required String chamaId,
    String? currentMemberId,
  }) async {
    final members = await fetchMembers(chamaId: chamaId);
    final balance = await getChamaBalance(chamaId: chamaId);
    final goal = await getActiveFinanceGoal(chamaId: chamaId);

    if (goal == null) {
      return {
        'balance': balance,
        'goal': null,
        'totalContributed': 0.0,
        'overallProgress': 0.0,
        'perMemberTotal': 0.0,
        'perMemberMonthly': 0.0,
        'fully': <Map<String, dynamic>>[],
        'notFully': <Map<String, dynamic>>[],
        'myContributed': 0.0,
        'myProgress': 0.0,
        'myLoan': null,
        'trend': <Map<String, dynamic>>[],
      };
    }

    final goalId = goal['id'].toString();
    final totalGoal = (goal['total_goal_amount'] as num?)?.toDouble() ?? 0.0;
    final perMemberTotal =
        (goal['per_member_total'] as num?)?.toDouble() ?? 0.0;
    final perMemberMonthly =
        (goal['per_member_monthly'] as num?)?.toDouble() ?? 0.0;

    final contributions = await _db
        .from('finance_contributions')
        .select(
          'member_id, amount, contribution_month, contribution_year, paid_at',
        )
        .eq('goal_id', goalId);

    final totals = <String, double>{};
    double totalContributed = 0.0;

    for (final row in contributions) {
      final memberId = row['member_id'].toString();
      final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
      totals[memberId] = (totals[memberId] ?? 0.0) + amount;
      totalContributed += amount;
    }

    final fully = <Map<String, dynamic>>[];
    final notFully = <Map<String, dynamic>>[];

    for (final m in members) {
      final memberId = m['id'].toString();
      final name = (m['name'] ?? '').toString();
      final paid = totals[memberId] ?? 0.0;
      final remaining = (perMemberTotal - paid).clamp(0.0, perMemberTotal);
      final progress = perMemberTotal == 0 ? 0.0 : paid / perMemberTotal;

      final row = {
        'member_id': memberId,
        'name': name,
        'paid': paid,
        'expected': perMemberTotal,
        'remaining': remaining,
        'progress': progress,
      };

      if (paid >= perMemberTotal) {
        fully.add(row);
      } else {
        notFully.add(row);
      }
    }

    final trend = await getContributionTrend(goalId: goalId);

    double myContributed = 0.0;
    double myProgress = 0.0;
    Map<String, dynamic>? myLoan;

    if (currentMemberId != null && currentMemberId.isNotEmpty) {
      myContributed = totals[currentMemberId] ?? 0.0;
      myProgress = perMemberTotal == 0 ? 0.0 : myContributed / perMemberTotal;

      final loanRows = await _db
          .from('loan_requests')
          .select('*')
          .eq('member_id', currentMemberId)
          .order('created_at', ascending: false)
          .limit(1);

      final loanList = loanRows as List;
      if (loanList.isNotEmpty) {
        myLoan = Map<String, dynamic>.from(loanList.first);
        final loanId = myLoan['id'].toString();
        final loanBalance = await getLoanBalance(loanRequestId: loanId);
        myLoan['balance'] = loanBalance;
      }
    }

    return {
      'balance': balance,
      'goal': goal,
      'totalContributed': totalContributed,
      'overallProgress': totalGoal == 0 ? 0.0 : totalContributed / totalGoal,
      'perMemberTotal': perMemberTotal,
      'perMemberMonthly': perMemberMonthly,
      'fully': fully,
      'notFully': notFully,
      'myContributed': myContributed,
      'myProgress': myProgress,
      'myLoan': myLoan,
      'trend': trend,
    };
  }

  static Future<Map<String, dynamic>> getChamaFinanceSummary({
    required String chamaId,
  }) async {
    // Get goal
    final goal = await _db
        .from('finance_goals')
        .select()
        .eq('chama_id', chamaId)
        .maybeSingle();

    // Get contributions
    final contributions = await _db
        .from('finance_contributions')
        .select('amount')
        .eq('chama_id', chamaId);

    double currentSaved = 0.0;

    for (final row in contributions) {
      final amount = row['amount'];
      if (amount is num) {
        currentSaved += amount.toDouble();
      }
    }

    double targetAmount = 0.0;
    int targetMonths = 0;

    if (goal != null) {
      final target = goal['total_goal_amount'];
      final duration = goal['duration_months'];

      if (target is num) targetAmount = target.toDouble();
      if (duration is num) targetMonths = duration.toInt();
    }

    return {
      'targetAmount': targetAmount,
      'currentSaved': currentSaved,
      'targetMonths': targetMonths,
    };
  }
  // =========================
  // LEGACY FINANCE DASHBOARD
  // Keep for compatibility with older UI
  // =========================

  static Future<Map<String, dynamic>> getFinanceDashboard({
    required String chamaId,
    required int month,
    required int year,
  }) async {
    final members = await fetchMembers(chamaId: chamaId);
    final balance = await getChamaBalance(chamaId: chamaId);

    final expected = await getMonthlyExpectedAmount(
      chamaId: chamaId,
      month: month,
      year: year,
    );

    if (expected == null) {
      return {
        'balance': balance,
        'expected': null,
        'fully': <Map<String, dynamic>>[],
        'notFully': <Map<String, dynamic>>[],
      };
    }

    final start = DateTime(year, month, 1).toUtc();
    final end = month == 12
        ? DateTime(year + 1, 1, 1).toUtc()
        : DateTime(year, month + 1, 1).toUtc();

    final txRes = await _db
        .from('transactions')
        .select('member_id, type, amount, created_at')
        .eq('chama_id', chamaId)
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String());

    final totals = <String, double>{};

    for (final row in txRes) {
      final type = (row['type'] ?? '').toString().toLowerCase();
      if (type != 'contribution') continue;

      final memberId = row['member_id'].toString();
      final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;
      totals[memberId] = (totals[memberId] ?? 0.0) + amt;
    }

    final fully = <Map<String, dynamic>>[];
    final notFully = <Map<String, dynamic>>[];

    for (final m in members) {
      final id = m['id'].toString();
      final name = (m['name'] ?? '').toString();

      final paid = totals[id] ?? 0.0;
      final remaining = (expected - paid).clamp(0.0, expected);

      final row = {
        'member_id': id,
        'name': name,
        'paid': paid,
        'expected': expected,
        'remaining': remaining,
      };

      if (paid >= expected) {
        fully.add(row);
      } else {
        notFully.add(row);
      }
    }

    return {
      'balance': balance,
      'expected': expected,
      'fully': fully,
      'notFully': notFully,
    };
  }

  // =========================
  // MEETINGS
  // =========================

  static Future<List<Map<String, dynamic>>> fetchMeetingsByChama({
    required String chamaId,
  }) async {
    final members = await fetchMembers(chamaId: chamaId);
    final memberIds = members.map((e) => e['id'].toString()).toList();

    if (memberIds.isEmpty) return [];

    final res = await _db
        .from('meetings')
        .select('''
        id,
        created_at,
        title,
        meeting_date,
        start_time,
        end_time,
        venue,
        minutes_text,
        any_other_business,
        next_meeting_date,
        status,
        created_by,
        secretary_id,
        chairperson_id,
        approved,
        approved_at,
        approved_by,
        updated_at
      ''')
        .inFilter('created_by', memberIds)
        .neq('status', 'archived')
        .order('meeting_date', ascending: false);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>?> getUpcomingMeeting({
    required String chamaId,
  }) async {
    final meetings = await fetchMeetingsByChama(chamaId: chamaId);
    if (meetings.isEmpty) return null;

    final today = DateTime.now();
    final upcoming = meetings.where((m) {
      final raw = m['meeting_date'];
      if (raw == null) return false;
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return false;
      return !dt.isBefore(DateTime(today.year, today.month, today.day));
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

  static Future<Map<String, dynamic>?> getMeetingById(String meetingId) async {
    final res = await _db
        .from('meetings')
        .select('*')
        .eq('id', meetingId)
        .maybeSingle();

    return res == null ? null : Map<String, dynamic>.from(res);
  }

  static Future<String> createMeeting({
    required String title,
    required DateTime meetingDate,
    String? startTime,
    String? endTime,
    String? venue,
    String? minutesText,
    String? anyOtherBusiness,
    DateTime? nextMeetingDate,
    String? status,
    required String createdBy,
    String? secretaryId,
    String? chairpersonId,
  }) async {
    final payload = _cleanMap({
      'title': title,
      'meeting_date': _dateOnly(meetingDate),
      'start_time': startTime,
      'end_time': endTime,
      'venue': venue,
      'minutes_text': minutesText,
      'any_other_business': anyOtherBusiness,
      'next_meeting_date': nextMeetingDate == null
          ? null
          : _dateOnly(nextMeetingDate),
      'status': status ?? 'draft',
      'created_by': createdBy,
      'secretary_id': secretaryId,
      'chairperson_id': chairpersonId,
      'approved': false,
    });

    final res = await _db
        .from('meetings')
        .insert(payload)
        .select('id')
        .single();

    return res['id'].toString();
  }

  static Future<void> updateMeeting({
    required String meetingId,
    required Map<String, dynamic> updates,
  }) async {
    final cleaned = _cleanMap(updates);
    if (cleaned.isEmpty) return;

    await _db.from('meetings').update(cleaned).eq('id', meetingId);
  }

  static Future<void> updateMeetingDetails({
    required String meetingId,
    required String title,
    required DateTime meetingDate,
    String? startTime,
    String? endTime,
    String? venue,
    String? secretaryId,
    String? chairpersonId,
  }) async {
    final payload = _cleanMap({
      'title': title,
      'meeting_date': _dateOnly(meetingDate),
      'start_time': startTime,
      'end_time': endTime,
      'venue': venue,
      'secretary_id': secretaryId,
      'chairperson_id': chairpersonId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _db.from('meetings').update(payload).eq('id', meetingId);
  }

  static Future<void> saveMeetingMinutes({
    required String meetingId,
    required String minutesText,
    String? anyOtherBusiness,
  }) async {
    final payload = _cleanMap({
      'minutes_text': minutesText,
      'any_other_business': anyOtherBusiness,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _db.from('meetings').update(payload).eq('id', meetingId);
  }

  static Future<void> approveMeeting({
    required String meetingId,
    required String approvedBy,
  }) async {
    await _db
        .from('meetings')
        .update({
          'approved': true,
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'published',
        })
        .eq('id', meetingId);
  }

  static Future<void> publishMeeting({required String meetingId}) async {
    await _db
        .from('meetings')
        .update({
          'status': 'published',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', meetingId);
  }

  static Future<void> revertMeetingToDraft({required String meetingId}) async {
    await _db
        .from('meetings')
        .update({
          'status': 'draft',
          'approved': false,
          'approved_by': null,
          'approved_at': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', meetingId);
  }

  static Future<void> deleteMeeting(String meetingId) async {
    await _db.from('meetings').delete().eq('id', meetingId);
  }

  static Future<void> deleteMeetingSafe({required String meetingId}) async {
    await _db.from('meeting_action_items').delete().eq('meeting_id', meetingId);
    await _db.from('meeting_agenda_items').delete().eq('meeting_id', meetingId);
    await _db.from('meeting_attendance').delete().eq('meeting_id', meetingId);
    await _db.from('meetings').delete().eq('id', meetingId);
  }

  static Future<void> archiveMeeting({required String meetingId}) async {
    await _db
        .from('meetings')
        .update({
          'status': 'archived',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', meetingId);
  }
  // =========================
  // MEETING ATTENDANCE
  // =========================

  static Future<List<Map<String, dynamic>>> fetchMeetingAttendance({
    required String meetingId,
  }) async {
    final res = await _db
        .from('meeting_attendance')
        .select('''
          id,
          created_at,
          meeting_id,
          member_id,
          attendance_status,
          remarks,
          recorded_by,
          updated_at,
          member:members!meeting_attendance_member_id_fkey(id, name, phone, role)
        ''')
        .eq('meeting_id', meetingId)
        .order('created_at', ascending: true);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> saveMeetingAttendance({
    required String meetingId,
    required List<Map<String, dynamic>> attendanceRows,
  }) async {
    await _db.from('meeting_attendance').delete().eq('meeting_id', meetingId);

    if (attendanceRows.isEmpty) return;

    final payload = attendanceRows.map((row) {
      return _cleanMap({
        'meeting_id': meetingId,
        'member_id': row['member_id'],
        'attendance_status': row['attendance_status'],
        'remarks': row['remarks'],
        'recorded_by': row['recorded_by'],
      });
    }).toList();

    await _db.from('meeting_attendance').insert(payload);
  }

  // =========================
  // MEETING AGENDA ITEMS
  // =========================

  static Future<List<Map<String, dynamic>>> fetchMeetingAgendaItems({
    required String meetingId,
  }) async {
    final res = await _db
        .from('meeting_agenda_items')
        .select('*')
        .eq('meeting_id', meetingId)
        .order('item_order', ascending: true);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> saveMeetingAgendaItems({
    required String meetingId,
    required String createdBy,
    required List<Map<String, dynamic>> items,
  }) async {
    await _db.from('meeting_agenda_items').delete().eq('meeting_id', meetingId);

    if (items.isEmpty) return;

    final payload = items.map((item) {
      return _cleanMap({
        'meeting_id': meetingId,
        'item_order': item['item_order'],
        'item_title': item['item_title'],
        'discussion_notes': item['discussion_notes'],
        'resolution': item['resolution'],
        'created_by': createdBy,
      });
    }).toList();

    await _db.from('meeting_agenda_items').insert(payload);
  }

  // =========================
  // MEETING ACTION ITEMS
  // =========================

  static Future<List<Map<String, dynamic>>> fetchMeetingActionItems({
    required String meetingId,
  }) async {
    final res = await _db
        .from('meeting_action_items')
        .select('''
          id,
          created_at,
          meeting_id,
          agenda_item_id,
          task_title,
          task_description,
          assigned_to,
          due_date,
          status,
          created_by,
          completed_at,
          updated_at,
          assignee:members!meeting_action_items_assigned_to_fkey(id, name, phone, role)
        ''')
        .eq('meeting_id', meetingId)
        .order('created_at', ascending: true);

    final list = res as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> saveMeetingActionItems({
    required String meetingId,
    required String createdBy,
    required List<Map<String, dynamic>> items,
  }) async {
    await _db.from('meeting_action_items').delete().eq('meeting_id', meetingId);

    if (items.isEmpty) return;

    final payload = items.map((item) {
      return _cleanMap({
        'meeting_id': meetingId,
        'agenda_item_id': item['agenda_item_id'],
        'task_title': item['task_title'],
        'task_description': item['task_description'],
        'assigned_to': item['assigned_to'],
        'due_date': item['due_date'],
        'status': item['status'] ?? 'pending',
        'created_by': createdBy,
      });
    }).toList();

    await _db.from('meeting_action_items').insert(payload);
  }

  static Future<void> updateActionItemStatus({
    required String actionItemId,
    required String status,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (status == 'completed') {
      updates['completed_at'] = DateTime.now().toUtc().toIso8601String();
    }

    await _db
        .from('meeting_action_items')
        .update(updates)
        .eq('id', actionItemId);
  }

  // =========================
  // FULL MEETING DETAILS
  // =========================

  static Future<Map<String, dynamic>> getMeetingDetails({
    required String meetingId,
  }) async {
    final results = await Future.wait([
      getMeetingById(meetingId),
      fetchMeetingAttendance(meetingId: meetingId),
      fetchMeetingAgendaItems(meetingId: meetingId),
      fetchMeetingActionItems(meetingId: meetingId),
    ]);

    return {
      'meeting': results[0] as Map<String, dynamic>?,
      'attendance': results[1] as List<Map<String, dynamic>>,
      'agendaItems': results[2] as List<Map<String, dynamic>>,
      'actionItems': results[3] as List<Map<String, dynamic>>,
    };
  }

  // =========================
  // HELPERS
  // =========================

  static Map<String, dynamic> _cleanMap(Map<String, dynamic> input) {
    final out = <String, dynamic>{};

    for (final entry in input.entries) {
      final v = entry.value;
      if (v == null) continue;

      if (v is String) {
        final t = v.trim();
        if (t.isEmpty) continue;
        out[entry.key] = t;
      } else {
        out[entry.key] = v;
      }
    }

    return out;
  }

  static String _dateOnly(DateTime dt) {
    final d = dt.toUtc();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static String _monthShort(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
