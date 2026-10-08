import 'dart:async';

import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/features/auth/data/auth_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  bool _isValidEthiopianPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\s+|-'), '');
    return RegExp(r'^(\+251|0)?[97]\d{8}$').hasMatch(cleaned);
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneController.text.trim();
    final l10n = AppLocalizations.of(context);

    if (!_isValidEthiopianPhone(phone)) {
      setState(() {
        _errorMessage = l10n?.invalidPhone ?? 'Please enter a valid Ethiopian mobile number (09... or 07...)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    final result = await authRepo.requestOtp(phone);

    setState(() => _isLoading = false);

    result.when(
      success: (_) {
        setState(() => _isOtpSent = true);
        _startCountdown();
      },
      failure: (err) {
        setState(() => _errorMessage = err.message);
      },
    );
  }

  Future<void> _handleVerifyOtp() async {
    final phone = _phoneController.text.trim();
    final code = _otpController.text.trim();
    final l10n = AppLocalizations.of(context);

    if (code.length != 6) {
      setState(() {
        _errorMessage = l10n?.invalidOtp ?? 'Please enter the 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    final result = await authRepo.verifyOtp(phone: phone, code: code);

    setState(() => _isLoading = false);

    result.when(
      success: (_) {
        // Logged in! Router auth guard will transition to /discover automatically
      },
      failure: (err) {
        setState(() => _errorMessage = err.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Gradient Flame Icon
                ShaderMask(
                  shaderCallback: (bounds) => FikirColors.primaryGradient.createShader(bounds),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n?.appName ?? 'Fikir',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: FikirColors.primaryMagenta,
                      ),
                ),
                Text(
                  l10n?.tagline ?? 'Find your Ethiopian love',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 48),

                if (!_isOtpSent) ...[
                  Text(
                    l10n?.loginTitle ?? 'Welcome to Fikir',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n?.loginSubtitle ?? 'Enter your Ethiopian phone number to continue',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_outlined),
                      hintText: l10n?.phonePlaceholder ?? '09xxxxxxxx or 07xxxxxxxx',
                    ),
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    text: l10n?.sendOtp ?? 'Send Code',
                    isLoading: _isLoading,
                    onPressed: _handleSendOtp,
                  ),
                ] else ...[
                  Text(
                    l10n?.enterCode ?? 'Enter the 6-digit code',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Code sent to ${_phoneController.text}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: '------',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    text: l10n?.verifyOtp ?? 'Verify & Continue',
                    isLoading: _isLoading,
                    onPressed: _handleVerifyOtp,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _isOtpSent = false),
                        child: Text(l10n?.back ?? 'Change number'),
                      ),
                      TextButton(
                        onPressed: _countdown == 0 ? _handleSendOtp : null,
                        child: Text(
                          _countdown > 0
                              ? '${l10n?.resendCode ?? "Resend in"} (${_countdown}s)'
                              : (l10n?.resendCode ?? 'Resend Code'),
                        ),
                      ),
                    ],
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
