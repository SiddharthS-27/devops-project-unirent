import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/session.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'generated/endpoints.dart';
import 'idempotency.dart';
import 'mock/mock_server.dart';
import 'token_store.dart';

final apiConfigProvider = Provider<ApiConfig>(
  (ref) => ApiConfig.fromEnvironment(),
);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// The in-process backend; only present in mock mode.
final mockServerProvider = Provider<MockServer?>((ref) {
  final mode = ref.watch(apiConfigProvider).mode;
  return mode == ApiMode.mock ? MockServer() : null;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    config: ref.watch(apiConfigProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    mockServer: ref.watch(mockServerProvider),
    onSessionExpired: () => ref.read(sessionProvider.notifier).sessionExpired(),
  );
});

/// Typed access to every endpoint, e.g. `ref.read(apiProvider).auth`.
final apiProvider = Provider<UniRentApi>(
  (ref) => ref.watch(apiClientProvider).api,
);

/// Source of idempotency keys; override in tests for deterministic keys.
final idempotencyKeyFactoryProvider = Provider<String Function()>(
  (ref) => newIdempotencyKey,
);
