import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../app/env.dart';
import '../../app/error_messages.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';
import 'onboarding_scaffold.dart';
import 'phone_verifier.dart';

/// Validates a 10-digit Indian mobile number (without +91).
String? validateIndianMobile(String? value) {
  final digits = value?.trim() ?? '';
  return RegExp(r'^[6-9]\d{9}$').hasMatch(digits)
      ? null
      : 'Enter a 10-digit mobile number';
}

/// Onboarding step 2: verify a phone number by SMS code.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _code = TextEditingController();
  PhoneCodeRequest? _request;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyMessage(error));
      if (error
          case ApiException(code: 'WRONG_CODE') ||
              UserFacingException(code: 'WRONG_CODE')) {
        _code.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = '+91${_number.text.trim()}';
    await _run(() async {
      final request = await ref
          .read(phoneVerifierProvider)
          .sendCode(phone, previous: _request);
      final verified = request.verifiedIdToken;
      if (verified != null) {
        await _submitToken(verified);
      } else if (mounted) {
        setState(() => _request = request);
      }
    });
  }

  Future<void> _verify(String code) async {
    final request = _request;
    if (request == null || code.length != 6 || _busy) return;
    await _run(() async {
      final token = await ref
          .read(phoneVerifierProvider)
          .confirm(request, code);
      await _submitToken(token);
    });
  }

  Future<void> _submitToken(String firebaseIdToken) async {
    await ref
        .read(apiProvider)
        .auth
        .verifyPhone(PhoneVerify(firebaseIdToken: firebaseIdToken));
    await ref.read(sessionProvider.notifier).refreshMe();
  }

  void _changeNumber() {
    _code.clear();
    setState(() {
      _request = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return OnboardingScaffold(
      step: OnboardingStep.phone,
      title: 'Phone number',
      children: request == null ? _numberStep() : _codeStep(request),
    );
  }

  List<Widget> _numberStep() => [
    const Text(
      'Renters and owners use your number to coordinate pickups. '
      'We’ll text you a 6-digit code to verify it.',
    ),
    const SizedBox(height: AppSpacing.lg),
    if (_error != null) ...[
      InlineError(_error!),
      const SizedBox(height: AppSpacing.lg),
    ],
    Form(
      key: _formKey,
      child: AppTextField(
        controller: _number,
        label: 'Mobile number',
        prefixText: '+91 ',
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumberNational],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        validator: validateIndianMobile,
        onSubmitted: (_) => _sendCode(),
      ),
    ),
    const SizedBox(height: AppSpacing.xl),
    AppButton(label: 'Send code', isLoading: _busy, onPressed: _sendCode),
  ];

  List<Widget> _codeStep(PhoneCodeRequest request) {
    final isMock =
        ref.watch(appEnvProvider).phoneAuthMode == PhoneAuthMode.mock;
    return [
      Text('Enter the 6-digit code sent to ${request.phone}.'),
      if (isMock) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Development build: no SMS is sent. The code is 123456.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      Center(
        child: OtpEntry(
          controller: _code,
          autofocus: true,
          enabled: !_busy,
          errorText: _error,
          onCompleted: _verify,
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      AppButton(
        label: 'Verify',
        isLoading: _busy,
        onPressed: () => _verify(_code.text),
      ),
      const SizedBox(height: AppSpacing.sm),
      // Wraps on narrow screens or with large text.
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _busy ? null : _changeNumber,
            child: const Text('Change number'),
          ),
          TextButton(
            onPressed: _busy ? null : _sendCode,
            child: const Text('Resend code'),
          ),
        ],
      ),
    ];
  }
}
