import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';

final staffAppealsProvider = FutureProvider.autoDispose
    .family<List<AppealSummary>, AppealFilter>(
      (ref, filter) =>
          ref.watch(apiProvider).staff.appealsQueue(status: filter),
    );

final staffAppealProvider = FutureProvider.autoDispose
    .family<AppealDetail, String>(
      (ref, id) => ref.watch(apiProvider).staff.appeal(id),
    );
