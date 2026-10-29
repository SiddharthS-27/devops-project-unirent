import 'package:flutter/material.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';

/// Who wrote a support or chat message, as shown above it.
String messageAuthorLabel(
  MessageAuthor author,
  String? authorName, {
  required bool viewerIsStaff,
}) => switch (author) {
  MessageAuthor.user when !viewerIsStaff => 'You',
  MessageAuthor.user => authorName ?? 'Student',
  MessageAuthor.bot => 'UniRent bot',
  MessageAuthor.moderator when viewerIsStaff => authorName ?? 'Moderator',
  MessageAuthor.moderator =>
    authorName == null ? 'Moderator' : 'Moderator · $authorName',
  MessageAuthor.unknown => 'UniRent',
};

/// One message in a chat; the viewer's own messages sit on the right.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.label,
    required this.body,
    required this.mine,
    this.at,
    this.highlight = false,
    this.footer,
  });

  final String label;
  final String body;
  final bool mine;
  final DateTime? at;

  /// Marks a moderator's message.
  final bool highlight;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = mine
        ? scheme.primaryContainer
        : highlight
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerHigh;
    final foreground = mine
        ? scheme.onPrimaryContainer
        : highlight
        ? scheme.onTertiaryContainer
        : scheme.onSurface;
    final at = this.at;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                at == null ? label : '$label · ${formatIstDateTime(at)}',
                style: theme.textTheme.labelSmall?.copyWith(color: foreground),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// A text box with a send button, pinned under a chat.
class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.hint,
    this.sending = false,
    this.maxLength,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hint;
  final bool sending;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !sending,
                minLines: 1,
                maxLines: 4,
                maxLength: maxLength,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(hintText: hint, counterText: ''),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            sending
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton.filled(
                    tooltip: 'Send',
                    icon: const Icon(Icons.send),
                    onPressed: onSend,
                  ),
          ],
        ),
      ),
    );
  }
}
