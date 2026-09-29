import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/stack/common/errors/api/api_error.dart';
import 'package:handoff/stack/common/errors/api/api_error_type.dart';
import 'package:handoff/stack/common/exceptions/network_unavailable_exception.dart';
import 'package:handoff/stack/common/models/api/api_result.dart';
import 'package:handoff/stack/common/models/failure.dart';
import 'package:handoff/stack/common/models/result.dart';

void main() {
  group('Result', () {
    test('carries the value when successful', () {
      final result = Result<String, Failure>.success(value: 'ok');

      expect(result, isA<Success<String, Failure>>());
      expect(result.isSuccessful, isTrue);
      expect(result.value, 'ok');
      expect(result.error, isNull);
    });

    test('carries the error when failed', () {
      final result = Result<String, Failure>.failure(
        const Failure(message: 'boom'),
      );

      expect(result, isA<Failed<String, Failure>>());
      expect(result.isSuccessful, isFalse);
      expect(result.value, isNull);
      expect(result.error?.message, 'boom');
    });

    test('is successful without a value even when typed', () {
      // The previous shape reported this as a failure, because success was
      // derived from the value being non-null.
      final result = Result<String, Failure>.success();

      expect(result.isSuccessful, isTrue);
      expect(result.value, isNull);
    });

    test('is successful for an operation with nothing to return', () {
      expect(Result.success().isSuccessful, isTrue);
    });

    test('can be handled exhaustively without null checks', () {
      String describe(Result<int, Failure> result) {
        return switch (result) {
          Success(:final value) => 'value: $value',
          Failed(:final error) => 'error: ${error.message}',
        };
      }

      expect(describe(const Success(value: 7)), 'value: 7');
      expect(describe(const Failed(Failure(message: 'nope'))), 'error: nope');
    });

    test('compares by branch and payload', () {
      expect(
        const Success<int, Failure>(value: 1),
        const Success<int, Failure>(value: 1),
      );
      expect(
        const Success<int, Failure>(value: 1),
        isNot(const Success<int, Failure>(value: 2)),
      );
      expect(
        const Success<int, Failure>(),
        isNot(const Failed(Failure(message: ''))),
      );
    });
  });

  group('ApiResult', () {
    test('is a Result that matches the same branches', () {
      final success = ApiResult<String>.success(value: 'body');
      final failure = ApiResult<String>.failure(
        ApiError.fromException(NetworkUnavailableException()),
      );

      expect(success, isA<Result<String, ApiError>>());
      expect(success, isA<Success<String, ApiError>>());
      expect(switch (success) {
        Success(:final value) => value,
        Failed() => null,
      }, 'body');
      expect(failure.error?.apiErrorType, ApiErrorType.networkUnavailable);
    });
  });
}
