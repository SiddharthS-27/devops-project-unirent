import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';

/// Mock Microsoft sign-in (AUTH_MODE=mock): the backend issues a
/// Microsoft-shaped ID token for any college email.
class CollegeEmailSignInScreen extends ConsumerStatefulWidget {
  const CollegeEmailSignInScreen({super.key});

  @override
  ConsumerState<CollegeEmailSignInScreen> createState() =>
      _CollegeEmailSignInScreenState();
}

class _CollegeEmailSignInScreenState
    extends ConsumerState<CollegeEmailSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final token = await api.auth.mockMicrosoftToken(
        MockTokenRequest(email: _email.text.trim()),
      );
      await ref
          .read(sessionProvider.notifier)
          .signInWithMicrosoft(token.idToken);
    } on Object catch (error) {
      if (mounted) setState(() => _error = friendlyMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('College account'),
        leading: BackButton(onPressed: () => context.go(Routes.signIn)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(
              'Development sign-in: enter your college email instead of '
              'signing in with Microsoft.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            OptionalInlineError(_error),
            AppTextField(
              controller: _email,
              label: 'College email',
              hint: 'name@college.edu',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                final email = value?.trim() ?? '';
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                    ? null
                    : 'Enter your college email address';
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'Continue', isLoading: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
