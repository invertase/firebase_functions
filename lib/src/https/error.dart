/// Firebase Functions error codes.
///
/// These match the gRPC error codes used by the Node.js SDK.
/// See: https://grpc.github.io/grpc/core/md_doc_statuscodes.html
enum FunctionsErrorCode {
  // NOTE: These are ordered so that the first error code with a given HTTP
  // status code is the one that is used when mapping from HTTP status codes.
  ok('ok', 'OK', 200),
  invalidArgument('invalid-argument', 'Invalid argument', 400),
  failedPrecondition('failed-precondition', 'Failed precondition', 400),
  outOfRange('out-of-range', 'Value out of range', 400),
  unauthenticated('unauthenticated', 'Unauthenticated', 401),
  permissionDenied('permission-denied', 'Permission denied', 403),
  notFound('not-found', 'Resource not found', 404),
  alreadyExists('already-exists', 'Resource already exists', 409),
  aborted('aborted', 'Operation aborted', 409),
  resourceExhausted('resource-exhausted', 'Resource exhausted', 429),
  cancelled('cancelled', 'Request was cancelled', 499),
  internal('internal', 'Internal error', 500),
  unknown('unknown', 'Unknown error occurred', 500),
  dataLoss('data-loss', 'Data loss', 500),
  unimplemented('unimplemented', 'Operation not implemented', 501),
  unavailable('unavailable', 'Service unavailable', 503),
  deadlineExceeded('deadline-exceeded', 'Deadline exceeded', 504);

  const FunctionsErrorCode(this.value, this.message, this.httpStatusCode);

  /// The string value used in JSON serialization.
  final String value;

  /// The default human-readable message for this error code.
  final String message;

  /// The corresponding HTTP status code.
  final int httpStatusCode;

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
    'message': message ?? code.message,
    if (details != null) 'details': details,
  };

  /// Converts this error to a full error response.
  Map<String, dynamic> toErrorResponse() => <String, dynamic>{
    'error': toJson(),
  };

  /// Gets the HTTP status code for this error.
  int get httpStatusCode => code.httpStatusCode;

  @override
  String toString() => 'HttpsError(${code.value}): ${message ?? code.message}';

  /// Maps HTTP status codes to error codes (for parsing).
  static FunctionsErrorCode httpStatusToErrorCode(int statusCode) =>
      FunctionsErrorCode.values.firstWhere(
        (v) => v.httpStatusCode == statusCode,
        orElse: () => FunctionsErrorCode.unknown,
      );
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
