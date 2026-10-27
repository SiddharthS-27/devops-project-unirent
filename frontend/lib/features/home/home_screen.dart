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
import '../search/search_filters.dart';

final homeProvider = FutureProvider.autoDispose<HomeOut>(
  (ref) => ref.watch(apiProvider).search.home(),
);

/// How long typing must pause before suggestions are fetched.
const suggestDebounce = Duration(milliseconds: 250);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<Suggestion>? _suggestions;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    setState(() {
      _query = query;
      if (query.isEmpty) _suggestions = null;
    });
    if (query.isEmpty) return;
    _debounce = Timer(suggestDebounce, () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    List<Suggestion> results;
    try {
      final q = query.length > 100 ? query.substring(0, 100) : query;
      results = await ref.read(apiProvider).search.suggest(q: q);
    } on ApiException {
      results = const [];
    }
    // Ignore answers for text the user has since changed.
    if (mounted && query == _query) setState(() => _suggestions = results);
  }

  void _clear() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _query = '';
      _suggestions = null;
    });
  }

  void _openSearch(SearchFilters filters) =>
      context.push(Routes.searchFor(filters));

  void _openListing(String id) => context.push(Routes.listing(id));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UniRent')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (q) {
                if (q.trim().isNotEmpty) {
                  _openSearch(SearchFilters(q: q.trim()));
                }
              },
              decoration: InputDecoration(
                hintText: 'Search cameras, cycles, books…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: _clear,
                      ),
              ),
            ),
          ),
          Expanded(child: _query.isEmpty ? _homeContent() : _suggestionList()),
        ],
      ),
    );
  }

  Widget _suggestionList() {
    final suggestions = _suggestions;
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.search),
          title: Text('Search for “$_query”'),
          onTap: () => _openSearch(SearchFilters(q: _query)),
        ),
        if (suggestions == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (final s in suggestions)
            ListTile(
              leading: Icon(categoryIcon(s.category)),
              title: Text(s.title),
              subtitle: Text(
                '${filterKindLabel(s.kind)} · ${categoryLabel(s.category)}',
              ),
              onTap: () => _openListing(s.listingId),
            ),
      ],
    );
  }

  Widget _homeContent() {
    final home = ref.watch(homeProvider);
    return home.when(
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: friendlyMessage(error),
        onRetry: () => ref.invalidate(homeProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () => ref.refresh(homeProvider.future),
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            const _SectionTitle('Browse categories'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen,
              ),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final c in data.categories)
                    ActionChip(
                      avatar: Icon(categoryIcon(c.key), size: 18),
                      label: Text(c.label),
                      onPressed: () =>
                          _openSearch(SearchFilters(category: c.key)),
                    ),
                ],
              ),
            ),
            if (data.savedSearchMatches.isNotEmpty) ...[
              const _SectionTitle('New for your saved searches'),
              _Carousel(
                listings: data.savedSearchMatches,
                onTap: (l) => _openListing(l.id),
              ),
            ],
            const _SectionTitle('Recently listed'),
            if (data.recent.isEmpty)
              const EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Nothing listed yet',
                message: 'Be the first to list something on your campus.',
              )
            else
              for (final listing in data.recent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    0,
                    AppSpacing.screen,
                    AppSpacing.md,
                  ),
                  child: ListingTile(
                    listing: listing,
                    onTap: () => _openListing(listing.id),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.xl,
        AppSpacing.screen,
        AppSpacing.md,
      ),
      child: Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _Carousel extends StatelessWidget {
  const _Carousel({required this.listings, required this.onTap});

  final List<ListingCard> listings;
  final ValueChanged<ListingCard> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemCount: listings.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) => ListingMiniCard(
          listing: listings[i],
          onTap: () => onTap(listings[i]),
        ),
      ),
    );
  }
}
