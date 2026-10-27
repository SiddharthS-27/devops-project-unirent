import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';
import 'onboarding_scaffold.dart';
import 'terms_text.dart';

/// Onboarding step 3: accept the community rules (`POST /me/terms`).
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key});

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  Future<void> _accept(String version) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = ref.read(sessionProvider.notifier);
    try {
      final me = await ref
          .read(apiProvider)
          .profiles
          .acceptTerms(TermsIn(version: version));
      session.termsAccepted(me);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyMessage(error);
        _agreed = false;
      });
      // A newer version was published: reload it.
      if (error case ApiException(code: 'TERMS_OUTDATED')) {
        await session.refreshMe();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = ref.watch(sessionProvider).me?.currentTermsVersion ?? '';
    return OnboardingScaffold(
      step: OnboardingStep.terms,
      title: 'Community rules',
      children: [
        Text(
          'UniRent works because students trust each other. Please read and '
          'accept these rules.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final (index, (title, body)) in termsSections.indexed) ...[
          Text('${index + 1}. $title', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          'Version $version',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_error != null) ...[
          InlineError(_error!),
          const SizedBox(height: AppSpacing.lg),
        ],
        CheckboxListTile(
          value: _agreed,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('I have read and agree to the community rules'),
          onChanged: _busy
              ? null
              : (value) => setState(() => _agreed = value ?? false),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Accept and continue',
          isLoading: _busy,
          onPressed: _agreed && version.isNotEmpty
              ? () => _accept(version)
              : null,
        ),
      ],
    );
  }
}
