import 'package:firebase_functions/src/https/error.dart';
import 'package:test/test.dart';

void main() {
  group('FunctionsErrorCode', () {
    test('has correct string values', () {
      expect(FunctionsErrorCode.ok.value, 'ok');
      expect(FunctionsErrorCode.cancelled.value, 'cancelled');
      expect(FunctionsErrorCode.unknown.value, 'unknown');
      expect(FunctionsErrorCode.invalidArgument.value, 'invalid-argument');
      expect(FunctionsErrorCode.deadlineExceeded.value, 'deadline-exceeded');
      expect(FunctionsErrorCode.notFound.value, 'not-found');
      expect(FunctionsErrorCode.alreadyExists.value, 'already-exists');
      expect(FunctionsErrorCode.permissionDenied.value, 'permission-denied');
      expect(FunctionsErrorCode.resourceExhausted.value, 'resource-exhausted');
      expect(
        FunctionsErrorCode.failedPrecondition.value,
        'failed-precondition',
      );
      expect(FunctionsErrorCode.aborted.value, 'aborted');
      expect(FunctionsErrorCode.outOfRange.value, 'out-of-range');
      expect(FunctionsErrorCode.unimplemented.value, 'unimplemented');
      expect(FunctionsErrorCode.internal.value, 'internal');
      expect(FunctionsErrorCode.unavailable.value, 'unavailable');
      expect(FunctionsErrorCode.dataLoss.value, 'data-loss');
      expect(FunctionsErrorCode.unauthenticated.value, 'unauthenticated');
    });

    test('fromValue returns correct enum', () {
      expect(
        FunctionsErrorCode.fromValue('not-found'),
        FunctionsErrorCode.notFound,
      );
      expect(
        FunctionsErrorCode.fromValue('invalid-argument'),
        FunctionsErrorCode.invalidArgument,
      );
      expect(FunctionsErrorCode.fromValue('unknown-value'), isNull);
    });
  });

  group('HttpsError', () {
    test('toJson returns correct structure', () {
      final error = GenericHttpsError(
        FunctionsErrorCode.notFound,
        'Document not found',
      );

      expect(error.toJson(), {
        'status': 'NOT_FOUND',
        'message': 'Document not found',
      });
    });

    test('toJson includes details when provided', () {
      final error = GenericHttpsError(
        FunctionsErrorCode.invalidArgument,
        'Invalid input',
        {'field': 'email', 'reason': 'invalid format'},
      );

      expect(error.toJson(), {
        'status': 'INVALID_ARGUMENT',
        'message': 'Invalid input',
        'details': {'field': 'email', 'reason': 'invalid format'},
      });
    });

    test('toJson uses default message when message is null', () {
      final error = GenericHttpsError(FunctionsErrorCode.notFound);

      expect(error.toJson()['message'], 'Resource not found');
    });

    test('toErrorResponse wraps toJson in error key', () {
      final error = GenericHttpsError(
        FunctionsErrorCode.notFound,
        'Document not found',
      );

      expect(error.toErrorResponse(), {
        'error': {'status': 'NOT_FOUND', 'message': 'Document not found'},
      });
    });

    test('httpStatusCode returns correct HTTP status', () {
      expect(GenericHttpsError(FunctionsErrorCode.ok).httpStatusCode, 200);
      expect(
        GenericHttpsError(FunctionsErrorCode.cancelled).httpStatusCode,
        499,
      );
      expect(GenericHttpsError(FunctionsErrorCode.unknown).httpStatusCode, 500);
      expect(
        GenericHttpsError(FunctionsErrorCode.invalidArgument).httpStatusCode,
        400,
      );
      expect(
        GenericHttpsError(FunctionsErrorCode.deadlineExceeded).httpStatusCode,
        504,
      );
      expect(
        GenericHttpsError(FunctionsErrorCode.notFound).httpStatusCode,
        404,
      );
      expect(
        GenericHttpsError(FunctionsErrorCode.alreadyExists).httpStatusCode,
        409,
      );
      expect(
        GenericHttpsError(FunctionsErrorCode.permissionDenied).httpStatusCode,
        403,
      );
      expect(
        GenericHttpsError(FunctionsErrorCode.resourceExhausted).httpStatusCode,
        429,
      );
      expect(
        GenericHttpsError(FunctionsErrorCode.failedPrecondition).httpStatusCode,
        400,
      );
      expect(GenericHttpsError(FunctionsErrorCode.aborted).httpStatusCode, 409);
      expect(
        GenericHttpsError(FunctionsErrorCode.outOfRange).httpStatusCode,
        400,
      );
      expect(
        GenericHttpsError(FunctionsErrorCode.unimplemented).httpStatusCode,
        501,
      );
      expect(
        GenericHttpsError(FunctionsErrorCode.internal).httpStatusCode,
        500,
      );
      expect(
        GenericHttpsError(FunctionsErrorCode.unavailable).httpStatusCode,
        503,
      );
      expect(
        GenericHttpsError(FunctionsErrorCode.dataLoss).httpStatusCode,
        500,
      );
      expect(
        GenericHttpsError(FunctionsErrorCode.unauthenticated).httpStatusCode,
        401,
      );
    });

    test('httpStatusToErrorCode returns correct error code', () {
      expect(HttpsError.httpStatusToErrorCode(200), FunctionsErrorCode.ok);
      expect(
        HttpsError.httpStatusToErrorCode(400),
        FunctionsErrorCode.invalidArgument,
      );
      expect(
        HttpsError.httpStatusToErrorCode(401),
        FunctionsErrorCode.unauthenticated,
      );
      expect(
        HttpsError.httpStatusToErrorCode(403),
        FunctionsErrorCode.permissionDenied,
      );
      expect(
        HttpsError.httpStatusToErrorCode(404),
        FunctionsErrorCode.notFound,
      );
      expect(
        HttpsError.httpStatusToErrorCode(409),
        FunctionsErrorCode.alreadyExists,
      );
      expect(
        HttpsError.httpStatusToErrorCode(429),
        FunctionsErrorCode.resourceExhausted,
      );
      expect(
        HttpsError.httpStatusToErrorCode(499),
        FunctionsErrorCode.cancelled,
      );
      expect(
        HttpsError.httpStatusToErrorCode(500),
        FunctionsErrorCode.internal,
      );
      expect(
        HttpsError.httpStatusToErrorCode(501),
        FunctionsErrorCode.unimplemented,
      );
      expect(
        HttpsError.httpStatusToErrorCode(503),
        FunctionsErrorCode.unavailable,
      );
      expect(
        HttpsError.httpStatusToErrorCode(504),
        FunctionsErrorCode.deadlineExceeded,
      );
      expect(
        HttpsError.httpStatusToErrorCode(418), // I'm a teapot
        FunctionsErrorCode.unknown,
      );
    });

    test('toString returns descriptive message', () {
      final error = GenericHttpsError(
        FunctionsErrorCode.notFound,
        'Document not found',
      );

      expect(error.toString(), 'HttpsError(not-found): Document not found');
    });

    test('toString uses default message when message is null', () {
      final error = GenericHttpsError(FunctionsErrorCode.notFound);

      expect(error.toString(), 'HttpsError(not-found): Resource not found');
    });
  });

  group('Specific Error Classes', () {
    test('CancelledError has correct code', () {
      final error = CancelledError('Operation cancelled');
      expect(error.code, FunctionsErrorCode.cancelled);
      expect(error.message, 'Operation cancelled');
      expect(error.httpStatusCode, 499);
    });

    test('CancelledError uses default message', () {
      final error = CancelledError();
      expect(error.toJson()['message'], 'Request was cancelled');
    });

    test('UnknownError has correct code', () {
      final error = UnknownError('Something went wrong');
      expect(error.code, FunctionsErrorCode.unknown);
      expect(error.message, 'Something went wrong');
      expect(error.httpStatusCode, 500);
    });

    test('InvalidArgumentError has correct code', () {
      final error = InvalidArgumentError('Invalid email format');
      expect(error.code, FunctionsErrorCode.invalidArgument);
      expect(error.message, 'Invalid email format');
      expect(error.httpStatusCode, 400);
    });

    test('DeadlineExceededError has correct code', () {
      final error = DeadlineExceededError('Request timed out');
      expect(error.code, FunctionsErrorCode.deadlineExceeded);
      expect(error.message, 'Request timed out');
      expect(error.httpStatusCode, 504);
    });

    test('NotFoundError has correct code', () {
      final error = NotFoundError('User not found');
      expect(error.code, FunctionsErrorCode.notFound);
      expect(error.message, 'User not found');
      expect(error.httpStatusCode, 404);
    });

    test('AlreadyExistsError has correct code', () {
      final error = AlreadyExistsError('Email already registered');
      expect(error.code, FunctionsErrorCode.alreadyExists);
      expect(error.message, 'Email already registered');
      expect(error.httpStatusCode, 409);
    });

    test('PermissionDeniedError has correct code', () {
      final error = PermissionDeniedError('Access denied');
      expect(error.code, FunctionsErrorCode.permissionDenied);
      expect(error.message, 'Access denied');
      expect(error.httpStatusCode, 403);
    });

    test('ResourceExhaustedError has correct code', () {
      final error = ResourceExhaustedError('Rate limit exceeded');
      expect(error.code, FunctionsErrorCode.resourceExhausted);
      expect(error.message, 'Rate limit exceeded');
      expect(error.httpStatusCode, 429);
    });

    test('FailedPreconditionError has correct code', () {
      final error = FailedPreconditionError('Account not verified');
      expect(error.code, FunctionsErrorCode.failedPrecondition);
      expect(error.message, 'Account not verified');
      expect(error.httpStatusCode, 400);
    });

    test('AbortedError has correct code', () {
      final error = AbortedError('Transaction aborted');
      expect(error.code, FunctionsErrorCode.aborted);
      expect(error.message, 'Transaction aborted');
      expect(error.httpStatusCode, 409);
    });

    test('OutOfRangeError has correct code', () {
      final error = OutOfRangeError('Value must be between 1 and 100');
      expect(error.code, FunctionsErrorCode.outOfRange);
      expect(error.message, 'Value must be between 1 and 100');
      expect(error.httpStatusCode, 400);
    });

    test('UnimplementedError has correct code', () {
      final error = UnimplementedError('Feature not yet available');
      expect(error.code, FunctionsErrorCode.unimplemented);
      expect(error.message, 'Feature not yet available');
      expect(error.httpStatusCode, 501);
    });

    test('InternalError has correct code', () {
      final error = InternalError('Database connection failed');
      expect(error.code, FunctionsErrorCode.internal);
      expect(error.message, 'Database connection failed');
      expect(error.httpStatusCode, 500);
    });

    test('UnavailableError has correct code', () {
      final error = UnavailableError('Service temporarily unavailable');
      expect(error.code, FunctionsErrorCode.unavailable);
      expect(error.message, 'Service temporarily unavailable');
      expect(error.httpStatusCode, 503);
    });

    test('DataLossError has correct code', () {
      final error = DataLossError('Data corrupted');
      expect(error.code, FunctionsErrorCode.dataLoss);
      expect(error.message, 'Data corrupted');
      expect(error.httpStatusCode, 500);
    });

    test('UnauthenticatedError has correct code', () {
      final error = UnauthenticatedError('Please sign in');
      expect(error.code, FunctionsErrorCode.unauthenticated);
      expect(error.message, 'Please sign in');
      expect(error.httpStatusCode, 401);
    });

    test('Error classes support details parameter', () {
      final error = NotFoundError('User not found', {'userId': '12345'});

      expect(error.details, {'userId': '12345'});
      expect(error.toJson()['details'], {'userId': '12345'});
    });
  });

  group('HttpsError implements Exception', () {
    test('can be thrown and caught', () {
      expect(
        () => throw NotFoundError('Not found'),
        throwsA(isA<HttpsError>()),
      );
    });

    test('can be caught as specific type', () {
      expect(
        () => throw NotFoundError('Not found'),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('is sealed - all subclasses are known', () {
      // This test verifies that HttpsError is sealed by checking
      // that we can use exhaustive switch. The variable must be typed
      // as HttpsError (not a specific subclass) for exhaustive checking.
      final HttpsError error = NotFoundError('test');
      final result = switch (error) {
        GenericHttpsError() => 'generic',
        CancelledError() => 'cancelled',
        UnknownError() => 'unknown',
        InvalidArgumentError() => 'invalid',
        DeadlineExceededError() => 'deadline',
        NotFoundError() => 'not-found',
        AlreadyExistsError() => 'exists',
        PermissionDeniedError() => 'permission',
        ResourceExhaustedError() => 'exhausted',
        FailedPreconditionError() => 'precondition',
        AbortedError() => 'aborted',
        OutOfRangeError() => 'range',
        UnimplementedError() => 'unimplemented',
        InternalError() => 'internal',
        UnavailableError() => 'unavailable',
        DataLossError() => 'data-loss',
        UnauthenticatedError() => 'unauthenticated',
      };
      expect(result, 'not-found');
    });
  });
}
