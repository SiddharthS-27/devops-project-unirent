import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';

final metricsProvider = FutureProvider.autoDispose<MetricsOut>(
  (ref) => ref.watch(apiProvider).admin.metrics(),
);

final reconciliationRunsProvider =
    FutureProvider.autoDispose<List<ReconciliationRunOut>>(
      (ref) => ref.watch(apiProvider).payments.reconciliationRuns(),
    );

final reconciliationReportProvider = FutureProvider.autoDispose
    .family<ReconciliationReport, String>(
      (ref, id) => ref.watch(apiProvider).payments.reconciliationReport(id),
    );
