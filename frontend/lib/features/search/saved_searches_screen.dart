import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import 'saved_searches.dart';

class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SavedSearchOut saved,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this saved search?'),
        content: const Text('You’ll stop hearing about new matches for it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).search.deleteSavedSearch(saved.id);
      ref.invalidate(savedSearchesProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Saved search deleted')),
      );
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedSearchesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved searches')),
      body: saved.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(savedSearchesProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.bookmarks_outlined,
                title: 'No saved searches',
                message:
                    'Save a search from the results to hear about new '
                    'matches on your Home tab.',
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, i) {
                  final s = items[i];
                  final filters = filtersFromSaved(s);
                  final summary = describeSearch(filters);
                  final title = s.name ?? summary;
                  return ListTile(
                    leading: const Icon(Icons.bookmark_outline),
                    title: Text(title),
                    subtitle: summary.isEmpty || summary == title
                        ? null
                        : Text(summary),
                    onTap: () => context.push(Routes.searchFor(filters)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (s.newMatchCount > 0)
                          Badge(
                            label: Text('${s.newMatchCount} new'),
                            largeSize: 20,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                          ),
                        IconButton(
                          tooltip: 'Delete saved search',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, ref, s),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
