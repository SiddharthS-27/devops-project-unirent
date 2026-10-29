import 'package:dio/dio.dart';

/// Any failed API call. [code] is the stable machine-readable error code from
/// the backend's `{"error": {"code", "message", "details"}}` body, or one of
/// the client-side codes below when there was no usable response.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  /// Builds an exception from an HTTP error response.
  factory ApiException.fromResponse(int statusCode, Object? body) {
    if (body case {'error': final Map<Object?, Object?> error}) {
      if (error case {'code': final String code, 'message': final String msg}) {
        return ApiException(
          statusCode: statusCode,
          code: code,
          message: msg,
          details: error['details'],
        );
      }
    }
    return ApiException(
      statusCode: statusCode,
      code: 'HTTP_$statusCode',
      message: 'The server returned an unexpected error ($statusCode).',
      details: body,
    );
  }

  factory ApiException.fromDioException(DioException e) {
    if (e.error case final ApiException inner) return inner;
    final response = e.response;
    if (response != null && response.statusCode != null) {
      return ApiException.fromResponse(response.statusCode!, response.data);
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const ApiException(
        statusCode: null,
        code: timeout,
        message: 'The server took too long to respond.',
      ),
      DioExceptionType.cancel => const ApiException(
        statusCode: null,
        code: cancelled,
        message: 'The request was cancelled.',
      ),
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => const ApiException(
        statusCode: null,
        code: networkError,
        message: 'Could not reach UniRent. Check your internet connection.',
      ),
      _ => ApiException(
        statusCode: null,
        code: unknown,
        message: 'Something went wrong. Please try again.',
        details: e.error?.toString(),
      ),
    };
  }

  // Client-side codes, used when no error body was received.
  static const networkError = 'NETWORK_ERROR';
  static const timeout = 'TIMEOUT';
  static const cancelled = 'CANCELLED';
  static const unknown = 'UNKNOWN';

  /// HTTP status, or null when no response was received.
  final int? statusCode;
  final String code;

  /// Human-readable message from the server (safe to show as a fallback).
  final String message;
  final Object? details;

  /// True when the request never got a response (offline, timeout...).
  bool get isConnectivityProblem => statusCode == null && code != cancelled;

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}
