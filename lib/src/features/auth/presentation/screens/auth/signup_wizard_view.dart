import 'dart:async';
import 'dart:math';
import 'package:auto_route/auto_route.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:gap/gap.dart';
import 'package:medusa_admin/src/core/constants/strings.dart';
import 'package:medusa_admin/src/core/extensions/snack_bar_extension.dart';
import 'package:medusa_admin/src/core/utils/hide_keyboard.dart';
import 'package:medusa_admin/src/features/auth/data/service/auth_preference_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medusa_admin/src/core/services/app_scope_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:medusa_admin/src/features/auth/presentation/bloc/authentication/authentication_bloc.dart';

// ─── Onboarding API helpers ──────────────────────────────────────────────────
// All calls go through the Medusa backend's public onboarding endpoints.
// No hardcoded superadmin key, no cold-start Render server.
class _OnboardingApi {
  static Dio _dio() {
    final base = AuthPreferenceService.baseUrlGetter?.isNotEmpty == true
        ? AuthPreferenceService.baseUrlGetter!
        : AppConstants.baseUrl;
    return Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
    ));
  }

  /// Returns {available: bool, message: String}
  static Future<Map<String, dynamic>> checkAvailability(
      String phone, String? email) async {
    final body = <String, dynamic>{'phone': phone};
    if (email != null && email.isNotEmpty) body['email'] = email;
    final res = await _dio().post('/admin/vendor/onboarding/check', data: body);
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Returns {success: bool, expiresInSeconds: int}
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    final res = await _dio()
        .post('/admin/vendor/onboarding/otp/send', data: {'phone': phone});
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Returns {valid: bool}
  static Future<Map<String, dynamic>> verifyOtp(
      String phone, String code) async {
    final res = await _dio().post('/admin/vendor/onboarding/otp/verify',
        data: {'phone': phone, 'code': code});
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Returns {user: {id, email, store_id, ...}}
  static Future<Map<String, dynamic>> register({
    required String phone,
    required String email,
    required String password,
    required String storeName,
    required String accountType,
    required String otpCode,
    String? niche,
  }) async {
    final res = await _dio().post('/admin/vendor/onboarding/register', data: {
      'phone': phone,
      'email': email,
      'password': password,
      'storeName': storeName,
      'accountType': accountType,
      'otpCode': otpCode,
      if (niche != null && niche.isNotEmpty) 'niche': niche,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }
}
// ─────────────────────────────────────────────────────────────────────────────

@RoutePage()
class SignupWizardView extends StatefulWidget {
  const SignupWizardView({super.key});

  @override
  State<SignupWizardView> createState() => _SignupWizardViewState();
}

class _SignupWizardViewState extends State<SignupWizardView> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 6;

  // Step 1
  String _accountType = 'vendor';

  // Step 2
  final _inviteCodeCtrl = TextEditingController();
  final _nicheCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();

  // Step 3
  final _phoneCtrl = TextEditingController(text: '+234');

  // Step 4 — OTP is verified server-side; the expected code is NEVER stored
  // on the client to prevent bypass via local comparison.
  final _otpCtrl = TextEditingController();
  int _otpCooldown = 0;
  Timer? _cooldownTimer;
  bool _otpVerified = false;

  // Step 5
  bool _noEmail = false;
  final _emailCtrl = TextEditingController();
  String? _generatedEmail;

  // Step 6
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _inviteCodeCtrl.dispose();
    _nicheCtrl.dispose();
    _storeNameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _goToPage(int page) {
    setState(() => _currentStep = page);
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _nextStep() async {
    if (_currentStep >= _totalSteps - 1) return;

    if (_currentStep == 0) {
      _goToPage(1);
      return;
    }

    if (_currentStep == 1) {
      if (_accountType == 'vendor' && _storeNameCtrl.text.trim().isEmpty) {
        context.showSnackBar('Please enter your store name');
        return;
      }
      if ((_accountType == 'logistics_staff' || _accountType == 'intern') &&
          _inviteCodeCtrl.text.trim().isEmpty) {
        context.showSnackBar('Please enter your invite code');
        return;
      }
      _goToPage(2);
      return;
    }

    if (_currentStep == 2) {
      final phone = _phoneCtrl.text.trim();
      if (phone.isEmpty || phone.length < 10) {
        context.showSnackBar('Please enter a valid phone number');
        return;
      }
      await _checkPhoneAndSendOtp();
      return;
    }

    if (_currentStep == 3) {
      if (_otpCtrl.text.trim().length < 4) {
        context.showSnackBar('Please enter the OTP code you received');
        return;
      }
      await _verifyOtp();
      return;
    }

    if (_currentStep == 4) {
      if (!_noEmail && _emailCtrl.text.trim().isEmpty) {
        context.showSnackBar('Please enter a valid email address');
        return;
      }
      if (_noEmail && _generatedEmail == null) await _generateEmailAddress();
      if (!_noEmail) {
        await _checkEmailAvailability();
        return;
      }
      _goToPage(5);
      return;
    }

    _goToPage(_currentStep + 1);
  }

  void _prevStep() {
    if (_currentStep > 0) _goToPage(_currentStep - 1);
  }

  Future<void> _generateEmailAddress() async {
    final name = _storeNameCtrl.text.trim().isEmpty
        ? 'vendor'
        : _storeNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim().replaceAll('+', '');
    setState(() {
      _generatedEmail =
          'vndr-${name.toLowerCase().replaceAll(' ', '')}${phone.substring(max(0, phone.length - 5))}@afriomarkets.com';
    });
  }

  // ── Phone pre-check + OTP send ──────────────────────────────────────────
  Future<void> _checkPhoneAndSendOtp() async {
    // If an OTP is already in flight (cooldown active) just advance.
    if (_otpCooldown > 0) {
      _goToPage(3);
      return;
    }

    final phone = _phoneCtrl.text.trim();

    EasyLoading.show(status: 'Checking availability…');
    try {
      final check = await _OnboardingApi.checkAvailability(phone, null);
      if (check['available'] == false) {
        EasyLoading.dismiss();
        if (!mounted) return;
        context.showSnackBar(check['message']?.toString() ??
            'This phone number is already registered. Please log in instead.');
        return;
      }
    } on DioException catch (e) {
      EasyLoading.dismiss();
      if (!mounted) return;
      context.showSnackBar(
          'Could not verify phone: ${e.response?.data?['message'] ?? e.message}');
      return;
    }

    EasyLoading.show(status: 'Sending OTP…');
    try {
      final res = await _OnboardingApi.sendOtp(phone);
      EasyLoading.dismiss();
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _otpCooldown = 30;
          _otpVerified = false;
        });
        _startCooldownTimer();
        context.showSnackBar('OTP sent! Check your phone for the code.');
        _goToPage(3);
      } else {
        context
            .showSnackBar(res['message']?.toString() ?? 'Failed to send OTP');
      }
    } on DioException catch (e) {
      EasyLoading.dismiss();
      if (!mounted) return;
      context.showSnackBar(
          'Failed to send OTP: ${e.response?.data?['message'] ?? e.message}');
    }
  }

  // ── Email availability check ─────────────────────────────────────────────
  Future<void> _checkEmailAvailability() async {
    EasyLoading.show(status: 'Checking email…');
    try {
      final check = await _OnboardingApi.checkAvailability(
          _phoneCtrl.text.trim(), _emailCtrl.text.trim());
      EasyLoading.dismiss();
      if (!mounted) return;
      if (check['available'] == false) {
        context.showSnackBar(check['message']?.toString() ??
            'This email is already registered. Please log in instead.');
        return;
      }
      _goToPage(5);
    } on DioException catch (e) {
      EasyLoading.dismiss();
      if (!mounted) return;
      context.showSnackBar(
          'Could not verify email: ${e.response?.data?['message'] ?? e.message}');
    }
  }

  // ── Resend OTP ───────────────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    if (_otpCooldown > 0) return;
    EasyLoading.show(status: 'Resending OTP…');
    try {
      final res = await _OnboardingApi.sendOtp(_phoneCtrl.text.trim());
      EasyLoading.dismiss();
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _otpCooldown = 30;
          _otpCtrl.clear();
        });
        _startCooldownTimer();
        context.showSnackBar('New OTP sent!');
      } else {
        context
            .showSnackBar(res['message']?.toString() ?? 'Failed to resend OTP');
      }
    } on DioException catch (e) {
      EasyLoading.dismiss();
      if (!mounted) return;
      context.showSnackBar(
          'Resend failed: ${e.response?.data?['message'] ?? e.message}');
    }
  }

  // ── Server-side OTP verification ─────────────────────────────────────────
  Future<void> _verifyOtp() async {
    EasyLoading.show(status: 'Verifying OTP…');
    try {
      final res = await _OnboardingApi.verifyOtp(
          _phoneCtrl.text.trim(), _otpCtrl.text.trim());
      EasyLoading.dismiss();
      if (!mounted) return;
      if (res['valid'] == true) {
        setState(() => _otpVerified = true);
        _goToPage(4);
      } else {
        context.showSnackBar(res['message']?.toString() ??
            'Invalid OTP code. Please try again.');
      }
    } on DioException catch (e) {
      EasyLoading.dismiss();
      if (!mounted) return;
      context.showSnackBar(
          'OTP error: ${e.response?.data?['message'] ?? e.message}');
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _otpCooldown = 0);
      } else {
        if (mounted) setState(() => _otpCooldown--);
      }
    });
  }

  // ── Final registration ───────────────────────────────────────────────────
  Future<void> _submitRegistration() async {
    final password = _passwordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (password.isEmpty || password.length < 6) {
      context.showSnackBar('Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      context.showSnackBar('Passwords do not match');
      return;
    }
    if (!_otpVerified) {
      context.showSnackBar('Please verify your phone number first');
      _goToPage(3);
      return;
    }

    final email = _noEmail ? _generatedEmail! : _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    EasyLoading.show(status: 'Creating your account…');
    try {
      // 1. Register via Medusa backend (creates User + Store + Wallet).
      final regRes = await _OnboardingApi.register(
        phone: phone,
        email: email,
        password: password,
        storeName: _storeNameCtrl.text.trim().isEmpty
            ? 'My Store'
            : _storeNameCtrl.text.trim(),
        accountType: _accountType,
        otpCode: _otpCtrl.text.trim(),
        niche: _nicheCtrl.text.trim().isEmpty ? null : _nicheCtrl.text.trim(),
      );

      if (regRes['success'] != true) {
        throw Exception(
            regRes['message']?.toString() ?? 'Registration failed.');
      }

      final medusaUserId = regRes['user']?['id'];

      // 2. Supabase sign-up (supplemental — for session / push notifications).
      try {
        final supabase = Supabase.instance.client;
        final fullName = _accountType == 'vendor'
            ? _storeNameCtrl.text.trim()
            : _accountType.replaceAll('_', ' ').toUpperCase();

        await supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'phone': phone,
            'full_name': fullName,
            'medusa_user_id': medusaUserId,
          },
        );

        // Best-effort upsert into public.users.
        try {
          await supabase.from('users').upsert({
            'email': email,
            'phone': phone,
            'type': _accountType,
            'medusa_user_id': medusaUserId,
            'last_sign_in_at': DateTime.now().toIso8601String(),
          }, onConflict: 'email');
        } catch (_) {}
      } catch (supabaseErr) {
        // Medusa registration is the source of truth — Supabase is supplemental.
        debugPrint(
            '[SignupWizard] Supabase sign-up non-fatal error: $supabaseErr');
      }

      // Automatically align the initial operating scope and user metadata
      await AppScopeService.setUserMetadata({
        'account_type': _accountType,
        'store_name': _storeNameCtrl.text.trim(),
        'phone': phone,
        'niche': _nicheCtrl.text.trim(),
      });
      if (_accountType == 'logistics_org') {
        await AppScopeService.setScope(AppScope.logistics);
      } else if (_accountType == 'logistics_staff') {
        await AppScopeService.setScope(AppScope.rider);
      } else {
        await AppScopeService.setScope(AppScope.vendor);
      }

      EasyLoading.showSuccess('Registration successful! Signing in…');

      try {
        await AuthPreferenceService.instance.setEmail(email);
        if (mounted) {
          context.read<AuthenticationBloc>().add(
            AuthenticationEvent.logInCookie(email, password),
          );
        }
      } catch (loginErr) {
        debugPrint('[SignupWizard] Auto-login dispatch error: $loginErr');
      }

      await Future.delayed(const Duration(milliseconds: 1200));
      EasyLoading.dismiss();

      if (!mounted) return;
      final authState = context.read<AuthenticationBloc>().state;
      final isLoggedIn =
          authState.maybeWhen(loggedIn: (_) => true, orElse: () => false);

      if (isLoggedIn) {
        context.router.replaceAll([const MainAppRoute()]);
      } else if (context.router.canPop()) {
        context.router.pop();
      } else {
        context.router.replaceAll([SignInRoute()]);
      }
    } on DioException catch (e) {
      EasyLoading.dismiss();
      if (!mounted) return;
      final msg = e.response?.data?['message'] ?? e.message ?? 'Unknown error';
      context.showSnackBar('Registration failed: $msg');
    } catch (e) {
      EasyLoading.dismiss();
      if (!mounted) return;
      context.showSnackBar('Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE48629);

    return HideKeyboard(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _currentStep > 0
                ? _prevStep
                : () {
                    if (context.router.canPop()) {
                      context.router.pop();
                    } else {
                      context.router.replaceAll([SignInRoute()]);
                    }
                  },
          ),
          title: const Text('Create Account'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: List.generate(_totalSteps, (index) {
                    final isActive = index <= _currentStep;
                    return Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: isActive ? accent : Colors.grey.shade300,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                    _buildStep4(),
                    _buildStep5(),
                    _buildStep6(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Step 1 ─────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Select Account Type',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const Gap(8),
          Text('Choose the type of account you want to configure',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center),
          const Gap(24),
          Expanded(
            child: ListView(children: [
              _typeCard(
                  'vendor',
                  'Vendor / Merchant',
                  'Sell products on Afriomarkets and manage store orders.',
                  Icons.storefront),
              const Gap(12),
              _typeCard(
                  'logistics_org',
                  'Logistics Organization',
                  'Register a courier, delivery fleet, or sorting hub company.',
                  Icons.local_shipping),
              const Gap(12),
              _typeCard(
                  'logistics_staff',
                  'Delivery Rider / Fleet Staff',
                  'Join an existing logistics company as a rider or dispatcher.',
                  Icons.two_wheeler),
              const Gap(12),
              _typeCard(
                  'dropshipper',
                  'Dropshipper',
                  'Configure specialized dropshipping preferences.',
                  Icons.shopping_bag),
            ]),
          ),
          const Gap(16),
          _nextBtn('Next Step'),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _typeCard(String type, String title, String desc, IconData icon) {
    final isSelected = _accountType == type;
    const accent = Color(0xFFE48629);
    return InkWell(
      onTap: () => setState(() => _accountType = type),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? accent : Colors.grey.shade300,
              width: isSelected ? 2 : 1),
          color: isSelected
              ? accent.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
        ),
        child: Row(children: [
          Icon(icon, size: 36, color: isSelected ? accent : Colors.grey),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Gap(4),
                Text(desc,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Step 2 ─────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Verification & Preferences',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const Gap(24),
          if (_accountType == 'vendor') ...[
            _lbl('Store Name *'),
            const Gap(6),
            _fld(_storeNameCtrl, 'Enter your store name'),
            const Gap(16),
            _lbl('Niche / Category (Optional)'),
            const Gap(6),
            _fld(_nicheCtrl, 'e.g. fashion, electronics, cosmetics'),
          ] else if (_accountType == 'logistics_org') ...[
            _lbl('Logistics Company / Fleet Name *'),
            const Gap(6),
            _fld(_storeNameCtrl, 'e.g. Swift Air & Road Express Ltd'),
            const Gap(16),
            _lbl('Primary Operational City / Base *'),
            const Gap(6),
            _fld(_nicheCtrl, 'e.g. Lagos, Abuja, Port Harcourt, Accra'),
          ] else if (_accountType == 'logistics_staff' ||
              _accountType == 'intern') ...[
            _lbl('Full Name / Rider Name *'),
            const Gap(6),
            _fld(_storeNameCtrl, 'e.g. Musa Ibrahim'),
            const Gap(16),
            _lbl('Logistics Organization / Station Invite Code *'),
            const Gap(6),
            _fld(_inviteCodeCtrl, 'Enter the invite code from your dispatch company'),
          ] else if (_accountType == 'dropshipper') ...[
            _lbl('Catalog Sourcing Niche (Optional)'),
            const Gap(6),
            _fld(_nicheCtrl, 'e.g. Electronics, Home Goods'),
          ],
          const Gap(32),
          _nextBtn('Next Step'),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ─── Step 3 ─────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Phone Verification',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const Gap(8),
          Text('Enter your phone number to receive a verification code',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center),
          const Gap(24),
          _lbl('Phone Number *'),
          const Gap(6),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                hintText: '+234 123 4567 890', border: OutlineInputBorder()),
          ),
          const Gap(8),
          Text(
              'We will verify this number is not already registered before sending the code.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const Gap(40),
          _nextBtn('Send Verification Code'),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ─── Step 4 ─────────────────────────────────────────────────────────────
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Enter Verification Code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const Gap(8),
          Text('We sent a code to ${_phoneCtrl.text}',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center),
          const Gap(24),
          _lbl('OTP Code *'),
          const Gap(6),
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
                hintText: '••••••',
                border: OutlineInputBorder(),
                counterText: ''),
          ),
          const Gap(16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _otpCooldown > 0
                    ? 'Resend in ${_otpCooldown}s'
                    : "Didn't receive the code? ",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              if (_otpCooldown == 0)
                TextButton(
                  onPressed: _resendOtp,
                  child: const Text('Resend',
                      style: TextStyle(color: Color(0xFFE48629))),
                ),
            ],
          ),
          const Gap(40),
          _nextBtn('Verify & Continue'),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ─── Step 5 ─────────────────────────────────────────────────────────────
  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Email Setup',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const Gap(24),
          CheckboxListTile(
            title: const Text("I don't have an email address"),
            subtitle: const Text(
                'We will generate a secure email mapped to your store name and phone number'),
            value: _noEmail,
            activeColor: const Color(0xFFE48629),
            onChanged: (val) {
              setState(() {
                _noEmail = val ?? false;
                if (_noEmail) {
                  _generateEmailAddress();
                } else {
                  _generatedEmail = null;
                }
              });
            },
          ),
          const Gap(24),
          if (_noEmail) ...[
            _lbl('Your Assigned Email'),
            const Gap(6),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Text(
                _generatedEmail ?? 'Generating…',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF344F16)),
              ),
            ),
          ] else ...[
            _lbl('Email Address *'),
            const Gap(6),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  hintText: 'e.g. name@example.com',
                  border: OutlineInputBorder()),
            ),
          ],
          const Gap(40),
          _nextBtn('Next Step'),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ─── Step 6 ─────────────────────────────────────────────────────────────
  Widget _buildStep6() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Secure Password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const Gap(24),
          _lbl('Password *'),
          const Gap(6),
          TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  hintText: 'At least 6 characters',
                  border: OutlineInputBorder())),
          const Gap(16),
          _lbl('Confirm Password *'),
          const Gap(6),
          TextField(
              controller: _confirmPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  hintText: 'Repeat password', border: OutlineInputBorder())),
          const Gap(32),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF344F16),
              minimumSize: const Size(double.infinity, 50.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0)),
            ),
            onPressed: _submitRegistration,
            child: const Text('Complete Registration',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ─── Shared helpers ──────────────────────────────────────────────────────
  Widget _lbl(String t) =>
      Text(t, style: const TextStyle(fontWeight: FontWeight.bold));

  Widget _fld(TextEditingController c, String hint) => TextField(
      controller: c,
      decoration:
          InputDecoration(hintText: hint, border: const OutlineInputBorder()));

  Widget _nextBtn(String label) => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF344F16),
          minimumSize: const Size(double.infinity, 50.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        ),
        onPressed: _nextStep,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
}
