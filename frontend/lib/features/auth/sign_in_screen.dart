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
    final muted = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            // The name at the top, the pitch and the one action together at
            // the bottom; the column scrolls only when the screen is short.
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.sm),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: UniRentWordmark(markSize: 28),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Welcome to UniRent',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Rent and resell with students on your campus. '
                          'Cameras, cycles, books and more, handed over in '
                          'person with a code.',
                          style: muted,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        for (final (step, detail) in const [
                          ('List what you own', 'Set a price per hour or day.'),
                          (
                            'Request with dates',
                            'The owner approves within 24 hours.',
                          ),
                          (
                            'Hand over with a code',
                            'Photos and a 6-digit code on both sides.',
                          ),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(step, style: theme.textTheme.titleSmall),
                                Text(
                                  detail,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        if (_error != null) ...[
                          InlineError(_error!),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        AppButton(
                          label: 'Continue with college Microsoft account',
                          isLoading: _busy,
                          onPressed: _continue,
                        ),
                        const SizedBox(height: AppSpacing.sm),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
