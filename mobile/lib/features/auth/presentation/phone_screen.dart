import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/core/utils/phone_utils.dart';
import 'package:fikir/features/auth/data/auth_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid => PhoneUtils.isValidEthiopianPhone(_controller.text);

  Future<void> _submitPhone() async {
    final raw = _controller.text.trim();
    final normalized = PhoneUtils.normalizeEthiopianPhone(raw);
    final l10n = AppLocalizations.of(context);

    if (normalized == null) {
      setState(() {
        _errorMessage = l10n?.invalidPhone ??
            'Please enter a valid Ethiopian mobile number (09... or 07...)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repo = ref.read(authRepositoryProvider);
    final result = await repo.requestOtp(normalized);

    setState(() => _isLoading = false);

    result.when(
      success: (_) {
        context.push('/otp', extra: normalized);
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
                l10n?.myNumberIs ?? 'My Number Is',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n?.phoneNotice ??
                    'We will send an SMS with a 6-digit verification code. Standard carrier rates may apply.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              // Phone Input with Fixed +251 🇪🇹 Prefix
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FikirColors.lightBorder),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🇪🇹', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 8),
                        Text(
                          '+251',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      decoration: InputDecoration(
                        hintText: '0911 234 567',
                        errorText: _errorMessage,
                      ),
                      onChanged: (val) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        } else {
                          setState(() {});
                        }
                      },
                      onSubmitted: (_) => _isValid ? _submitPhone() : null,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Submit Button
              GradientButton(
                text: l10n?.continueAction ?? 'Continue',
                isLoading: _isLoading,
                onPressed: _isValid ? _submitPhone : null,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
