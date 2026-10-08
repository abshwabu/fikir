import 'dart:async';
import 'dart:math';

import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/features/auth/data/auth_repository.dart';
import 'package:fikir/features/onboarding/data/onboarding_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sms_autofill/sms_autofill.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    required this.phoneNumber, super.key,
  });

  final String phoneNumber;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin, CodeAutoFill {
  static const int _pinLength = 6;
  static const int _initialAttempts = 5;

  final List<TextEditingController> _controllers =
      List.generate(_pinLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_pinLength, (_) => FocusNode());

  late AnimationController _shakeController;
  int _countdown = 60;
  Timer? _timer;
  int _attemptsRemaining = _initialAttempts;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _initAutoFill();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  void _initAutoFill() {
    try {
      listenForCode();
    } catch (_) {
      // Ignored if platform doesn't support SmsRetriever (e.g. desktop/iOS)
    }
  }

  @override
  void codeUpdated() {
    // Android SMS Retriever callback
    final smsCode = code;
    if (smsCode != null && smsCode.length == _pinLength) {
      _fillPin(smsCode);
      _verifyCode(smsCode);
    }
  }

  @override
  void dispose() {
    cancel();
    unregisterListener();
    _timer?.cancel();
    _shakeController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
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

  String get _currentPin => _controllers.map((c) => c.text).join();

  void _fillPin(String code) {
    for (var i = 0; i < _pinLength && i < code.length; i++) {
      _controllers[i].text = code[i];
    }
    if (_pinLength <= code.length) {
      _focusNodes.last.unfocus();
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste
      _fillPin(value);
      if (_currentPin.length == _pinLength) {
        _verifyCode(_currentPin);
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < _pinLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_currentPin.length == _pinLength) {
          _verifyCode(_currentPin);
        }
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_countdown > 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repo = ref.read(authRepositoryProvider);
    final result = await repo.requestOtp(widget.phoneNumber);

    setState(() => _isLoading = false);

    result.when(
      success: (_) {
        _startCountdown();
        setState(() {
          _attemptsRemaining = _initialAttempts;
        });
      },
      failure: (err) {
        setState(() => _errorMessage = err.message);
      },
    );
  }

  Future<void> _verifyCode(String pin) async {
    if (pin.length != _pinLength || _isLoading || _attemptsRemaining <= 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    final result = await authRepo.verifyOtp(
      phone: widget.phoneNumber,
      code: pin,
    );

    setState(() => _isLoading = false);

    result.when(
      success: (_) {
        final onboardingRepo = ref.read(onboardingRepositoryProvider);
        if (onboardingRepo.isOnboardingComplete()) {
          context.go('/discover');
        } else {
          context.go('/onboarding');
        }
      },
      failure: (err) {
        setState(() {
          _attemptsRemaining--;
          _shakeController.forward(from: 0);
          for (final c in _controllers) {
            c.clear();
          }
          _focusNodes.first.requestFocus();

          final l10n = AppLocalizations.of(context);
          if (_attemptsRemaining <= 0) {
            _errorMessage = l10n?.tooManyAttempts ??
                'Too many failed attempts. Please request a new code.';
          } else {
            _errorMessage = err.message;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.verificationCode ?? 'Verification Code',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n?.codeSentTo(widget.phoneNumber) ??
                    'Enter the 6-digit code sent to ${widget.phoneNumber}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 36),

              // 6-Box Animated Pin Input
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final offset = sin(_shakeController.value * pi * 4) * 10;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_pinLength, (index) {
                    final hasValue = _controllers[index].text.isNotEmpty;
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.backspace &&
                              _controllers[index].text.isEmpty &&
                              index > 0) {
                            _focusNodes[index - 1].requestFocus();
                            _controllers[index - 1].clear();
                          }
                        },
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          enabled: _attemptsRemaining > 0 && !_isLoading,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: hasValue
                                    ? FikirColors.primaryCoral
                                    : FikirColors.lightBorder,
                                width: hasValue ? 2 : 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: FikirColors.primaryMagenta,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (val) => _onDigitChanged(index, val),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Attempts Remaining Indicator
              if (_attemptsRemaining < _initialAttempts && _attemptsRemaining > 0) ...[
                Text(
                  l10n?.attemptsRemaining(_attemptsRemaining) ??
                      'Attempts remaining: $_attemptsRemaining',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],

              // Error Banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Spacer(),

              // Resend Countdown Button
              TextButton(
                onPressed: _countdown == 0 ? _resendOtp : null,
                child: Text(
                  _countdown > 0
                      ? '${l10n?.resendCode ?? "Resend Code"} (${_countdown}s)'
                      : (l10n?.resendCode ?? 'Resend Code'),
                  style: TextStyle(
                    color: _countdown == 0 ? FikirColors.primaryCoral : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Manual Verify Button
              GradientButton(
                text: l10n?.verifyOtp ?? 'Verify Code',
                isLoading: _isLoading,
                onPressed: _currentPin.length == _pinLength && _attemptsRemaining > 0
                    ? () => _verifyCode(_currentPin)
                    : null,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
