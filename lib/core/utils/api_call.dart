import 'dart:io';

import 'package:dio/dio.dart';

class ApiCall {
  ApiCall._();

  static const Duration defaultTimeout = Duration(seconds: 5);
  static const int defaultMaxAttempts = 2;

  static Future<T> withResilience<T>({
    required Future<T> Function() call,
    int maxAttempts = defaultMaxAttempts,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await call();
      } on DioException catch (error) {
        if (!_isRetryableDio(error)) rethrow;
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      }

      if (attempt < maxAttempts) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }

    if (lastError != null) {
      Error.throwWithStackTrace(lastError, StackTrace.current);
    }

    throw StateError('Network call failed without an error.');
  }

  static bool _isRetryableDio(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      _ => false,
    };
  }
}
