import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../listings/listing_format.dart';
import 'search_filters.dart';

/// The student's saved searches. Listing them marks their matches as seen on
/// the server, so `new_match_count` is "new since you last looked".
final savedSearchesProvider = FutureProvider.autoDispose<List<SavedSearchOut>>(
  (ref) => ref.watch(apiProvider).search.listSavedSearches(),
);

/// Whether [filters] has anything a saved search can store. Dates and sort
/// aren't part of saved searches.
bool canSaveSearch(SearchFilters filters) =>
    filters.q.isNotEmpty ||
    filters.category != null ||
    filters.kind != null ||
    filters.hasPrice;

SavedSearchIn savedSearchFrom(SearchFilters filters, {String? name}) =>
    SavedSearchIn(
      name: name == null || name.trim().isEmpty ? null : name.trim(),
      q: filters.q.isEmpty ? null : filters.q,
      category: filters.category,
      kind: filters.kind,
      minPricePaise: filters.minPricePaise,
      maxPricePaise: filters.maxPricePaise,
    );

SearchFilters filtersFromSaved(SavedSearchOut saved) => SearchFilters(
  q: saved.q ?? '',
  category: saved.category,
  kind: saved.kind,
  minPricePaise: saved.minPricePaise,
  maxPricePaise: saved.maxPricePaise,
);

/// "“camera” · Cameras · Rent · Up to ₹500".
String describeSearch(SearchFilters f) => [
  if (f.q.isNotEmpty) '“${f.q}”',
  if (f.category case final c?) categoryLabel(c),
  if (f.kind case final k?) filterKindLabel(k),
  if (f.hasPrice) priceRangeLabel(f.minPricePaise, f.maxPricePaise),
].join(' · ');

/// A name to suggest when saving [filters].
String suggestedSearchName(SearchFilters f) {
  if (f.q.isNotEmpty) return f.q;
  if (f.category case final c?) return categoryLabel(c);
  return describeSearch(f);
}
