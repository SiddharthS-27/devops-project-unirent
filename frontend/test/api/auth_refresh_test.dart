import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_db.dart';
import 'package:unirent/api/mock/mock_handlers.dart';
import 'package:unirent/api/mock/mock_server.dart';

/// A mock-mode client signed in as the seeded student.
Future<(ApiClient, MockServer, MemoryTokenStore)> signedInClient({
  void Function()? onSessionExpired,
}) async {
  final server = MockServer();
  final store = MemoryTokenStore();
  final client = ApiClient(
    config: const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
    tokenStore: store,
    mockServer: server,
    onSessionExpired: onSessionExpired,
  );
  final idToken = await client.api.auth.mockMicrosoftToken(
    const MockTokenRequest(email: 'asha@college.edu'),
  );
  await client.saveSession(
    await client.api.auth.signInWithMicrosoft(
      MicrosoftSignIn(idToken: idToken.idToken),
    ),
  );
  return (client, server, store);
}

/// Delays the refresh endpoint so concurrent requests overlap with it.
void slowDownRefresh(MockServer server, Completer<void> gate) {
  final refresh = mockHandlers(server.db)['POST /api/v1/auth/refresh']!;
  server.on('POST /api/v1/auth/refresh', (request) async {
    await gate.future;
    return refresh(request);
  });
}

void main() {
  test('adds the bearer token', () async {
    final (client, _, _) = await signedInClient();
    final me = await client.api.profiles.getMe();
    expect(me.account.email, 'asha@college.edu');
  });

  test('concurrent 401s share a single refresh', () async {
    final (client, server, store) = await signedInClient();
    final before = (await store.read())!;
    server.db.expireAccessTokens();
    final gate = Completer<void>();
    slowDownRefresh(server, gate);

    final requests = Future.wait([
      client.api.profiles.getMe(),
      client.api.profiles.getMe(),
      client.api.health.serverTime(),
    ]);
    // Let all three hit the 401 before the refresh completes.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete();
    final results = await requests;

    expect(results, hasLength(3));
    expect(server.db.refreshCount, 1);
    expect(server.db.usedRefreshTokens, hasLength(1));
    final after = (await store.read())!;
    expect(after.accessToken, isNot(before.accessToken));
    expect(after.refreshToken, isNot(before.refreshToken));
  });

  test('a later 401 reuses tokens refreshed by another request', () async {
    final (client, server, _) = await signedInClient();
    server.db.expireAccessTokens();
    await client.api.profiles.getMe();
    await client.api.profiles.getMe();
    expect(server.db.refreshCount, 1);
  });

  test('a rejected refresh clears the session', () async {
    var expired = 0;
    final (client, server, store) = await signedInClient(
      onSessionExpired: () => expired++,
    );
    server.db
      ..expireAccessTokens()
      ..refreshTokens.clear(); // The server no longer knows the token.

    await expectLater(
      client.api.profiles.getMe(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'TOKEN_EXPIRED'),
      ),
    );
    expect(expired, 1);
    expect(await store.read(), isNull);
  });

  test('other 401s do not trigger a refresh', () async {
    final (client, server, _) = await signedInClient();
    server.db.accessTokens.clear(); // Unknown token → INVALID_TOKEN.
    await expectLater(
      client.api.profiles.getMe(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'INVALID_TOKEN'),
      ),
    );
    expect(server.db.refreshCount, 0);
  });

  test('IdempotentAction reuses its key until reset', () {
    var n = 0;
    final action = IdempotentAction(() => 'key-${++n}');
    expect(action.key, 'key-1');
    expect(action.key, 'key-1');
    action.reset();
    expect(action.key, 'key-2');
    expect(newIdempotencyKey(), isNot(newIdempotencyKey()));
    expect(mockOtpCode, '123456');
  });
}
