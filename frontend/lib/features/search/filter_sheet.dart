import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api.dart';
import '../../ui/ui.dart';
import '../listings/listing_format.dart';
import 'search_filters.dart';

/// Opens the filter sheet; returns the new filters, or null if dismissed.
Future<SearchFilters?> showFilterSheet(
  BuildContext context,
  SearchFilters current,
) {
  return showModalBottomSheet<SearchFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => FilterSheet(initial: current),
  );
}

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.initial});

  final SearchFilters initial;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  final _formKey = GlobalKey<FormState>();
  late SearchFilters _filters = widget.initial;
  late final _min = TextEditingController(
    text: _rupees(_filters.minPricePaise),
  );
  late final _max = TextEditingController(
    text: _rupees(_filters.maxPricePaise),
  );

  static String _rupees(int? paise) => paise == null ? '' : '${paise ~/ 100}';

  static int? _paise(String text) {
    final rupees = int.tryParse(text.trim());
    return rupees == null ? null : rupees * 100;
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final today = toIst(DateTime.now());
    final first = DateTime(today.year, today.month, today.day);
    final from = _filters.availableFrom;
    final to = _filters.availableTo;
    final range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: first.add(const Duration(days: 180)),
      initialDateRange: from == null || to == null
          ? null
          : DateTimeRange(
              start: DateTime(from.year, from.month, from.day),
              end: DateTime(to.year, to.month, to.day),
            ),
      helpText: 'Available between',
    );
    if (range == null) return;
    setState(() {
      _filters = _filters.copyWith(
        availableFrom: DateTime.utc(
          range.start.year,
          range.start.month,
          range.start.day,
        ),
        availableTo: DateTime.utc(
          range.end.year,
          range.end.month,
          range.end.day,
        ),
      );
    });
  }

  void _apply() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _filters.copyWith(
        minPricePaise: _paise(_min.text),
        maxPricePaise: _paise(_max.text),
      ),
    );
  }

  void _reset() {
    _min.clear();
    _max.clear();
    setState(() {
      _filters = SearchFilters(q: _filters.q, sort: _filters.sort);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: AppSpacing.lg);
    final kindValue = _filters.kind?.json ?? 'any';
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screen,
        right: AppSpacing.screen,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filters', style: theme.textTheme.titleLarge),
              gap,
              DropdownButtonFormField<ListingCategory?>(
                initialValue: _filters.category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(child: Text('All categories')),
                  for (final c in listingCategories)
                    DropdownMenuItem(value: c, child: Text(categoryLabel(c))),
                ],
                onChanged: (c) =>
                    setState(() => _filters = _filters.copyWith(category: c)),
              ),
              gap,
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'any', label: Text('Any')),
                  ButtonSegment(value: 'rent', label: Text('Rent')),
                  ButtonSegment(value: 'sale', label: Text('Buy')),
                ],
                selected: {kindValue},
                onSelectionChanged: (s) => setState(() {
                  final value = s.single;
                  _filters = _filters.copyWith(
                    kind: value == 'any' ? null : TradeKind.fromJson(value),
                  );
                }),
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _min,
                      label: 'Min price',
                      prefixText: '₹',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _max,
                      label: 'Max price',
                      prefixText: '₹',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final min = _paise(_min.text);
                        final max = _paise(value ?? '');
                        return min != null && max != null && max < min
                            ? 'Must be at least the minimum'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              if (_filters.kind != TradeKind.sale) ...[
                gap,
                OutlinedButton.icon(
                  onPressed: _pickDates,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    _filters.hasDates
                        ? 'Available ${dateRangeLabel(_filters.availableFrom, _filters.availableTo)}'
                        : 'Available dates (rentals)',
                  ),
                ),
                if (_filters.hasDates)
                  TextButton(
                    onPressed: () => setState(() {
                      _filters = _filters.copyWith(
                        availableFrom: null,
                        availableTo: null,
                      );
                    }),
                    child: const Text('Clear dates'),
                  ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(label: 'Show results', onPressed: _apply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
