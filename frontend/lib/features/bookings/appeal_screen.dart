import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import 'booking_actions.dart';
import 'booking_providers.dart';
import 'handover_photos.dart';

const maxAppealPhotos = 8;

/// The reasons [booking]'s viewer can appeal for, with their labels.
List<(AppealReason, String)> appealReasonsFor(BookingOut booking) => [
  if (booking.kind == TradeKind.rent)
    (AppealReason.damageDispute, 'We can’t agree on the damage or late fee'),
  if (booking.role == BookingViewerRole.renter)
    (AppealReason.itemMismatch, 'The item isn’t what was listed'),
  (AppealReason.other, 'Something else'),
];

/// Files an appeal on a booking: reason, details and extra photos. The
/// handover photos go with it automatically.
class AppealScreen extends ConsumerWidget {
  const AppealScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('File an appeal'),
        leading: context.canPop()
            ? null
            : BackButton(
                onPressed: () => context.go(Routes.booking(bookingId)),
              ),
      ),
      body: booking.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        ),
        data: (b) => b.canAppeal
            ? _AppealForm(booking: b)
            : EmptyState(
                icon: Icons.gavel_outlined,
                title: 'This booking can’t be appealed now',
                message: b.appeal?.status == AppealStatus.open
                    ? 'An appeal is already being reviewed.'
                    : 'Rentals can be appealed once the item is back; '
                          'purchases for 48 hours after the handover.',
                action: AppButton.secondary(
                  label: 'Back to the booking',
                  expand: false,
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.booking(bookingId)),
                ),
              ),
      ),
    );
  }
}

class _AppealForm extends ConsumerStatefulWidget {
  const _AppealForm({required this.booking});

  final BookingOut booking;

  @override
  ConsumerState<_AppealForm> createState() => _AppealFormState();
}

class _AppealFormState extends ConsumerState<_AppealForm>
    with BookingActionRunner {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  late AppealReason? _reason = switch (appealReasonsFor(widget.booking)) {
    [(final only, _)] => only,
    _ => null,
  };
  String? _reasonError;
  final _photos = <String>[];
  bool _uploading = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final keys = await pickAndUploadHandoverPhotos(
        context,
        ref,
        max: maxAppealPhotos - _photos.length,
        purpose: UploadPurpose.appeal,
        onUploading: () {
          if (mounted) setState(() => _uploading = true);
        },
      );
      if (keys != null && mounted) {
        setState(
          () => _photos.addAll(keys.take(maxAppealPhotos - _photos.length)),
        );
      }
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final reason = _reason;
    setState(
      () => _reasonError = reason == null ? 'Choose what went wrong' : null,
    );
    final valid = _formKey.currentState!.validate();
    if (reason == null || !valid) return;
    final router = GoRouter.of(context);
    final b = widget.booking;
    final appeal = await runAction(
      'appeal',
      (key) => ref
          .read(apiProvider)
          .bookings
          .fileAppeal(
            b.id,
            AppealCreate(
              reason: reason,
              notes: _details.text.trim(),
              photoKeys: _photos.isEmpty ? null : [..._photos],
            ),
            idempotencyKey: key,
          ),
      bookingId: b.id,
      listingId: b.listing.id,
      done: 'Appeal filed. A moderator will look at it.',
    );
    if (appeal != null && mounted) {
      router.canPop() ? router.pop() : router.go(Routes.booking(b.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = widget.booking;
    final reasons = appealReasonsFor(b);
    final busy = busyAction != null;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Text(b.listing.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'A moderator reviews the handover photos, which are attached '
            'automatically, along with what you add here. Both sides are '
            'told the ruling.',
          ),
          const SizedBox(height: AppSpacing.xl),
          // Grouped so the error below doesn't shift the list's children.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'What went wrong?',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              RadioGroup<AppealReason>(
                groupValue: _reason,
                onChanged: (v) => setState(() {
                  _reason = v;
                  _reasonError = null;
                }),
                child: Column(
                  children: [
                    for (final (reason, label) in reasons)
                      RadioListTile<AppealReason>(
                        value: reason,
                        title: Text(label),
                        contentPadding: EdgeInsets.zero,
                        enabled: !busy,
                      ),
                  ],
                ),
              ),
              OptionalInlineError(_reasonError, gap: AppSpacing.sm),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _details,
            label: 'Details',
            hint: 'What happened, and what outcome you’re asking for',
            maxLines: 6,
            maxLength: 2000,
            enabled: !busy,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v?.trim().length ?? 0) < 5
                ? 'Describe what happened (at least 5 characters)'
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text('Photo evidence', style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Optional. Add up to $maxAppealPhotos photos that show the '
            'problem.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_photos.isNotEmpty)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (i, key) in _photos.indexed)
                  InputChip(
                    key: ValueKey(key),
                    avatar: const Icon(Icons.photo_outlined),
                    label: Text('Photo ${i + 1}'),
                    deleteButtonTooltipMessage: 'Remove photo ${i + 1}',
                    onDeleted: busy
                        ? null
                        : () => setState(() => _photos.remove(key)),
                  ),
              ],
            ),
          if (_photos.length < maxAppealPhotos)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy || _uploading ? null : _addPhotos,
                icon: _uploading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo_outlined),
                label: Text(_uploading ? 'Uploading…' : 'Add photos'),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          AppButton.primary(
            label: 'File appeal',
            isLoading: busy,
            onPressed: _uploading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
