import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/api/api.dart';

void main() {
  final options = RequestOptions(path: '/api/v1/me');

  test('parses the backend error body', () {
    final e = ApiException.fromResponse(409, {
      'error': {
        'code': 'PHONE_IN_USE',
        'message': 'This number belongs to another account',
      },
    });
    expect(e.statusCode, 409);
    expect(e.code, 'PHONE_IN_USE');
    expect(e.message, 'This number belongs to another account');
    expect(e.details, isNull);
  });

  test('keeps validation details', () {
    final e = ApiException.fromResponse(422, {
      'error': {
        'code': 'VALIDATION_ERROR',
        'message': 'The request is not valid',
        'details': [
          {'field': 'year', 'message': 'Must be between 1 and 6'},
        ],
      },
    });
    expect(e.code, 'VALIDATION_ERROR');
    expect(e.details, isA<List<Object?>>());
  });

  test('falls back for unexpected bodies', () {
    final e = ApiException.fromResponse(502, '<html>Bad gateway</html>');
    expect(e.code, 'HTTP_502');
    expect(e.statusCode, 502);
  });

  test('maps dio errors with a response', () {
    final e = ApiException.fromDioException(
      DioException.badResponse(
        statusCode: 401,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 401,
          data: {
            'error': {'code': 'TOKEN_EXPIRED', 'message': 'Expired'},
          },
        ),
      ),
    );
    expect(e.code, 'TOKEN_EXPIRED');
    expect(e.statusCode, 401);
  });

  test('maps connectivity failures to client-side codes', () {
    final offline = ApiException.fromDioException(
      DioException.connectionError(requestOptions: options, reason: 'offline'),
    );
    expect(offline.code, ApiException.networkError);
    expect(offline.isConnectivityProblem, isTrue);

    final slow = ApiException.fromDioException(
      DioException.receiveTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: options,
      ),
    );
    expect(slow.code, ApiException.timeout);
  });
}
