import 'dart:convert';

import 'package:shelf/shelf.dart' show Request, Response;

import '../https/error.dart';

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
