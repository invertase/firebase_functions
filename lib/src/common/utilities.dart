import 'dart:convert';

import 'package:shelf/shelf.dart' show Request, Response;

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

InternalError logInternalError(Object error, StackTrace stackTrace) {
  // TODO: should use pkg:stack_trace to make the stack easier to read
  logger.error('''
$error
$stackTrace
''');
  return InternalError();
}
