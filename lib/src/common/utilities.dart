import 'dart:convert';

import 'package:shelf/shelf.dart' show Request, Response;
import 'package:stack_trace/stack_trace.dart' show Trace;

import '../https/error.dart';
import '../logger/logger.dart';

Future<Map<String, dynamic>> readAsJsonMap(Request request) async {
  final decoded = await _converter.bind(request.read()).first;
  return switch (decoded) {
    final Map<String, dynamic> m => m,
    _ => throw FormatException('CloudEvent body must be a JSON object'),
  };
}

final _converter = const Utf8Decoder().fuse(const JsonDecoder());

extension HttpErrorExtension on HttpsError {
  Response toShelfResponse() => Response(
    httpStatusCode,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(toErrorResponse()),
  );
}

/// Logs an unexpected error with its stack trace and returns an [InternalError].
///
/// Use in HTTPS and callable function handlers where the response must be
/// a structured JSON error. The actual error details are only logged
/// server-side and never exposed to the client.
InternalError logInternalError(Object error, StackTrace stackTrace) {
  _logError(error, stackTrace);
  return InternalError();
}

/// Logs an unexpected error with its stack trace and returns a generic 500
/// response.
///
/// Use in event-triggered function handlers (Firestore, PubSub, Storage, etc.)
/// where the caller is the Cloud Functions infrastructure rather than an
/// end-user client.
Response logEventHandlerError(Object error, StackTrace stackTrace) {
  _logError(error, stackTrace);
  return Response.internalServerError();
}

/// Formats and logs an error with a terse, readable stack trace.
void _logError(Object error, StackTrace stackTrace) {
  final terse = Trace.from(stackTrace).terse;
  logger.error('$error\n$terse');
}
