import 'package:flutter/material.dart';

import '../../../app/error_messages.dart';
import '../../../ui/ui.dart';

/// One page of results and the cursor for the next.
typedef PageResult<T> = ({List<T> items, String? next});

/// A list loaded a page at a time with a "Load more" button. Changing
/// [queryKey] starts again from the first page.
class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.queryKey,
    required this.load,
    required this.itemBuilder,
    required this.empty,
  });

  final Object queryKey;
  final Future<PageResult<T>> Function(String? cursor) load;
  final Widget Function(BuildContext context, T item, VoidCallback reload)
  itemBuilder;
  final Widget empty;

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  final _items = <T>[];
  String? _next;
  Object? _error;
  bool _loading = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(PagedList<T> old) {
    super.didUpdateWidget(old);
    if (old.queryKey != widget.queryKey) _reload();
  }

  Future<void> _reload() {
    _items.clear();
    _next = null;
    return _fetch(null);
  }

  Future<void> _fetch(String? cursor) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.load(cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        if (cursor == null) _items.clear();
        _items.addAll(page.items);
        _next = page.next;
      });
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      if (_loading) return const LoadingState();
      if (_error != null) {
        return ErrorState(message: friendlyMessage(_error!), onRetry: _reload);
      }
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        children: [
          if (_items.isEmpty) widget.empty,
          for (final item in _items) ...[
            widget.itemBuilder(context, item, _reload),
            const Divider(height: 1),
          ],
          if (_error != null && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: InlineError(friendlyMessage(_error!)),
            ),
          if (_next != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppButton.secondary(
                label: 'Load more',
                isLoading: _loading,
                onPressed: () => _fetch(_next),
              ),
            ),
        ],
      ),
    );
  }
}
