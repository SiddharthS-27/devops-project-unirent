import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../ui/ui.dart';
import '../staff_format.dart';

final moderatorsProvider = FutureProvider.autoDispose<List<StaffAccountOut>>(
  (ref) => ref.watch(apiProvider).admin.listModerators(),
);

/// The moderators, and adding one with a temporary password.
class ModeratorsScreen extends ConsumerWidget {
  const ModeratorsScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final created = await showDialog<StaffAccountOut>(
      context: context,
      builder: (context) => const _CreateDialog(),
    );
    if (created == null) return;
    ref.invalidate(moderatorsProvider);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${created.name ?? created.email} added. Share the temporary '
            'password with them; they set their own when they first sign in.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moderators = ref.watch(moderatorsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add moderator'),
      ),
      body: moderators.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(moderatorsProvider),
        ),
        data: (mods) => RefreshIndicator(
          onRefresh: () => ref.refresh(moderatorsProvider.future),
          child: mods.isEmpty
              ? ListView(
                  children: const [
                    EmptyState(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'No moderators yet',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: mods.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final m = mods[i];
                    return ListTile(
                      leading: const Icon(Icons.shield_outlined),
                      title: Text(m.name ?? m.email),
                      subtitle: Text(
                        [
                          m.email,
                          'Added ${formatIstDate(m.createdAt)}',
                          m.lastLoginAt == null
                              ? 'Never signed in'
                              : 'Last signed in '
                                    '${formatIstDateTime(m.lastLoginAt!)}',
                        ].join('\n'),
                        style: theme.textTheme.bodySmall,
                      ),
                      isThreeLine: true,
                      trailing: m.status == 'active'
                          ? null
                          : Chip(label: Text(accountStatusLabel(m.status))),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _CreateDialog extends ConsumerStatefulWidget {
  const _CreateDialog();

  @override
  ConsumerState<_CreateDialog> createState() => _CreateDialogState();
}

class _CreateDialogState extends ConsumerState<_CreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(apiProvider)
          .admin
          .createModerator(
            ModeratorCreate(
              name: _name.text.trim(),
              email: _email.text.trim(),
              temporaryPassword: _password.text,
            ),
          );
      navigator.pop(created);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is ApiException && error.code == 'EMAIL_IN_USE'
            ? 'An account with this email already exists.'
            : friendlyMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add moderator'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _name,
                label: 'Name',
                maxLength: 200,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Enter their name' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                enabled: !_saving,
                validator: (v) =>
                    RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Enter a valid email',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _password,
                label: 'Temporary password',
                helperText: 'They replace it when they first sign in',
                maxLength: 200,
                enabled: !_saving,
                validator: (v) =>
                    (v?.length ?? 0) < 8 ? 'Use at least 8 characters' : null,
              ),
              OptionalInlineError(_error, gap: AppSpacing.md),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
