import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../api/api.dart';
import '../../ui/ui.dart';
import '../listings/listing_format.dart';

const _unset = Object();

/// A search: query text, filters and sort. Serialises to URL query
/// parameters so a search can be linked to, restored and saved.
@immutable
class SearchFilters {
  const SearchFilters({
    this.q = '',
    this.category,
    this.kind,
    this.minPricePaise,
    this.maxPricePaise,
    this.availableFrom,
    this.availableTo,
    this.sort = SearchSort.trust,
  });

  factory SearchFilters.fromQuery(Map<String, String> query) {
    T? parse<T>(String key, T? Function(String) fromJson) {
      final raw = query[key];
      return raw == null || raw.isEmpty ? null : fromJson(raw);
    }

    DateTime? date(String key) {
      final raw = query[key];
      final parsed = raw == null ? null : DateTime.tryParse(raw);
      return parsed == null
          ? null
          : DateTime.utc(parsed.year, parsed.month, parsed.day);
    }

    return SearchFilters(
      q: query['q'] ?? '',
      category: parse('category', ListingCategory.fromJson),
      kind: parse('kind', TradeKind.fromJson),
      minPricePaise: parse('min_price_paise', int.tryParse),
      maxPricePaise: parse('max_price_paise', int.tryParse),
      availableFrom: date('available_from'),
      availableTo: date('available_to'),
      sort: parse('sort', SearchSort.fromJson) ?? SearchSort.trust,
    );
  }

  final String q;
  final ListingCategory? category;
  final TradeKind? kind;
  final int? minPricePaise;
  final int? maxPricePaise;

  /// Calendar dates in IST (time parts are zero).
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final SearchSort sort;

  bool get hasDates => availableFrom != null || availableTo != null;

  bool get hasPrice => minPricePaise != null || maxPricePaise != null;

  /// Number of filters set (not counting the text or sort).
  int get activeCount => [
    category != null,
    kind != null,
    hasPrice,
    hasDates,
  ].where((set) => set).length;

  /// Start of [availableFrom] in IST, as an instant.
  DateTime? get availableFromInstant {
    final d = availableFrom;
    return d == null ? null : fromIst(d.year, d.month, d.day);
  }

  /// End of [availableTo] in IST (start of the next day), as an instant.
  DateTime? get availableToInstant {
    final d = availableTo;
    return d == null ? null : fromIst(d.year, d.month, d.day + 1);
  }

  SearchFilters copyWith({
    String? q,
    Object? category = _unset,
    Object? kind = _unset,
    Object? minPricePaise = _unset,
    Object? maxPricePaise = _unset,
    Object? availableFrom = _unset,
    Object? availableTo = _unset,
    SearchSort? sort,
  }) {
    T? pick<T>(Object? value, T? current) =>
        identical(value, _unset) ? current : value as T?;
    final nextKind = pick<TradeKind>(kind, this.kind);
    final forSale = nextKind == TradeKind.sale;
    return SearchFilters(
      q: q ?? this.q,
      category: pick(category, this.category),
      kind: nextKind,
      minPricePaise: pick(minPricePaise, this.minPricePaise),
      maxPricePaise: pick(maxPricePaise, this.maxPricePaise),
      // Availability only applies to rentals.
      availableFrom: forSale ? null : pick(availableFrom, this.availableFrom),
      availableTo: forSale ? null : pick(availableTo, this.availableTo),
      sort: sort ?? this.sort,
    );
  }

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Map<String, String> toQuery() => {
    if (q.isNotEmpty) 'q': q,
    if (category case final c?) 'category': c.json,
    if (kind case final k?) 'kind': k.json,
    if (minPricePaise case final p?) 'min_price_paise': '$p',
    if (maxPricePaise case final p?) 'max_price_paise': '$p',
    if (availableFrom case final d?) 'available_from': _dateFormat.format(d),
    if (availableTo case final d?) 'available_to': _dateFormat.format(d),
    if (sort != SearchSort.trust) 'sort': sort.json,
  };

  @override
  bool operator ==(Object other) =>
      other is SearchFilters && mapEquals(other.toQuery(), toQuery());

  @override
  int get hashCode => Object.hashAllUnordered(
    toQuery().entries.map((e) => '${e.key}=${e.value}'),
  );
}

String sortLabel(SearchSort sort) => switch (sort) {
  SearchSort.newest => 'Newest first',
  SearchSort.priceAsc => 'Price: low to high',
  SearchSort.priceDesc => 'Price: high to low',
  _ => 'Most trusted owners',
};

const searchSorts = [
  SearchSort.trust,
  SearchSort.newest,
  SearchSort.priceAsc,
  SearchSort.priceDesc,
];

/// Short labels for the active filters, e.g. for chips.
String priceRangeLabel(int? minPaise, int? maxPaise) {
  if (minPaise != null && maxPaise != null) {
    return '${formatMoney(minPaise)}–${formatMoney(maxPaise)}';
  }
  if (minPaise != null) return 'From ${formatMoney(minPaise)}';
  return 'Up to ${formatMoney(maxPaise ?? 0)}';
}

String dateRangeLabel(DateTime? from, DateTime? to) {
  final f = DateFormat('d MMM', 'en_US');
  if (from != null && to != null) return '${f.format(from)} – ${f.format(to)}';
  if (from != null) return 'From ${f.format(from)}';
  return 'Until ${f.format(to!)}';
}

String filterKindLabel(TradeKind kind) =>
    kind == TradeKind.sale ? 'Buy' : 'Rent';

String filterCategoryLabel(ListingCategory c) => categoryLabel(c);
