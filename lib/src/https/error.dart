/// Firebase Functions error codes.
///
/// These match the gRPC error codes used by the Node.js SDK.
/// See: https://grpc.github.io/grpc/core/md_doc_statuscodes.html
enum FunctionsErrorCode {
  ok('ok'),
  cancelled('cancelled'),
  unknown('unknown'),
  invalidArgument('invalid-argument'),
  deadlineExceeded('deadline-exceeded'),
  notFound('not-found'),
  alreadyExists('already-exists'),
  permissionDenied('permission-denied'),
  resourceExhausted('resource-exhausted'),
  failedPrecondition('failed-precondition'),
  aborted('aborted'),
  outOfRange('out-of-range'),
  unimplemented('unimplemented'),
  internal('internal'),
  unavailable('unavailable'),
  dataLoss('data-loss'),
  unauthenticated('unauthenticated');

  const FunctionsErrorCode(this.value);

  /// The string value used in JSON serialization.
  final String value;

  /// Maps an error code value string to the corresponding enum.
  static FunctionsErrorCode? fromValue(String value) {
    for (final code in FunctionsErrorCode.values) {
      if (code.value == value) {
        return code;
      }
    }
    return null;
  }
}

/// Base error class for HTTPS Callable functions.
///
/// When thrown from a callable function, this error is automatically
/// serialized and sent to the client with the appropriate status code.
///
/// You can throw this directly:
/// ```dart
/// throw HttpsError(FunctionsErrorCode.notFound, 'Document not found');
/// ```
///
/// Or use the specific error subclasses for convenience:
/// ```dart
/// throw NotFoundError('Document not found');
/// throw UnauthenticatedError('User must be authenticated');
/// ```
sealed class HttpsError implements Exception {
  HttpsError(this.code, [this.message, this.details]);

  /// The error code.
  final FunctionsErrorCode code;

  /// Human-readable error message.
  final String? message;

  /// Additional error details (must be JSON-serializable).
  final dynamic details;

  /// Converts this error to JSON for wire transmission.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': code.value.toUpperCase().replaceAll('-', '_'),
    'message': message ?? _defaultMessage(code),
    if (details != null) 'details': details,
  };

  /// Converts this error to a full error response.
  Map<String, dynamic> toErrorResponse() => <String, dynamic>{
    'error': toJson(),
  };

  /// Gets the HTTP status code for this error.
  int get httpStatusCode => errorCodeToHttpStatus(code);

  @override
  String toString() =>
      'HttpsError(${code.value}): ${message ?? _defaultMessage(code)}';

  /// Maps error codes to HTTP status codes.
  static int errorCodeToHttpStatus(FunctionsErrorCode code) => switch (code) {
    FunctionsErrorCode.ok => 200,
    FunctionsErrorCode.cancelled => 499,
    FunctionsErrorCode.unknown => 500,
    FunctionsErrorCode.invalidArgument => 400,
    FunctionsErrorCode.deadlineExceeded => 504,
    FunctionsErrorCode.notFound => 404,
    FunctionsErrorCode.alreadyExists => 409,
    FunctionsErrorCode.permissionDenied => 403,
    FunctionsErrorCode.resourceExhausted => 429,
    FunctionsErrorCode.failedPrecondition => 400,
    FunctionsErrorCode.aborted => 409,
    FunctionsErrorCode.outOfRange => 400,
    FunctionsErrorCode.unimplemented => 501,
    FunctionsErrorCode.internal => 500,
    FunctionsErrorCode.unavailable => 503,
    FunctionsErrorCode.dataLoss => 500,
    FunctionsErrorCode.unauthenticated => 401,
  };

  /// Maps HTTP status codes to error codes (for parsing).
  static FunctionsErrorCode httpStatusToErrorCode(int statusCode) =>
      switch (statusCode) {
        200 => FunctionsErrorCode.ok,
        400 => FunctionsErrorCode.invalidArgument,
        401 => FunctionsErrorCode.unauthenticated,
        403 => FunctionsErrorCode.permissionDenied,
        404 => FunctionsErrorCode.notFound,
        409 => FunctionsErrorCode.alreadyExists,
        429 => FunctionsErrorCode.resourceExhausted,
        499 => FunctionsErrorCode.cancelled,
        500 => FunctionsErrorCode.internal,
        501 => FunctionsErrorCode.unimplemented,
        503 => FunctionsErrorCode.unavailable,
        504 => FunctionsErrorCode.deadlineExceeded,
        _ => FunctionsErrorCode.unknown,
      };

  /// Default messages for each error code.
  static String _defaultMessage(FunctionsErrorCode code) => switch (code) {
    FunctionsErrorCode.ok => 'OK',
    FunctionsErrorCode.cancelled => 'Request was cancelled',
    FunctionsErrorCode.unknown => 'Unknown error occurred',
    FunctionsErrorCode.invalidArgument => 'Invalid argument',
    FunctionsErrorCode.deadlineExceeded => 'Deadline exceeded',
    FunctionsErrorCode.notFound => 'Resource not found',
    FunctionsErrorCode.alreadyExists => 'Resource already exists',
    FunctionsErrorCode.permissionDenied => 'Permission denied',
    FunctionsErrorCode.resourceExhausted => 'Resource exhausted',
    FunctionsErrorCode.failedPrecondition => 'Failed precondition',
    FunctionsErrorCode.aborted => 'Operation aborted',
    FunctionsErrorCode.outOfRange => 'Value out of range',
    FunctionsErrorCode.unimplemented => 'Operation not implemented',
    FunctionsErrorCode.internal => 'Internal error',
    FunctionsErrorCode.unavailable => 'Service unavailable',
    FunctionsErrorCode.dataLoss => 'Data loss',
    FunctionsErrorCode.unauthenticated => 'Unauthenticated',
  };
}

