import 'package:dio/dio.dart';

import 'api_exception.dart';

/// The single seam between the generated endpoints and the HTTP stack.
abstract interface class ApiTransport {
  /// Sends a request and returns the decoded JSON body (null when empty).
  ///
  /// Throws [ApiException] on any failure.
  Future<Object?> send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Map<String, String>? headers,
    Object? body,
  });
}

class DioTransport implements ApiTransport {
  DioTransport(this._dio);

  final Dio _dio;

  @override
  Future<Object?> send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: headers),
      );
      final data = response.data;
      return data == '' ? null : data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
