import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';
import '../widgets/paged_list.dart';
import 'user_row_tile.dart';

/// Find students by name, roll number or email, or list the flagged ones.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _search = TextEditingController();
  String _q = '';
  bool _flagged = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submit() => setState(() => _q = _search.text.trim());

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: TextField(
              controller: _search,
              enabled: !_flagged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              maxLength: 100,
              decoration: InputDecoration(
                hintText: 'Name, roll number or email',
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _flagged ? null : _submit,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: FilterChip(
                label: const Text('Flagged only'),
                selected: _flagged,
                onSelected: (v) => setState(() => _flagged = v),
              ),
            ),
          ),
          Expanded(
            child: PagedList<StaffUserRow>(
              queryKey: (_q, _flagged),
              load: (cursor) async {
                final page = await api.staff.users(
                  q: _flagged || _q.isEmpty ? null : _q,
                  flagged: _flagged ? true : null,
                  cursor: cursor,
                );
                return (items: page.items, next: page.nextCursor);
              },
              itemBuilder: (context, user, reload) =>
                  UserRowTile(user: user, onReturn: reload),
              empty: EmptyState(
                icon: Icons.people_outline,
                title: _flagged ? 'No flagged students' : 'No students found',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
