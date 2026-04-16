import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class CreateChamaPage extends StatefulWidget {
  const CreateChamaPage({super.key});

  @override
  State<CreateChamaPage> createState() => _CreateChamaPageState();
}

class _CreateChamaPageState extends State<CreateChamaPage> {
  final chamaNameController = TextEditingController();
  final chairNameController = TextEditingController();
  final chairPhoneController = TextEditingController();
  final purposeController = TextEditingController();

  String paymentMode = "Paybill";
  final paybillNumberController = TextEditingController();
  final paybillAccountController = TextEditingController();
  final tillNumberController = TextEditingController();
  final bankNameController = TextEditingController();
  final bankAccountController = TextEditingController();

  final memberNameController = TextEditingController();
  final memberPhoneController = TextEditingController();

  final List<Map<String, String>> members = [];
  bool isSubmitting = false;

  String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\s+'), '').trim();
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void addMember() {
    final name = memberNameController.text.trim();
    final phone = normalizePhone(memberPhoneController.text.trim());
    final chairPhone = normalizePhone(chairPhoneController.text.trim());

    if (name.isEmpty || phone.isEmpty) {
      showMessage("Please enter member name and phone number");
      return;
    }

    if (chairPhone.isNotEmpty && phone == chairPhone) {
      showMessage("Chairperson phone number cannot be added again as a member");
      return;
    }

    final alreadyExists = members.any(
      (m) => normalizePhone(m["phone"] ?? "") == phone,
    );

    if (alreadyExists) {
      showMessage("That member phone number has already been added");
      return;
    }

    setState(() {
      members.add({
        "name": name,
        "phone": phone,
        "role": members.isEmpty
            ? "Treasurer"
            : members.length == 1
            ? "Secretary"
            : "Member",
      });
    });

    memberNameController.clear();
    memberPhoneController.clear();
  }

  void removeMember(int index) {
    setState(() {
      members.removeAt(index);
    });
  }

  bool _validatePaymentFields() {
    if (paymentMode == "Paybill") {
      return paybillNumberController.text.trim().isNotEmpty &&
          paybillAccountController.text.trim().isNotEmpty;
    }
    if (paymentMode == "Till") {
      return tillNumberController.text.trim().isNotEmpty;
    }
    if (paymentMode == "Bank") {
      return bankNameController.text.trim().isNotEmpty &&
          bankAccountController.text.trim().isNotEmpty;
    }
    return true;
  }

  bool _hasDuplicatePhones() {
    final seen = <String>{};

    final chairPhone = normalizePhone(chairPhoneController.text.trim());
    if (chairPhone.isNotEmpty) {
      if (seen.contains(chairPhone)) return true;
      seen.add(chairPhone);
    }

    for (final m in members) {
      final phone = normalizePhone(m["phone"] ?? "");
      if (phone.isEmpty) continue;
      if (seen.contains(phone)) return true;
      seen.add(phone);
    }

    return false;
  }

