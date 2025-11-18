/// Firebase Functions error codes.
///
/// These match the gRPC error codes used by the Node.js SDK.
/// See: https://grpc.github.io/grpc/core/md_doc_statuscodes.html
enum FunctionsErrorCode {
  ok,
  cancelled,
  unknown,
  invalidArgument,
  deadlineExceeded,
  notFound,
  alreadyExists,
  permissionDenied,
  resourceExhausted,
  failedPrecondition,
  aborted,
  outOfRange,
  unimplemented,
  internal,
  unavailable,
  dataLoss,
  unauthenticated,
}

/// Error class for HTTPS Callable functions.
///
/// When thrown from a callable function, this error is automatically
/// serialized and sent to the client with the appropriate status code.
///
/// Example:
/// ```dart
/// firebase.https.onCall(
///   name: 'checkAuth',
///   (request, response) async {
///     if (request.auth == null) {
///       throw HttpsError(
///         FunctionsErrorCode.unauthenticated,
///         'User must be authenticated',
///       );
///     }
///     return CallableResult('Success');
///   },
/// );
/// ```
class HttpsError implements Exception {

  HttpsError(this.code, this.message, [this.details]);
  /// The error code.
  final FunctionsErrorCode code;

  /// Human-readable error message.
  final String message;

  /// Additional error details (must be JSON-serializable).
  final dynamic details;

  /// Converts this error to JSON for wire transmission.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'status': _errorCodeToStatus(code),
        'message': message,
        if (details != null) 'details': details,
      };

  /// Converts this error to a full error response.
  Map<String, dynamic> toErrorResponse() => <String, dynamic>{
        'error': toJson(),
      };

  @override
  String toString() => 'HttpsError($code): $message';

  /// Maps error codes to their string representations.
  static String _errorCodeToStatus(FunctionsErrorCode code) => switch (code) {
      FunctionsErrorCode.ok => 'OK',
      FunctionsErrorCode.cancelled => 'CANCELLED',
      FunctionsErrorCode.unknown => 'UNKNOWN',
      FunctionsErrorCode.invalidArgument => 'INVALID_ARGUMENT',
      FunctionsErrorCode.deadlineExceeded => 'DEADLINE_EXCEEDED',
      FunctionsErrorCode.notFound => 'NOT_FOUND',
      FunctionsErrorCode.alreadyExists => 'ALREADY_EXISTS',
      FunctionsErrorCode.permissionDenied => 'PERMISSION_DENIED',
      FunctionsErrorCode.resourceExhausted => 'RESOURCE_EXHAUSTED',
      FunctionsErrorCode.failedPrecondition => 'FAILED_PRECONDITION',
      FunctionsErrorCode.aborted => 'ABORTED',
      FunctionsErrorCode.outOfRange => 'OUT_OF_RANGE',
      FunctionsErrorCode.unimplemented => 'UNIMPLEMENTED',
      FunctionsErrorCode.internal => 'INTERNAL',
      FunctionsErrorCode.unavailable => 'UNAVAILABLE',
      FunctionsErrorCode.dataLoss => 'DATA_LOSS',
      FunctionsErrorCode.unauthenticated => 'UNAUTHENTICATED',
    };

  /// Maps HTTP status codes to error codes (for parsing).
  static FunctionsErrorCode statusToErrorCode(int statusCode) => switch (statusCode) {
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
}