/// Creates an [HttpsError] with the given code and optional message.
///
/// This is a factory for creating HttpsError instances.
final class GenericHttpsError extends HttpsError {
  GenericHttpsError(super.code, [super.message, super.details]);
}

/// Error indicating the operation was cancelled.
final class CancelledError extends HttpsError {
  CancelledError([String? message, dynamic details])
    : super(FunctionsErrorCode.cancelled, message, details);
}

/// Error indicating an unknown error occurred.
final class UnknownError extends HttpsError {
  UnknownError([String? message, dynamic details])
    : super(FunctionsErrorCode.unknown, message, details);
}

/// Error indicating an invalid argument was provided.
final class InvalidArgumentError extends HttpsError {
  InvalidArgumentError([String? message, dynamic details])
    : super(FunctionsErrorCode.invalidArgument, message, details);
}

/// Error indicating the deadline was exceeded.
final class DeadlineExceededError extends HttpsError {
  DeadlineExceededError([String? message, dynamic details])
    : super(FunctionsErrorCode.deadlineExceeded, message, details);
}

/// Error indicating the requested resource was not found.
final class NotFoundError extends HttpsError {
  NotFoundError([String? message, dynamic details])
    : super(FunctionsErrorCode.notFound, message, details);
}

/// Error indicating the resource already exists.
final class AlreadyExistsError extends HttpsError {
  AlreadyExistsError([String? message, dynamic details])
    : super(FunctionsErrorCode.alreadyExists, message, details);
}

/// Error indicating permission was denied.
final class PermissionDeniedError extends HttpsError {
  PermissionDeniedError([String? message, dynamic details])
    : super(FunctionsErrorCode.permissionDenied, message, details);
}

/// Error indicating a resource has been exhausted.
final class ResourceExhaustedError extends HttpsError {
  ResourceExhaustedError([String? message, dynamic details])
    : super(FunctionsErrorCode.resourceExhausted, message, details);
}

/// Error indicating a precondition check failed.
final class FailedPreconditionError extends HttpsError {
  FailedPreconditionError([String? message, dynamic details])
    : super(FunctionsErrorCode.failedPrecondition, message, details);
}

/// Error indicating the operation was aborted.
final class AbortedError extends HttpsError {
  AbortedError([String? message, dynamic details])
    : super(FunctionsErrorCode.aborted, message, details);
}

/// Error indicating a value was out of range.
final class OutOfRangeError extends HttpsError {
  OutOfRangeError([String? message, dynamic details])
    : super(FunctionsErrorCode.outOfRange, message, details);
}

/// Error indicating the operation is not implemented.
///
/// Note: This shadows Dart's core UnimplementedError. If you need the core
/// error, use `throw UnsupportedError('...')` instead.
final class UnimplementedError extends HttpsError {
  UnimplementedError([String? message, dynamic details])
    : super(FunctionsErrorCode.unimplemented, message, details);
}

/// Error indicating an internal error occurred.
final class InternalError extends HttpsError {
  InternalError([String? message, dynamic details])
    : super(FunctionsErrorCode.internal, message, details);
}

/// Error indicating the service is unavailable.
final class UnavailableError extends HttpsError {
  UnavailableError([String? message, dynamic details])
    : super(FunctionsErrorCode.unavailable, message, details);
}

/// Error indicating data was lost.
final class DataLossError extends HttpsError {
  DataLossError([String? message, dynamic details])
    : super(FunctionsErrorCode.dataLoss, message, details);
}

/// Error indicating the user is not authenticated.
final class UnauthenticatedError extends HttpsError {
  UnauthenticatedError([String? message, dynamic details])
    : super(FunctionsErrorCode.unauthenticated, message, details);
}