  Future<void> _showInviteCodeDialog({
    required String chamaId,
    required String inviteCode,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Chama Created 🎉"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Your chama has been created successfully.\nShare this invite code with members so they can join.",
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: SelectableText(
                inviteCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: inviteCode));
              showMessage("Invite code copied ✅");
            },
            child: const Text("Copy"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, {
                "created": true,
                "message": "Chama created",
                "chamaId": chamaId,
                "inviteCode": inviteCode,
              });
            },
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  Future<void> createChama() async {
    if (isSubmitting) return;

    final chamaName = chamaNameController.text.trim();
    final chairName = chairNameController.text.trim();
    final chairPhone = normalizePhone(chairPhoneController.text.trim());
    final purpose = purposeController.text.trim();

    if (chamaName.isEmpty ||
        chairName.isEmpty ||
        chairPhone.isEmpty ||
        members.length < 3) {
      showMessage("Please complete all required fields");
      return;
    }

    if (purpose.isEmpty) {
      showMessage("Please add the chama purpose");
      return;
    }

    if (!_validatePaymentFields()) {
      showMessage("Please complete payment details");
      return;
    }

    if (_hasDuplicatePhones()) {
      showMessage("Duplicate phone numbers are not allowed");
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final chamaId = await SupabaseService.createChama(
        chamaName: chamaName,
        chairName: chairName,
        chairPhone: chairPhone,
        purpose: purpose,
        paymentMode: paymentMode,
        paybillNumber: paybillNumberController.text.trim().isEmpty
            ? null
            : paybillNumberController.text.trim(),
        paybillAccount: paybillAccountController.text.trim().isEmpty
            ? null
            : paybillAccountController.text.trim(),
        tillNumber: tillNumberController.text.trim().isEmpty
            ? null
            : tillNumberController.text.trim(),
        bankName: bankNameController.text.trim().isEmpty
            ? null
            : bankNameController.text.trim(),
        bankAccount: bankAccountController.text.trim().isEmpty
            ? null
            : bankAccountController.text.trim(),
      );

      for (final m in members) {
        await SupabaseService.addMember(
          name: m["name"]!,
          phone: normalizePhone(m["phone"]!),
          role: m["role"]!,
          chamaId: chamaId,
        );
      }

      final chama = await SupabaseService.getChamaById(chamaId);
      final inviteCode = (chama['invite_code'] ?? '').toString();

      if (!mounted) return;

      await _showInviteCodeDialog(chamaId: chamaId, inviteCode: inviteCode);
    } catch (e) {
      if (!mounted) return;

      final errorText = e.toString().toLowerCase();

      if (errorText.contains("duplicate key value") ||
          errorText.contains("members_unique_phone_per_chama")) {
        showMessage(
          "A member with that phone number already exists in this chama",
        );
      } else {
        showMessage("Failed to create chama. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    chamaNameController.dispose();
    chairNameController.dispose();
    chairPhoneController.dispose();
    purposeController.dispose();
    paybillNumberController.dispose();
    paybillAccountController.dispose();
    tillNumberController.dispose();
    bankNameController.dispose();
    bankAccountController.dispose();
    memberNameController.dispose();
    memberPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Create your Chama",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              TextField(
                controller: chamaNameController,
                decoration: const InputDecoration(
                  labelText: "Chama Name",
                  prefixIcon: Icon(Icons.group),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: chairNameController,
                decoration: const InputDecoration(
                  labelText: "Chairperson Name",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: chairPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Chairperson Phone Number",
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: purposeController,
                decoration: const InputDecoration(
                  labelText: "Purpose (e.g. Savings, Investment, Welfare)",
                  prefixIcon: Icon(Icons.flag),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 10),

              const Text(
                "Payment Mode",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: paymentMode,
                items: const [
                  DropdownMenuItem(value: "Paybill", child: Text("Paybill")),
                  DropdownMenuItem(value: "Till", child: Text("Till Number")),
                  DropdownMenuItem(value: "Bank", child: Text("Bank Account")),
                ],
                onChanged: isSubmitting
                    ? null
                    : (v) => setState(() => paymentMode = v ?? "Paybill"),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments),
                ),
              ),

              const SizedBox(height: 12),

              if (paymentMode == "Paybill") ...[
                TextField(
                  controller: paybillNumberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Paybill Number",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: paybillAccountController,
                  decoration: const InputDecoration(
                    labelText: "Account Number",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              if (paymentMode == "Till") ...[
                TextField(
                  controller: tillNumberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Till Number",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              if (paymentMode == "Bank") ...[
                TextField(
                  controller: bankNameController,
                  decoration: const InputDecoration(
                    labelText: "Bank Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bankAccountController,
                  decoration: const InputDecoration(
                    labelText: "Bank Account Number",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 10),

              const Text(
                "Add Members (minimum 3)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: memberNameController,
                decoration: const InputDecoration(
                  labelText: "Member Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: memberPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Member Phone Number",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : addMember,
                  icon: const Icon(Icons.person_add),
                  label: const Text("Add Member"),
                ),
              ),

              const SizedBox(height: 14),

              if (members.isEmpty)
                const Text("No members added yet.")
              else
                ...members.asMap().entries.map((entry) {
                  final index = entry.key;
                  final m = entry.value;

                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(m["name"]!),
                    subtitle: Text("${m["phone"]} • ${m["role"]}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: isSubmitting
                          ? null
                          : () => removeMember(index),
                    ),
                  );
                }),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : createChama,
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Create Chama"),
                ),
              ),

              const SizedBox(height: 10),
              const Text(
                "Note: Members will join using the chama invite code.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
