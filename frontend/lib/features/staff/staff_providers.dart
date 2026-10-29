import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';

final supportInboxProvider = FutureProvider.autoDispose
    .family<List<SupportThreadSummary>, ThreadStatus>(
      (ref, status) =>
          ref.watch(apiProvider).staff.supportInbox(status: status),
    );

final staffThreadProvider = FutureProvider.autoDispose
    .family<SupportThreadOut, String>(
      (ref, id) => ref.watch(apiProvider).staff.supportThread(id),
    );

final escalationsProvider = FutureProvider.autoDispose<List<EscalationOut>>(
  (ref) => ref.watch(apiProvider).staff.escalations(),
);

/// Students with risk flags, most flags first (first page).
final flaggedUsersProvider = FutureProvider.autoDispose<StaffUserRowPage>(
  (ref) => ref.watch(apiProvider).staff.users(flagged: true, limit: 50),
);

final staffUserProvider = FutureProvider.autoDispose
    .family<StaffUserDetail, String>(
      (ref, id) => ref.watch(apiProvider).staff.user(id),
    );
