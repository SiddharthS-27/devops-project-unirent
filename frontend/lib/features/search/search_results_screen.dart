import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import '../listings/listing_format.dart';
import '../listings/widgets/listing_tiles.dart';
import 'filter_sheet.dart';
import 'search_filters.dart';

/// Search results with filters, sort and cursor-based infinite scroll.
class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key, required this.initial});

  final SearchFilters initial;

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  static const pageSize = 20;

  late SearchFilters _filters = widget.initial;
  late final _query = TextEditingController(text: widget.initial.q);
  final _scroll = ScrollController();

  final _items = <ListingCard>[];
  String? _cursor;
  bool _done = false;
  bool _loading = false;
  Object? _error;

  /// Bumped on every new search so late responses for old ones are dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_loadMore());
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 600) unawaited(_loadMore());
  }

  void _apply(SearchFilters filters) {
    _generation++;
    setState(() {
      _filters = filters;
      _items.clear();
      _cursor = null;
      _done = false;
      _loading = false;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final f = _filters;
      final page = await ref
          .read(apiProvider)
          .search
          .search(
            q: f.q.isEmpty ? null : f.q,
            category: f.category,
            kind: f.kind,
            minPricePaise: f.minPricePaise,
            maxPricePaise: f.maxPricePaise,
            availableFrom: f.availableFromInstant,
            availableTo: f.availableToInstant,
            sort: f.sort,
            cursor: _cursor,
            limit: pageSize,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
        _loading = false;
      });
      // Keep loading until the list fills the screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients && !_done) _onScroll();
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _openFilters() async {
    final next = await showFilterSheet(context, _filters);
    if (next != null && next != _filters) _apply(next);
  }

  void _openListing(ListingCard listing) =>
      context.push(Routes.listing(listing.id));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search listings',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onSubmitted: (q) => _apply(_filters.copyWith(q: q.trim())),
        ),
        actions: [
          PopupMenuButton<SearchSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _filters.sort,
            onSelected: (sort) => _apply(_filters.copyWith(sort: sort)),
            itemBuilder: (context) => [
              for (final sort in searchSorts)
                CheckedPopupMenuItem(
                  value: sort,
                  checked: sort == _filters.sort,
                  child: Text(sortLabel(sort)),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: _filters.activeCount > 0,
              label: Text('${_filters.activeCount}'),
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _ActiveFilters(filters: _filters, onChanged: _apply),
          Expanded(child: _results()),
        ],
      ),
    );
  }

  Widget _results() {
    if (_items.isEmpty) {
      if (_error != null) {
        return ErrorState(
          message: friendlyMessage(_error!),
          onRetry: () => _apply(_filters),
        );
      }
      if (!_done) return const LoadingState();
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        message: 'Try different words or fewer filters.',
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.screen),
      itemCount: _items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index < _items.length) {
          final listing = _items[index];
          return ListingTile(
            listing: listing,
            onTap: () => _openListing(listing),
          );
        }
        return _footer();
      },
    );
  }

  Widget _footer() {
    if (_error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadMore,
          icon: const Icon(Icons.refresh),
          label: const Text('Couldn’t load more. Try again'),
        ),
      );
    }
    if (_done) return const SizedBox(height: AppSpacing.xl);
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Removable chips for the filters in use.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.filters, required this.onChanged});

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final f = filters;
    final chips = [
      if (f.category case final c?)
        _chip(categoryLabel(c), () => onChanged(f.copyWith(category: null))),
      if (f.kind case final k?)
        _chip(filterKindLabel(k), () => onChanged(f.copyWith(kind: null))),
      if (f.hasPrice)
        _chip(
          priceRangeLabel(f.minPricePaise, f.maxPricePaise),
          () => onChanged(f.copyWith(minPricePaise: null, maxPricePaise: null)),
        ),
      if (f.hasDates)
        _chip(
          dateRangeLabel(f.availableFrom, f.availableTo),
          () => onChanged(f.copyWith(availableFrom: null, availableTo: null)),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: chips,
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onDeleted) => InputChip(
    label: Text(label),
    onDeleted: onDeleted,
    deleteButtonTooltipMessage: 'Remove $label filter',
  );
}
