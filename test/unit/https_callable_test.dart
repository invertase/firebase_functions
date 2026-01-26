import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';

import 'package:firebase_functions/src/https/callable.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('CallableResult', () {
    test('holds data correctly', () {
      final result = CallableResult('hello');
      expect(result.data, 'hello');
    });

    test('toResponse returns correct JSON structure', () async {
      final result = CallableResult({'message': 'Hello'});
      final response = result.toResponse();

      expect(response.statusCode, 200);
      expect(
        response.headers[HttpHeaders.contentTypeHeader],
        'application/json',
      );

      final body = jsonDecode(await response.readAsString());
      expect(body, {
        'result': {'message': 'Hello'},
      });
    });

    test('toResponse handles string data', () async {
      final result = CallableResult('simple string');
      final response = result.toResponse();

      final body = jsonDecode(await response.readAsString());
      expect(body, {'result': 'simple string'});
    });

    test('toResponse handles numeric data', () async {
      final result = CallableResult(42);
      final response = result.toResponse();

      final body = jsonDecode(await response.readAsString());
      expect(body, {'result': 42});
    });

    test('toResponse handles list data', () async {
      final result = CallableResult([1, 2, 3]);
      final response = result.toResponse();

      final body = jsonDecode(await response.readAsString());
      expect(body, {
        'result': [1, 2, 3],
      });
    });
  });

  group('JsonResult', () {
    test('extends CallableResult with Map type', () {
      final result = JsonResult({'status': 'ok'});
      expect(result, isA<CallableResult<Map<String, dynamic>>>());
      expect(result.data, {'status': 'ok'});
    });

    test('toResponse returns correct JSON structure', () async {
      final result = JsonResult({'status': 'ok', 'count': 5});
      final response = result.toResponse();

      final body = jsonDecode(await response.readAsString());
      expect(body, {
        'result': {'status': 'ok', 'count': 5},
      });
    });
  });

  group('AuthData', () {
    test('holds uid correctly', () {
      const auth = AuthData(uid: 'user123');
      expect(auth.uid, 'user123');
      expect(auth.token, isNull);
    });

    test('holds token claims correctly', () {
      const auth = AuthData(
        uid: 'user123',
        token: {'email': 'test@example.com', 'admin': true},
      );
      expect(auth.uid, 'user123');
      expect(auth.token, {'email': 'test@example.com', 'admin': true});
    });
  });

  group('AppCheckData', () {
    test('holds appId correctly', () {
      const appCheck = AppCheckData(appId: 'app123');
      expect(appCheck.appId, 'app123');
      expect(appCheck.token, isNull);
      expect(appCheck.alreadyConsumed, isNull);
    });

    test('holds all fields correctly', () {
      const appCheck = AppCheckData(
        appId: 'app123',
        token: 'token-value',
        alreadyConsumed: false,
      );
      expect(appCheck.appId, 'app123');
      expect(appCheck.token, 'token-value');
      expect(appCheck.alreadyConsumed, false);
    });
  });

  group('CallableRequest', () {
    Request createRequest({
      String method = 'POST',
      Map<String, String>? headers,
      String? body,
    }) {
      return Request(
        method,
        Uri.parse('http://localhost:8080/test'),
        headers: headers,
        body: body,
      );
    }

    test('data returns decoded body data', () {
      final request = CallableRequest<Map<String, dynamic>>(createRequest(), {
        'name': 'John',
        'age': 30,
      }, null);

      expect(request.data, {'name': 'John', 'age': 30});
    });

    test('data uses fromJson decoder when provided', () {
      final request = CallableRequest<_TestUser>(createRequest(), {
        'name': 'John',
        'age': 30,
      }, _TestUser.fromJson);

      final user = request.data;
      expect(user.name, 'John');
      expect(user.age, 30);
    });

    test('data throws when fromJson expects Map but gets non-Map', () {
      final request = CallableRequest<_TestUser>(
        createRequest(),
        'not a map',
        _TestUser.fromJson,
      );

      expect(() => request.data, throwsStateError);
    });

    test('acceptsStreaming returns true for SSE accept header', () {
      final request = CallableRequest(
        createRequest(headers: {'accept': 'text/event-stream'}),
        null,
        null,
      );

      expect(request.acceptsStreaming, isTrue);
    });

    test('acceptsStreaming returns false for other accept headers', () {
      final request = CallableRequest(
        createRequest(headers: {'accept': 'application/json'}),
        null,
        null,
      );

      expect(request.acceptsStreaming, isFalse);
    });

    test('acceptsStreaming returns false when no accept header', () {
      final request = CallableRequest(createRequest(), null, null);

      expect(request.acceptsStreaming, isFalse);
    });

    test('auth is accessible', () {
      const authData = AuthData(uid: 'user123');
      final request = CallableRequest(
        createRequest(),
        null,
        null,
        auth: authData,
      );

      expect(request.auth?.uid, 'user123');
    });

    test('app is accessible', () {
      const appCheckData = AppCheckData(appId: 'app123');
      final request = CallableRequest(
        createRequest(),
        null,
        null,
        app: appCheckData,
      );

      expect(request.app?.appId, 'app123');
    });

    test('instanceIdToken extracts from header', () {
      final request = CallableRequest(
        createRequest(
          headers: {'Firebase-Instance-ID-Token': 'instance-token'},
        ),
        null,
        null,
      );

      expect(request.instanceIdToken, 'instance-token');
    });

    test('rawRequest returns underlying request', () {
      final shelfRequest = createRequest();
      final request = CallableRequest(shelfRequest, null, null);

      expect(request.rawRequest, same(shelfRequest));
    });
  });

  group('CallableResponse', () {
    test('acceptsStreaming is set correctly', () {
      final response = CallableResponse<String>(acceptsStreaming: true);
      expect(response.acceptsStreaming, isTrue);

      final response2 = CallableResponse<String>(acceptsStreaming: false);
      expect(response2.acceptsStreaming, isFalse);
    });

    test('heartbeatSeconds is set correctly', () {
      final response = CallableResponse<String>(
        acceptsStreaming: true,
        heartbeatSeconds: 30,
      );
      expect(response.heartbeatSeconds, 30);
    });

    test('initializeStreaming creates streamingResponse', () {
      final response = CallableResponse<String>(acceptsStreaming: true);
      response.initializeStreaming();

      expect(response.streamingResponse, isNotNull);
      expect(
        response.streamingResponse!.headers['Content-Type'],
        'text/event-stream',
      );
      expect(response.streamingResponse!.headers['Cache-Control'], 'no-cache');
      expect(response.streamingResponse!.headers['Connection'], 'keep-alive');

      // Cleanup
      unawaited(response.closeStream());
    });

    test('sendChunk returns false when not streaming', () async {
      final response = CallableResponse<String>(acceptsStreaming: false);
      final success = await response.sendChunk('test');

      expect(success, isFalse);
    });

    test('sendChunk returns false when aborted', () async {
      final response = CallableResponse<String>(acceptsStreaming: true);
      response.initializeStreaming();
      response.abort();

      final success = await response.sendChunk('test');
      expect(success, isFalse);
    });

    test('sendChunk sends SSE formatted data', () async {
      final response = CallableResponse<String>(acceptsStreaming: true);
      response.initializeStreaming();

      // Send a chunk - should succeed
      final success = await response.sendChunk('hello');
      expect(success, isTrue);

      // The streamingResponse should have correct headers
      expect(
        response.streamingResponse!.headers['Content-Type'],
        'text/event-stream',
      );

      // Clean up without awaiting (since no consumer)
      response.clearHeartbeat();
    });

    test('writeSSE sends raw SSE data', () {
      final response = CallableResponse<String>(acceptsStreaming: true);
      response.initializeStreaming();

      // writeSSE should not throw
      response.writeSSE({'result': 'done'});

      expect(response.streamingResponse, isNotNull);

      // Clean up
      response.clearHeartbeat();
    });

    test('closeStream prevents subsequent sends', () async {
      final response = CallableResponse<String>(acceptsStreaming: true);
      response.initializeStreaming();

      // Close without awaiting (no consumer)
      unawaited(response.closeStream());

      // Give time for close to process
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Subsequent sends should fail because stream is closed
      final success = await response.sendChunk('test');
      expect(success, isFalse);
    });

    test('aborted returns correct state', () {
      final response = CallableResponse<String>(acceptsStreaming: true);
      response.initializeStreaming();

      expect(response.aborted, isFalse);
      response.abort();
      expect(response.aborted, isTrue);
    });

    test('clearHeartbeat clears the timer', () {
      final response = CallableResponse<String>(
        acceptsStreaming: true,
        heartbeatSeconds: 1,
      );
      response.initializeStreaming();

      // Just verify it doesn't throw
      response.clearHeartbeat();

      unawaited(response.closeStream());
    });

    test('stream method forwards stream data', () async {
      final response = CallableResponse<int>(acceptsStreaming: true);
      response.initializeStreaming();

      // Create a stream of results
      final sourceStream = Stream.fromIterable([
        CallableResult(1),
        CallableResult(2),
        CallableResult(3),
      ]);

      response.stream(sourceStream);

      // Give time for stream to process
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify the streaming response was set up correctly
      expect(response.streamingResponse, isNotNull);
      expect(
        response.streamingResponse!.headers['Content-Type'],
        'text/event-stream',
      );

      // Clean up
      response.clearHeartbeat();
    });

    test('stream method does nothing when not accepting streaming', () async {
      final response = CallableResponse<int>(acceptsStreaming: false);

      var streamCompleted = false;
      final sourceStream = Stream.fromIterable([CallableResult(1)]).map((e) {
        streamCompleted = true;
        return e;
      });

      response.stream(sourceStream);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Stream should not have been consumed
      expect(streamCompleted, isFalse);
    });
  });

  group('decode', () {
    test('returns null for null input', () {
      expect(decode(null), isNull);
    });

    test('handles lists recursively', () {
      final result = decode([1, 2, 3]);
      expect(result, [1, 2, 3]);
    });

    test('handles nested lists', () {
      final result = decode([
        [1, 2],
        [3, 4],
      ]);
      expect(result, [
        [1, 2],
        [3, 4],
      ]);
    });

    test('handles maps recursively', () {
      final result = decode({
        'a': 1,
        'b': {'c': 2},
      });
      expect(result, {
        'a': 1,
        'b': {'c': 2},
      });
    });

    test('decodes Int64Value special type', () {
      final result = decode({
        '@type': 'type.googleapis.com/google.protobuf.Int64Value',
        'value': '9223372036854775807',
      });
      expect(result, 9223372036854775807);
    });

    test('decodes UInt64Value special type', () {
      final result = decode({
        '@type': 'type.googleapis.com/google.protobuf.UInt64Value',
        'value': '18446744073709551615',
      });
      // This will be truncated due to double precision
      expect(result, isA<double>());
    });

    test('throws for invalid Int64 value', () {
      expect(
        () => decode({
          '@type': 'type.googleapis.com/google.protobuf.Int64Value',
          'value': 'not-a-number',
        }),
        throwsFormatException,
      );
    });

    test('throws for unsupported @type', () {
      expect(
        () => decode({
          '@type': 'type.googleapis.com/some.other.Type',
          'value': 'data',
        }),
        throwsFormatException,
      );
    });

    test('passes through primitives', () {
      expect(decode('string'), 'string');
      expect(decode(42), 42);
      expect(decode(3.14), 3.14);
      expect(decode(true), true);
    });
  });

  group('encode', () {
    test('returns null for null input', () {
      expect(encode(null), isNull);
    });

    test('handles finite numbers', () {
      expect(encode(42), 42);
      expect(encode(3.14), 3.14);
    });

    test('throws for non-finite numbers', () {
      expect(() => encode(double.infinity), throwsArgumentError);
      expect(() => encode(double.negativeInfinity), throwsArgumentError);
      expect(() => encode(double.nan), throwsArgumentError);
    });

    test('handles booleans', () {
      expect(encode(true), true);
      expect(encode(false), false);
    });

    test('handles strings', () {
      expect(encode('hello'), 'hello');
    });

    test('handles DateTime', () {
      final dt = DateTime.utc(2024, 1, 15, 12, 30, 45);
      expect(encode(dt), '2024-01-15T12:30:45.000Z');
    });

    test('handles lists recursively', () {
      final result = encode([1, 'two', true]);
      expect(result, [1, 'two', true]);
    });

    test('handles maps recursively', () {
      final result = encode({'a': 1, 'b': 'two'});
      expect(result, {'a': 1, 'b': 'two'});
    });

    test('converts map keys to strings', () {
      final result = encode({1: 'one', 2: 'two'});
      expect(result, {'1': 'one', '2': 'two'});
    });

    test('throws for unsupported types', () {
      expect(() => encode(_CustomObject()), throwsArgumentError);
    });
  });

  group('RequestValidation', () {
    Request createRequest({
      String method = 'POST',
      String contentType = 'application/json',
      Map<String, dynamic>? body,
    }) {
      final bodyString = body != null ? jsonEncode(body) : '';
      return Request(
        method,
        Uri.parse('http://localhost:8080/test'),
        headers: {'content-type': contentType},
        body: bodyString,
      );
    }

    test('json parses request body', () async {
      final request = createRequest(body: {'data': 'test'});
      final json = await request.json;
      expect(json, {'data': 'test'});
    });

    test('json returns null for empty body', () async {
      final request = Request('POST', Uri.parse('http://localhost:8080/test'));
      final json = await request.json;
      expect(json, isNull);
    });

    test('isValidRequest returns true for valid POST request', () async {
      final request = createRequest(body: {'data': 'test'});
      expect(await request.isValidRequest(), isTrue);
    });

    test('isValidRequest returns false for GET request', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/test'),
        headers: {'content-type': 'application/json'},
      );
      expect(await request.isValidRequest({'data': 'test'}), isFalse);
    });

    test('isValidRequest returns false for non-JSON content type', () async {
      final request = createRequest(
        contentType: 'text/plain',
        body: {'data': 'test'},
      );
      expect(await request.isValidRequest(), isFalse);
    });

    test('isValidRequest returns false for null body', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost:8080/test'),
        headers: {'content-type': 'application/json'},
      );
      expect(await request.isValidRequest(), isFalse);
    });

    test('isValidRequest returns false for extra fields in body', () async {
      final request = createRequest(body: {'data': 'test', 'extra': 'field'});
      expect(await request.isValidRequest(), isFalse);
    });

    test('isValidRequest handles content-type with charset', () async {
      final bodyString = jsonEncode({'data': 'test'});
      final request = Request(
        'POST',
        Uri.parse('http://localhost:8080/test'),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: bodyString,
      );
      expect(await request.isValidRequest(), isTrue);
    });

    test('isValidRequest accepts provided body parameter', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost:8080/test'),
        headers: {'content-type': 'application/json'},
        body: '', // Empty body
      );
      // Provide body directly
      expect(await request.isValidRequest({'data': 'test'}), isTrue);
    });
  });
}

// Test helper classes
class _TestUser {
  _TestUser(this.name, this.age);

  factory _TestUser.fromJson(Map<String, dynamic> json) {
    return _TestUser(json['name'] as String, json['age'] as int);
  }

  final String name;
  final int age;
}

class _CustomObject {}
