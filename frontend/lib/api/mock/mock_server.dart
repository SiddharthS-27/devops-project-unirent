import 'dart:async';

import 'package:dio/dio.dart';

import 'mock_db.dart';
import 'mock_handlers.dart';

/// A request as seen by a mock handler.
class MockRequest {
  MockRequest({
    required this.method,
    required this.path,
    this.pathParams = const {},
    this.query = const {},
    this.headers = const {},
    this.body,
  });

  final String method;
  final String path;
  final Map<String, String> pathParams;
  final Map<String, Object?> query;
  final Map<String, Object?> headers;
  final Object? body;

  /// The JSON object body; a 422 if there isn't one.
  Map<String, Object?> get json => switch (body) {
    final Map<String, Object?> map => map,
    _ => throw const MockApiError(
      422,
      'VALIDATION_ERROR',
      'The request is not valid',
    ),
  };

  /// The bearer token from the Authorization header, if any.
  String? get bearerToken {
    final header = headers.entries
        .where((e) => e.key.toLowerCase() == 'authorization')
        .map((e) => e.value)
        .firstOrNull;
    if (header is! String || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }
}

class MockResponse {
  const MockResponse(this.status, [this.body]);

  const MockResponse.json(Object? body) : this(200, body);

  const MockResponse.noContent() : this(204);

  /// Simulates the network being unreachable (no HTTP response at all).
  static const offline = MockResponse(0);

  final int status;
  final Object? body;
}

/// Thrown by handlers to answer with the backend's error shape.
class MockApiError implements Exception {
  const MockApiError(this.status, this.code, this.message, [this.details]);

  final int status;
  final String code;
  final String message;
  final Object? details;

  MockResponse toResponse() => MockResponse(status, {
    'error': {
      'code': code,
      'message': message,
      if (details != null) 'details': details,
    },
  });
}

typedef MockHandler = FutureOr<MockResponse> Function(MockRequest request);

/// In-process stand-in for the backend, answering from [db].
///
/// Routes are `'METHOD /path/{param}'` keys in one handler map (see
/// [mockHandlers]); anything unrouted answers 501 `NOT_IMPLEMENTED`, like
/// the real backend does for endpoints that aren't built yet.
class MockServer {
  MockServer({MockDb? db, Map<String, MockHandler>? handlers})
    : db = db ?? MockDb.seeded() {
    (handlers ?? mockHandlers(this.db)).forEach(on);
  }

  final MockDb db;
  final _routes = <_Route>[];

  /// Adds or replaces the handler for [route], e.g. `'GET /api/v1/me'`.
  void on(String route, MockHandler handler) {
    final [method, path] = route.split(' ');
    _routes
      ..removeWhere((r) => r.method == method && r.template == path)
      ..add(_Route(method, path, handler));
  }

  Future<MockResponse> handle(MockRequest request) async {
    // Literal routes win over parameterised ones (`/listings/mine` before
    // `/listings/{listing_id}`), like the real router.
    final routes = [..._routes]
      ..sort((a, b) => a.paramCount.compareTo(b.paramCount));
    for (final route in routes) {
      if (route.method != request.method) continue;
      final params = route.match(request.path);
      if (params == null) continue;
      try {
        return await route.handler(
          MockRequest(
            method: request.method,
            path: request.path,
            pathParams: params,
            query: request.query,
            headers: request.headers,
            body: request.body,
          ),
        );
      } on MockApiError catch (e) {
        return e.toResponse();
      }
    }
    return const MockApiError(
      501,
      'NOT_IMPLEMENTED',
      'This endpoint is not available yet',
    ).toResponse();
  }
}

class _Route {
  _Route(this.method, this.template, this.handler)
    : _names = [
        for (final m in RegExp(r'\{(\w+)\}').allMatches(template)) m[1]!,
      ],
      _pattern = RegExp(
        '^${template.replaceAll(RegExp(r'\{\w+\}'), '([^/]+)')}\$',
      );

  final String method;
  final String template;
  final MockHandler handler;
  final List<String> _names;
  final RegExp _pattern;

  int get paramCount => _names.length;

  Map<String, String>? match(String path) {
    final m = _pattern.firstMatch(path);
    if (m == null) return null;
    return {
      for (var i = 0; i < _names.length; i++)
        _names[i]: Uri.decodeComponent(m[i + 1]!),
    };
  }
}

/// Answers requests from a [MockServer] instead of the network (the
/// equivalent of MSW). Add it last so other interceptors still run.
class MockInterceptor extends Interceptor {
  MockInterceptor(this.server, {this.latency = Duration.zero});

  final MockServer server;

  /// Artificial delay, to make loading states visible in mock builds.
  final Duration latency;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final result = await server.handle(
      MockRequest(
        method: options.method.toUpperCase(),
        path: options.uri.path,
        query: options.queryParameters,
        headers: options.headers,
        body: options.data,
      ),
    );
    if (result.status == 0) {
      handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: 'Mock server is offline',
        ),
        true,
      );
      return;
    }
    final response = Response<Object?>(
      requestOptions: options,
      statusCode: result.status,
      data: result.body,
    );
    if (result.status >= 200 && result.status < 300) {
      handler.resolve(response, true);
    } else {
      handler.reject(
        DioException.badResponse(
          statusCode: result.status,
          requestOptions: options,
          response: response,
        ),
        true,
      );
    }
  }
}
