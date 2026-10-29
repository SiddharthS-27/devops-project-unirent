import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import 'countdown.dart';

/// Shows a one-time code in large digits, with an optional expiry countdown.
class OtpDisplay extends StatelessWidget {
  const OtpDisplay({
    super.key,
    required this.code,
    this.expiresAt,
    this.serverOffset = Duration.zero,
    this.clock = DateTime.now,
  });

  final String code;
  final DateTime? expiresAt;
  final Duration serverOffset;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final half = code.length ~/ 2;
    final grouped = code.length == 6
        ? '${code.substring(0, half)} ${code.substring(half)}'
        : code;
    final expiresAt = this.expiresAt;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Code ${code.split('').join(' ')}',
          child: ExcludeSemantics(
            child: SelectableText(
              grouped,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                letterSpacing: 6,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ),
        ),
        if (expiresAt != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Countdown(
            target: expiresAt,
            serverOffset: serverOffset,
            clock: clock,
            label: 'Expires in',
            overdueText: 'Code expired',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Entry for a numeric one-time code, drawn as one box per digit.
///
/// A single (invisible) text field underneath handles input, paste and SMS
/// autofill; the boxes only mirror its contents.
class OtpEntry extends StatefulWidget {
  const OtpEntry({
    super.key,
    this.length = 6,
    this.controller,
    this.onChanged,
    this.onCompleted,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
    this.semanticLabel = 'One-time code',
  });

  final int length;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Called when all [length] digits have been entered.
  final ValueChanged<String>? onCompleted;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final String semanticLabel;

  @override
  State<OtpEntry> createState() => _OtpEntryState();
}

class _OtpEntryState extends State<OtpEntry> {
  TextEditingController? _ownController;
  final FocusNode _focusNode = FocusNode();

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_rebuild);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _handleChanged(String value) {
    setState(() {});
    widget.onChanged?.call(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = _controller.text;
    final hasError = widget.errorText != null;
    final activeIndex = text.length.clamp(0, widget.length - 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.length; i++)
                    Container(
                      width: 44,
                      height: 52,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: hasError
                              ? scheme.error
                              : _focusNode.hasFocus && i == activeIndex
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: _focusNode.hasFocus && i == activeIndex
                              ? 2
                              : 1,
                        ),
                      ),
                      child: Text(
                        i < text.length ? text[i] : '',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFeatures: AppTypography.tabularFigures,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                alwaysIncludeSemantics: true,
                child: Semantics(
                  label: widget.semanticLabel,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                      counterText: '',
                    ),
                    onChanged: _handleChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.errorText!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}
