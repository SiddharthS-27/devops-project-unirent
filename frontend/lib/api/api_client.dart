import 'package:dio/dio.dart';

import 'api_config.dart';
import 'auth_interceptor.dart';
import 'generated/endpoints.dart';
import 'generated/models.dart';
import 'mock/mock_server.dart';
import 'token_store.dart';
import 'transport.dart';

/// The configured HTTP stack: dio + auth handling (+ the mock server in mock
/// mode), exposed as the typed [api].
class ApiClient {
  ApiClient._(this.dio, this.api, this.tokens);

  factory ApiClient({
    required ApiConfig config,
    required TokenStore tokenStore,
    void Function()? onSessionExpired,
    MockServer? mockServer,
    HttpClientAdapter? httpClientAdapter,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    if (httpClientAdapter != null) dio.httpClientAdapter = httpClientAdapter;

    final api = UniRentApi(DioTransport(dio));
    final tokens = TokenManager(
      store: tokenStore,
      refreshTokens: (refreshToken) async {
        final pair = await api.auth.refresh(
          RefreshRequest(refreshToken: refreshToken),
        );
        return AuthTokens(
          accessToken: pair.accessToken,
          refreshToken: pair.refreshToken,
        );
      },
      onSessionExpired: onSessionExpired,
    );

    dio.interceptors.add(AuthInterceptor(tokens: tokens, dio: dio));
    final mock =
        mockServer ?? (config.mode == ApiMode.mock ? MockServer() : null);
    if (mock != null) dio.interceptors.add(MockInterceptor(mock));

    return ApiClient._(dio, api, tokens);
  }

  final Dio dio;
  final UniRentApi api;
  final TokenManager tokens;

  /// Stores the tokens from a sign-in response.
  Future<void> saveSession(TokenPair pair) => tokens.save(
    AuthTokens(accessToken: pair.accessToken, refreshToken: pair.refreshToken),
  );

  /// Forgets the stored tokens.
  Future<void> clearSession() => tokens.clear();
}
