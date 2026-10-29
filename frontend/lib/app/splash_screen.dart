import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/ui.dart';
import 'session.dart';

/// Shown while the stored session is checked on app start.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: session.status == SessionStatus.restoreFailed
          ? ErrorState(
              title: 'Couldn’t sign you in',
              message: session.error,
              onRetry: ref.read(sessionProvider.notifier).restore,
            )
          : const LoadingState(message: 'Signing you in…'),
    );
  }
}
