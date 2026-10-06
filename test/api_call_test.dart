import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rahi/core/utils/api_call.dart';

void main() {
  group('ApiCall.withResilience', () {
    test('retries one transient socket failure', () async {
      var attempts = 0;

      final result = await ApiCall.withResilience<String>(
        call: () async {
          attempts++;
          if (attempts == 1) {
            throw SocketException('temporary');
          }
          return 'ok';
        },
      );

      expect(result, 'ok');
      expect(attempts, 2);
    });

    test('does not retry non-network Dio errors', () async {
      var attempts = 0;
      final options = RequestOptions(path: '/test');

      await expectLater(
        ApiCall.withResilience<void>(
          call: () async {
            attempts++;
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<void>(
                requestOptions: options,
                statusCode: 403,
              ),
            );
          },
        ),
        throwsA(isA<DioException>()),
      );

      expect(attempts, 1);
    });
  });
}
