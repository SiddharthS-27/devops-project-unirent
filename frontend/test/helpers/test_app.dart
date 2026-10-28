import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:unirent/api/api.dart';
import 'package:unirent/api/mock/mock_db.dart';
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/app.dart';
import 'package:unirent/app/env.dart';
import 'package:unirent/app/push_service.dart';
import 'package:unirent/app/router.dart';
import 'package:unirent/app/session.dart';
import 'package:unirent/ui/ui.dart';

class FakePushService implements PushService {
  FakePushService({this.isAvailable = false});

  @override
  final bool isAvailable;

  int enableCalls = 0;
  int syncCalls = 0;
  int unregisterCalls = 0;

  @override
  Future<bool> enable() async {
    enableCalls++;
    return true;
  }

  @override
  Future<void> syncIfPermitted() async => syncCalls++;

  @override
  Future<void> unregister() async => unregisterCalls++;

  final receivedPushes = StreamController<Uri>.broadcast();
  final openedPushes = StreamController<Uri>.broadcast();

  @override
  Stream<Uri> get received => receivedPushes.stream;

  @override
  Stream<Uri> get opened => openedPushes.stream;
}

/// The running app plus handles on its fakes.
class TestApp {
  TestApp(this.tester, this.server, this.tokens, this.push);

  final WidgetTester tester;
  final MockServer server;
  final MemoryTokenStore tokens;
  final FakePushService push;

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(UniRentApp)));

  GoRouter get router => container.read(routerProvider);

  /// Location of the top-most route, including pushed routes.
  String get location => router.state.uri.toString();

  Session get session => container.read(sessionProvider);

  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(String text) => tap(find.text(text).last);

  Future<void> enterField(String label, String text) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> enterOtp(String code) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(OtpEntry),
        matching: find.byType(TextField),
      ),
      code,
    );
    await tester.pumpAndSettle();
  }
}

/// Stored tokens for a seeded or test account, as if signed in earlier.
AuthTokens tokensFor(MockServer server, String email) {
  final pair = server.db.issueTokens(server.db.accountByEmail(email)!);
  return AuthTokens(
    accessToken: pair.accessToken,
    refreshToken: pair.refreshToken,
  );
}

/// Adds a student who has signed in but not onboarded.
MockAccount addStudent(MockServer server, String email) {
  return server.db.addAccount(
    MockAccount(
      id: server.db.nextId(),
      email: email,
      role: 'student',
      createdAt: DateTime.utc(2026, 10, 1),
    ),
  );
}

/// Pumps the whole app against an in-process mock backend.
Future<TestApp> pumpTestApp(
  WidgetTester tester, {
  MockServer? server,
  AuthTokens? storedTokens,
  FakePushService? push,
  AppEnv env = const AppEnv(),
  List<Override> overrides = const [],
}) async {
  // A tall phone so long forms fit without scrolling.
  tester.view
    ..physicalSize = const Size(1200, 6000)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final mock = server ?? MockServer();
  final tokens = MemoryTokenStore(storedTokens);
  final fakePush = push ?? FakePushService();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        apiConfigProvider.overrideWithValue(
          const ApiConfig(baseUrl: 'http://mock', mode: ApiMode.mock),
        ),
        mockServerProvider.overrideWithValue(mock),
        tokenStoreProvider.overrideWithValue(tokens),
        appEnvProvider.overrideWithValue(env),
        pushServiceProvider.overrideWithValue(fakePush),
        ...overrides,
      ],
      child: const UniRentApp(),
    ),
  );
  await tester.pumpAndSettle();
  return TestApp(tester, mock, tokens, fakePush);
}

/// The app restored with a stored session for [email].
Future<TestApp> pumpSignedIn(
  WidgetTester tester,
  String email, {
  MockServer? server,
  FakePushService? push,
  List<Override> overrides = const [],
}) {
  final mock = server ?? MockServer();
  return pumpTestApp(
    tester,
    server: mock,
    push: push,
    overrides: overrides,
    storedTokens: tokensFor(mock, email),
  );
}
