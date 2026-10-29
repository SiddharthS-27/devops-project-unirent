import 'dart:async';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'token_store.dart';

/// Exchanges a refresh token for a new token pair.
typedef RefreshTokens = Future<AuthTokens> Function(String refreshToken);

/// Owns the current tokens: caches them in memory, persists them, and
/// refreshes them at most once at a time.
///
/// The backend revokes the whole token family when a refresh token is used
/// twice, so concurrent refreshes would sign the user out. All callers that
/// need a refresh while one is running share its result instead.
class TokenManager {
  TokenManager({
    required this.store,
    required this.refreshTokens,
    this.onSessionExpired,
  });

  final TokenStore store;
  final RefreshTokens refreshTokens;

  /// Called when the session can't be refreshed and has been cleared.
  final void Function()? onSessionExpired;

  AuthTokens? _tokens;
  bool _loaded = false;
  Future<AuthTokens?>? _refreshing;

  Future<AuthTokens?> current() async {
    if (!_loaded) {
      _tokens = await store.read();
      _loaded = true;
    }
    return _tokens;
  }

  Future<void> save(AuthTokens tokens) async {
    _tokens = tokens;
    _loaded = true;
    await store.write(tokens);
  }

  Future<void> clear() async {
    _tokens = null;
    _loaded = true;
    await store.clear();
  }

  /// Refreshes the tokens, sharing one in-flight refresh between callers.
  ///
  /// Returns null (after clearing the session) if the server rejects the
  /// refresh token. Connectivity failures are rethrown and keep the session.
  Future<AuthTokens?> refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<AuthTokens?> _doRefresh() async {
    final tokens = await current();
    if (tokens == null) return null;
    try {
      final next = await refreshTokens(tokens.refreshToken);
      await save(next);
      return next;
    } on ApiException catch (e) {
      if (e.statusCode == null) rethrow;
      await clear();
      onSessionExpired?.call();
      return null;
    }
  }
}

/// Adds the bearer token and transparently refreshes an expired one.
///
/// On a 401 `TOKEN_EXPIRED` the request is retried once with fresh tokens.
/// If another request already refreshed in the meantime, the new token is
/// reused without refreshing again.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokens, required this.dio});

  final TokenManager tokens;

  /// The client the request is retried on.
  final Dio dio;

  static const _tokenKey = 'auth.token';
  static const _retriedKey = 'auth.retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final current = await tokens.current();
    if (current != null) {
      options.headers['Authorization'] = 'Bearer ${current.accessToken}';
      options.extra[_tokenKey] = current.accessToken;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final usedToken = options.extra[_tokenKey] as String?;
    if (!_isExpiredToken(err) ||
        usedToken == null ||
        options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }

    try {
      final current = await tokens.current();
      final fresh = current != null && current.accessToken != usedToken
          ? current // Someone else already refreshed.
          : await tokens.refresh();
      if (fresh == null) {
        handler.next(err);
        return;
      }
      options.extra[_retriedKey] = true;
      handler.resolve(await dio.fetch<Object?>(options));
    } on DioException catch (e) {
      handler.next(e);
    } on ApiException catch (e) {
      handler.next(err.copyWith(error: e));
    }
  }

  static bool _isExpiredToken(DioException err) {
    final response = err.response;
    if (response?.statusCode != 401) return false;
    return switch (response?.data) {
      {'error': {'code': 'TOKEN_EXPIRED'}} => true,
      _ => false,
    };
  }
}
