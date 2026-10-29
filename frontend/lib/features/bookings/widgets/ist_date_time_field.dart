import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Asks for a date then a time, read as India Standard Time whatever the
/// device's time zone. Returns the instant, or null if cancelled.
Future<DateTime?> pickIstDateTime(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) async {
  DateTime asLocalDate(DateTime instant) {
    final ist = toIst(instant);
    return DateTime(ist.year, ist.month, ist.day);
  }

  final date = await showDatePicker(
    context: context,
    initialDate: asLocalDate(initial),
    firstDate: asLocalDate(first),
    lastDate: asLocalDate(last),
  );
  if (date == null || !context.mounted) return null;
  final ist = toIst(initial);
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: ist.hour, minute: ist.minute),
    helpText: 'Time (IST)',
  );
  if (time == null) return null;
  return fromIst(date.year, date.month, date.day, time.hour, time.minute);
}

/// A tappable field showing an IST date and time.
class IstDateTimeField extends StatelessWidget {
  const IstDateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = '${formatIstShortDate(value)}, ${formatIstTime(value)}';
    return Semantics(
      button: true,
      label: '$label, $text',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.edit_calendar_outlined),
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }
}
