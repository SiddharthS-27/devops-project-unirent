import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/error_messages.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';

/// Minimum staff password length (mirrors the backend).
const staffPasswordMinLength = 10;

/// Validates a new staff password the way the backend does.
String? validateStaffPassword(String? value, {required String email}) {
  final password = value ?? '';
  if (password.length < staffPasswordMinLength) {
    return 'Use at least $staffPasswordMinLength characters';
  }
  if (email.toLowerCase().contains(password.toLowerCase())) {
    return 'The password can’t contain your email';
  }
  return null;
}

/// Replaces a temporary staff password (`must_change_password`).
class StaffPasswordScreen extends ConsumerStatefulWidget {
  const StaffPasswordScreen({super.key});

  @override
  ConsumerState<StaffPasswordScreen> createState() =>
      _StaffPasswordScreenState();
}

class _StaffPasswordScreenState extends ConsumerState<StaffPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .changeStaffPassword(_password.text);
    } on Object catch (error) {
      if (mounted) setState(() => _error = friendlyMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(sessionProvider).staffEmail ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set a new password'),
        leading: CloseButton(
          onPressed: ref.read(sessionProvider.notifier).cancelPasswordChange,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(
              'You signed in with a temporary password. Choose a new one for '
              '$email to continue.',
            ),
            const SizedBox(height: AppSpacing.lg),
            OptionalInlineError(_error),
            AppTextField(
              controller: _password,
              label: 'New password',
              helperText: 'At least $staffPasswordMinLength characters',
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              validator: (v) => validateStaffPassword(v, email: email),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _confirm,
              label: 'Confirm new password',
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  v == _password.text ? null : 'The passwords don’t match',
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Save password',
              isLoading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
