import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// JSON decoder function type.
typedef JsonDecoder<T extends Object?> = T Function(Map<String, dynamic>);

/// Result of a callable function.
///
/// Wraps the return value from a callable function handler.
class CallableResult<T extends Object> {
  final T data;

  CallableResult(this.data);

  /// Converts this result to a Shelf Response.
  Response toResponse() {
    return Response.ok(
      jsonEncode({'result': data}),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      },
    );
  }
}

/// Request context for a callable function.
///
/// Provides access to request data, authentication context, and headers.
class CallableRequest<T extends Object?> {
  final Request _delegate;
  final Object? _body;
  final JsonDecoder<T>? _jsonDecoder;

  CallableRequest(this._delegate, this._body, this._jsonDecoder);

  /// The request data (from the 'data' field in the request body).
  T get data {
    final decoded = decode(_body);

    if (_jsonDecoder == null) {
      // Use dynamic cast for flexibility
      return decoded as T;
    }

    // If jsonDecoder is provided, decoded must be a Map
    if (decoded is! Map<String, dynamic>) {
      throw StateError(
        'Expected Map<String, dynamic> for jsonDecoder, but got ${decoded.runtimeType}',
      );
    }

    return _jsonDecoder!(decoded);
  }

  /// Whether the client accepts streaming (SSE) responses.
  bool get acceptsStreaming {
    return _delegate.headers['accept'] == 'text/event-stream';
  }

  /// Firebase App Check context.
  ///
  /// TODO: Implement App Check validation
  Object? get app => null;

  /// Firebase Authentication context.
  ///
  /// TODO: Implement auth token validation and parsing
  Object? get auth => null;

  /// Firebase Instance ID token.
  String? get instanceIdToken {
    return _delegate.headers['Firebase-Instance-ID-Token'];
  }

  /// The raw Shelf request.
  Request get rawRequest => _delegate;
}

/// Response helper for callable functions.
///
/// Provides streaming support via Server-Sent Events (SSE).
class CallableResponse<T extends Object> {
  final bool acceptsStreaming;
  final int? heartbeatSeconds;

  StreamController<String>? _streamController;
  Response? _streamingResponse;
  Timer? _heartbeatTimer;
  bool _aborted = false;

  CallableResponse({required this.acceptsStreaming, this.heartbeatSeconds});

  /// Initializes SSE streaming.
  void initializeStreaming() {
    _streamController = StreamController<String>();
    _streamingResponse = Response.ok(
      _streamController!.stream,
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    );

    // Schedule heartbeat if configured
    if (heartbeatSeconds != null && heartbeatSeconds! > 0) {
      _scheduleHeartbeat();
    }
  }

  /// Sends a chunk of data to the client via SSE.
  ///
  /// Returns true if the chunk was sent successfully, false if streaming
  /// is not active or the connection was closed.
  Future<bool> sendChunk(T chunk) async {
    if (!acceptsStreaming) {
      return false;
    }

    if (_aborted || _streamController == null || _streamController!.isClosed) {
      return false;
    }

    try {
      final formattedData = _encodeSSE({'message': chunk});
      _streamController!.add(formattedData);

      // Reset heartbeat timer after successful write
      if (heartbeatSeconds != null && heartbeatSeconds! > 0) {
        _scheduleHeartbeat();
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Writes an SSE event to the stream.
  void writeSSE(Map<String, dynamic> data) {
    if (_streamController == null || _streamController!.isClosed) {
      return;
    }
    _streamController!.add(_encodeSSE(data));
  }

  /// Closes the streaming response.
  Future<void> closeStream() async {
    if (_streamController != null && !_streamController!.isClosed) {
      await _streamController!.close();
    }
  }

  /// Clears the heartbeat timer.
  void clearHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Gets the streaming response (for internal use).
  Response? get streamingResponse => _streamingResponse;

  /// Whether the stream has been aborted.
  bool get aborted => _aborted;

  /// Schedules the next heartbeat ping.
  void _scheduleHeartbeat() {
    clearHeartbeat();

    if (heartbeatSeconds == null || heartbeatSeconds! <= 0) {
      return;
    }

    _heartbeatTimer = Timer(Duration(seconds: heartbeatSeconds!), () {
      if (!_aborted &&
          _streamController != null &&
          !_streamController!.isClosed) {
        _streamController!.add(': ping\n\n');
        _scheduleHeartbeat();
      }
    });
  }

  /// Encodes data as SSE format.
  String _encodeSSE(Map<String, dynamic> data) {
    final encoded = jsonEncode(data);
    return 'data: $encoded\n\n';
  }
}

/// Decodes request data, handling special types (like Int64).
///
/// Matches the decode behavior from the Node.js SDK.
Object? decode(Object? body) {
  if (body == null) {
    return body;
  }

  if (body is List) {
    return body.map(decode).toList();
  }

  if (body is Map) {
    // Handle special @type encoding for Int64/UInt64
    if (body.containsKey('@type')) {
      final type = body['@type'];
      if (type == 'type.googleapis.com/google.protobuf.Int64Value' ||
          type == 'type.googleapis.com/google.protobuf.UInt64Value') {
        final value = double.tryParse(body['value'].toString());
        if (value == null) {
          throw FormatException('Invalid Int64/UInt64 value: ${body['value']}');
        }
        return value;
      }
      throw FormatException('Unsupported @type: $type');
    }

    return body.map((key, value) => MapEntry(key, decode(value)));
  }

  return body;
}

/// Encodes response data for transmission.
///
/// Matches the encode behavior from the Node.js SDK.
Object? encode(Object? data) {
  if (data == null) {
    return null;
  }

  // Numbers
  if (data is num) {
    if (data.isFinite) {
      return data;
    }
    throw ArgumentError('Cannot encode non-finite number: $data');
  }

  // Booleans and strings
  if (data is bool || data is String) {
    return data;
  }

  // DateTime
  if (data is DateTime) {
    return data.toIso8601String();
  }

  // Lists
  if (data is List) {
    return data.map(encode).toList();
  }

  // Maps
  if (data is Map) {
    final obj = <String, dynamic>{};
    data.forEach((k, v) {
      obj[k.toString()] = encode(v);
    });
    return obj;
  }

  throw ArgumentError('Data cannot be encoded in JSON: $data');
}

/// Extension methods for Request validation.
extension RequestValidation on Request {
  /// Parses JSON from the request body.
  Future<Object?> get json async {
    final body = await change().readAsString();
    return body.isEmpty ? null : jsonDecode(body);
  }

  /// Validates that this is a valid callable request.
  ///
  /// Checks:
  /// - Method is POST
  /// - Content-Type is application/json
  /// - Body contains only 'data' field
  Future<bool> isValidRequest([Map<String, dynamic>? body]) async {
    // Get body (use provided or read from request)
    final requestBody = body ?? await json;

    if (requestBody == null) {
      return false;
    }

    // Must be POST
    if (method.toUpperCase() != 'POST') {
      return false;
    }

    // Must be application/json
    var contentType = headers[HttpHeaders.contentTypeHeader] ?? '';
    final semiColonIndex = contentType.indexOf(';');
    if (semiColonIndex >= 0) {
      contentType = contentType.substring(0, semiColonIndex).trim();
    }

    if (contentType != 'application/json') {
      return false;
    }

    // Body must be a Map with only 'data' field
    if (requestBody is! Map<String, dynamic>) {
      return false;
    }

    final extraKeys = requestBody.keys.where((field) => field != 'data').toList();
    if (extraKeys.isNotEmpty) {
      return false;
    }

    return true;
  }
}
