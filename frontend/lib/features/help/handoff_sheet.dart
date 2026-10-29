import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../ui/ui.dart';

/// Asks what the student needs, then hands the chat to a moderator.
/// Returns the new conversation, or null if cancelled.
Future<SupportThreadOut?> showHandoffSheet(
  BuildContext context, {
  required List<TranscriptLine> transcript,
  String? bookingId,
}) => showModalBottomSheet<SupportThreadOut>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) =>
      _HandoffSheet(transcript: transcript, bookingId: bookingId),
);

class _HandoffSheet extends ConsumerStatefulWidget {
  const _HandoffSheet({required this.transcript, this.bookingId});

  final List<TranscriptLine> transcript;
  final String? bookingId;

  @override
  ConsumerState<_HandoffSheet> createState() => _HandoffSheetState();
}

class _HandoffSheetState extends ConsumerState<_HandoffSheet> {
  final _message = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Tell the moderator what you need help with.');
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });
    final navigator = Navigator.of(context);
    try {
      final thread = await ref
          .read(apiProvider)
          .help
          .handoff(
            HandoffIn(
              message: text,
              bookingId: widget.bookingId,
              transcript: widget.transcript.isEmpty ? null : widget.transcript,
            ),
          );
      if (mounted) navigator.pop(thread);
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = friendlyMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Talk to a moderator', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                'A moderator replies here in Help, usually within a day.',
                if (widget.transcript.isNotEmpty)
                  'They will see your chat with the bot.',
                if (widget.bookingId != null)
                  'This booking is attached so they can look it up.',
              ].join(' '),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _message,
              label: 'What do you need help with?',
              errorText: _error,
              maxLength: 1000,
              maxLines: 6,
              enabled: !_sending,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: 'Send to a moderator',
              icon: Icons.send,
              isLoading: _sending,
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}
