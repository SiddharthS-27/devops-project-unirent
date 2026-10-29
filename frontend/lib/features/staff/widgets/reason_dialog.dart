import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Asks staff why they are taking an action (3-1000 characters, recorded
/// and sent to the student). Returns the reason, or null if cancelled.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      _ReasonDialog(title: title, confirmLabel: confirmLabel, message: message),
);

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.confirmLabel,
    this.message,
  });

  final String title;
  final String confirmLabel;
  final String? message;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message case final message?) ...[
              Text(message),
              const SizedBox(height: AppSpacing.md),
            ],
            AppTextField(
              controller: _reason,
              label: 'Reason',
              maxLines: 3,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v?.trim().length ?? 0) < 3
                  ? 'Give a reason (at least 3 characters)'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _reason.text.trim());
            }
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
