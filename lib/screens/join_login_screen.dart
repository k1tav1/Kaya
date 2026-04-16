import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';
import '../services/notification_service.dart';

class JoinLoginChamaPage extends StatefulWidget {
  const JoinLoginChamaPage({super.key});

  @override
  State<JoinLoginChamaPage> createState() => _JoinLoginChamaPageState();
}

class _JoinLoginChamaPageState extends State<JoinLoginChamaPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController inviteCodeController = TextEditingController();

  String? genderValue;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Timer? _debounce;
  bool _isLookingUp = false;
  String? _memberName;
  String? _lookupError;
  String? _memberId;
  String? _resolvedChamaId;
  String? _resolvedChamaName;

  bool isSubmitting = false;
  bool _obscurePassword = true;
  bool _profileLoaded = false;

  String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\s+'), '').trim();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    final phone = normalizePhone(value);
    if (phone.length < 10) {
      return 'Enter a valid phone number';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Must contain at least one uppercase letter';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Must contain at least one number';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]').hasMatch(value)) {
      return 'Must contain at least one special character';
    }

    return null;
  }

  String? _validateGender(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please select gender';
    }
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _triggerMemberLookup() {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final phone = normalizePhone(phoneController.text.trim());
      final inviteCode = inviteCodeController.text.trim().toUpperCase();

      if (phone.isEmpty || inviteCode.isEmpty) {
        if (!mounted) return;
        setState(() {
          _memberName = null;
          _memberId = null;
          _lookupError = null;
          _isLookingUp = false;
          _profileLoaded = false;
          _resolvedChamaId = null;
          _resolvedChamaName = null;
        });
        return;
      }

      setState(() {
        _isLookingUp = true;
        _lookupError = null;
      });

      try {
        final chama = await SupabaseService.getChamaByInviteCode(
          inviteCode: inviteCode,
        );

        if (!mounted) return;

        if (chama == null) {
          setState(() {
            _memberName = null;
            _memberId = null;
            _lookupError = "Invalid invite code";
            _isLookingUp = false;
            _profileLoaded = false;
            _resolvedChamaId = null;
            _resolvedChamaName = null;
          });
          return;
        }

        final chamaId = chama['id']?.toString() ?? '';
        final chamaName = (chama['name'] ?? 'Chama').toString();

        final member = await SupabaseService.findMember(
          chamaId: chamaId,
          phone: phone,
        );

        if (!mounted) return;

        if (member == null) {
          setState(() {
            _memberName = null;
            _memberId = null;
            _lookupError =
                "Member not found for this phone number in $chamaName";
            _isLookingUp = false;
            _profileLoaded = false;
            _resolvedChamaId = chamaId;
            _resolvedChamaName = chamaName;
          });
          return;
        }

        final memberId = member['id']?.toString();

        setState(() {
          _memberName = member['name']?.toString();
          _memberId = memberId;
          _lookupError = null;
          _isLookingUp = false;
          _resolvedChamaId = chamaId;
          _resolvedChamaName = chamaName;
        });

        if (memberId != null && !_profileLoaded) {
          await _loadExistingProfile(memberId);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _memberName = null;
          _memberId = null;
          _lookupError = "Lookup failed: $e";
          _isLookingUp = false;
          _profileLoaded = false;
          _resolvedChamaId = null;
          _resolvedChamaName = null;
        });
      }
    });
  }

  Future<void> _loadExistingProfile(String memberId) async {
    try {
      final profile = await SupabaseService.getMemberProfile(memberId);

      if (!mounted || profile == null) return;

      setState(() {
        genderValue = profile['gender']?.toString();
        emailController.text = profile['email']?.toString() ?? '';
        _profileLoaded = true;
      });
    } catch (_) {}
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final phone = normalizePhone(phoneController.text.trim());
    final inviteCode = inviteCodeController.text.trim().toUpperCase();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final gender = genderValue?.trim();

    setState(() => isSubmitting = true);

    try {
      final chama = await SupabaseService.getChamaByInviteCode(
        inviteCode: inviteCode,
      );

      if (!mounted) return;

      if (chama == null) {
        _showMessage("Invalid invite code.");
        return;
      }

      final chamaId = chama['id']?.toString() ?? '';
      if (chamaId.isEmpty) {
        _showMessage("Could not resolve chama from invite code.");
        return;
      }

      final member = await SupabaseService.findMember(
        chamaId: chamaId,
        phone: phone,
      );

      if (!mounted) return;

      if (member == null) {
        _showMessage("Member not found. Check phone number and invite code.");
        return;
      }

      final name = member['name']?.toString() ?? "Member";
      final role = member['role']?.toString() ?? "member";
      final memberId = member['id']?.toString() ?? "";
      final memberPhone = member['phone']?.toString() ?? phone;

      await SupabaseService.saveMemberProfile(
        memberId: memberId,
        phone: memberPhone,
        email: email,
        gender: gender ?? '',
        password: password,
        activeChamaId: chamaId,
      );
      // await NotificationService.registerDeviceForMember(
      //   memberId: memberId,
      //   chamaId: chamaId,
      // );

      if (!mounted) return;

      _showMessage("Welcome, $name ✅");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            chamaId: chamaId,
            memberName: name,
            memberRole: role,
            memberPhone: memberPhone,
            memberId: memberId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage("Login error: $e");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    phoneController.addListener(_triggerMemberLookup);
    inviteCodeController.addListener(_triggerMemberLookup);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    phoneController.dispose();
    inviteCodeController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _isLookingUp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : (_memberName == null)
                  ? const Icon(Icons.person_outline)
                  : Chip(
                      avatar: const Icon(Icons.person, size: 18),
                      label: SizedBox(
                        width: 90,
                        child: Text(
                          _memberName!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),

                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          validator: _validatePhone,
                          decoration: const InputDecoration(
                            labelText: "Phone Number",
                            hintText: "07XXXXXXXX",
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Profile",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: genderValue,
                                validator: _validateGender,
                                items: const [
                                  DropdownMenuItem(
                                    value: "Male",
                                    child: Text("Male"),
                                  ),
                                  DropdownMenuItem(
                                    value: "Female",
                                    child: Text("Female"),
                                  ),
                                  DropdownMenuItem(
                                    value: "Prefer not to say",
                                    child: Text("Prefer not to say"),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => genderValue = v),
                                decoration: const InputDecoration(
                                  labelText: "Gender",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                                decoration: const InputDecoration(
                                  labelText: "Email",
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                validator: _validatePassword,
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Password must be 8+ characters, include an uppercase letter, a number, and a special character.",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: inviteCodeController,
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) =>
                              _validateRequired(value, "Invite Code"),
                          decoration: const InputDecoration(
                            labelText: "Invite Code",
                            hintText: "KAYA-1234",
                            prefixIcon: Icon(Icons.qr_code_2),
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 10),

                        if (_resolvedChamaName != null)
                          Text(
                            "Chama: $_resolvedChamaName",
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                        if (_lookupError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _lookupError!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else if (_memberName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              "Matched member: $_memberName",
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ),

                        const SizedBox(height: 18),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text("LOGIN"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
