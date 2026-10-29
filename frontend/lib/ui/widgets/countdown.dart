import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Formats a duration as `2d 3h 4m 5s`, dropping leading zero units
/// (`4m 5s`, `45s`). The sign is ignored.
String formatCountdown(Duration duration) {
  final total = duration.inSeconds.abs();
  final days = total ~/ Duration.secondsPerDay;
  final hours = total % Duration.secondsPerDay ~/ Duration.secondsPerHour;
  final minutes = total % Duration.secondsPerHour ~/ Duration.secondsPerMinute;
  final seconds = total % Duration.secondsPerMinute;

  return [
    if (days > 0) '${days}d',
    if (days > 0 || hours > 0) '${hours}h',
    if (days > 0 || hours > 0 || minutes > 0) '${minutes}m',
    '${seconds}s',
  ].join(' ');
}

/// The countdown in words for screen readers: "2 days 3 hours 4 minutes",
/// with seconds only in the last hour.
String spokenCountdown(Duration duration) {
  final total = duration.inSeconds.abs();
  final days = total ~/ Duration.secondsPerDay;
  final hours = total % Duration.secondsPerDay ~/ Duration.secondsPerHour;
  final minutes = total % Duration.secondsPerHour ~/ Duration.secondsPerMinute;
  final seconds = total % Duration.secondsPerMinute;
  String unit(int n, String name) => '$n $name${n == 1 ? '' : 's'}';
  final parts = [
    if (days > 0) unit(days, 'day'),
    if (hours > 0) unit(hours, 'hour'),
    if (minutes > 0) unit(minutes, 'minute'),
    if (total < Duration.secondsPerHour && (seconds > 0 || total == 0))
      unit(seconds, 'second'),
  ];
  return parts.join(' ');
}

/// Offset to add to the device clock to get server time, computed from a
/// server-reported `now`.
Duration serverClockOffset(DateTime serverNow, {DateTime? deviceNow}) =>
    serverNow.difference(deviceNow ?? DateTime.now());

/// Live countdown to a server-provided [target] that ticks every second.
///
/// Device clocks drift, so the remaining time is computed against server
/// time: device now + [serverOffset] (see [serverClockOffset]). Once the
/// target passes, it counts up in the error colour ("Overdue by 5m 2s").
class Countdown extends StatefulWidget {
  const Countdown({
    super.key,
    required this.target,
    this.serverOffset = Duration.zero,
    this.label,
    this.overdueLabel = 'Overdue by',
    this.overdueText,
    this.style,
    this.onElapsed,
    this.clock = DateTime.now,
  });

  final DateTime target;
  final Duration serverOffset;

  /// Prefix while time remains, e.g. "Return in".
  final String? label;

  /// Prefix once overdue.
  final String overdueLabel;

  /// Fixed text to show instead of the overdue duration, e.g. "Expired".
  final String? overdueText;
  final TextStyle? style;

  /// Called once when the countdown reaches zero while mounted.
  final VoidCallback? onElapsed;

  /// Device clock; injectable for tests.
  final DateTime Function() clock;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    _remaining = _computeRemaining();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _computeRemaining() =>
      widget.target.difference(widget.clock().add(widget.serverOffset));

  void _tick() {
    final next = _computeRemaining();
    if (_remaining > Duration.zero && next <= Duration.zero) {
      widget.onElapsed?.call();
    }
    setState(() => _remaining = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = _remaining.isNegative;
    // Round remaining time up so "1s" shows until the target is reached.
    final shown = overdue
        ? _remaining
        : Duration(seconds: (_remaining.inMilliseconds + 999) ~/ 1000);

    final String text;
    final String spoken;
    if (overdue) {
      text =
          widget.overdueText ??
          '${widget.overdueLabel} ${formatCountdown(shown)}';
      spoken =
          widget.overdueText ??
          '${widget.overdueLabel} ${spokenCountdown(shown)}';
    } else {
      final label = widget.label;
      text = label == null
          ? formatCountdown(shown)
          : '$label ${formatCountdown(shown)}';
      spoken = label == null
          ? spokenCountdown(shown)
          : '$label ${spokenCountdown(shown)}';
    }

    final base =
        widget.style ?? theme.textTheme.bodyMedium ?? const TextStyle();
    return Text(
      text,
      // "4m 5s" reads badly aloud; say the units in full.
      semanticsLabel: spoken,
      style: base.copyWith(
        fontFeatures: AppTypography.tabularFigures,
        color: overdue ? theme.colorScheme.error : null,
        fontWeight: overdue ? FontWeight.w600 : null,
      ),
    );
  }
}
