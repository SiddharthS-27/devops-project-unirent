import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/env.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';
import 'microsoft_auth.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _continue() async {
    if (ref.read(appEnvProvider).authMode == AuthMode.mock) {
      context.go(Routes.signInWithEmail);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final idToken = await ref.read(microsoftAuthProvider).signIn();
      if (idToken == null) return; // Cancelled.
      // The router moves on once the session changes.
      await ref.read(sessionProvider.notifier).signInWithMicrosoft(idToken);
    } on Object catch (error) {
      if (mounted) setState(() => _error = friendlyMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Welcome to UniRent',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Rent and resell with students on your campus.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (_error != null) ...[
                    InlineError(_error!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  AppButton(
                    label: 'Continue with college Microsoft account',
                    icon: Icons.login,
                    isLoading: _busy,
                    onPressed: _continue,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => context.go(Routes.staffSignIn),
                    child: const Text('Staff sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
