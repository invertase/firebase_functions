import 'dart:convert';

import 'package:firebase_functions/src/firebase.dart';
import 'package:firebase_functions/src/https/callable.dart';
import 'package:firebase_functions/src/https/error.dart';
import 'package:firebase_functions/src/https/https_namespace.dart';
import 'package:firebase_functions/src/https/options.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// Helper to find function by name (uses kebab-case Cloud Run ID)
FirebaseFunctionDeclaration? _findFunction(Firebase firebase, String name) {
  try {
    return firebase.functions.firstWhere((f) => f.name == name);
  } catch (e) {
    return null;
  }
}

void main() {
  group('HttpsNamespace', () {
    late Firebase firebase;
    late HttpsNamespace https;

    setUp(() {
      firebase = Firebase();
      https = HttpsNamespace(firebase);
    });

    group('onRequest', () {
      test('registers function with firebase', () {
        https.onRequest(
          name: 'testFunction',
          (request) async => Response.ok('Hello'),
        );

        expect(_findFunction(firebase, 'test-function'), isNotNull);
      });

      test('handler receives request and returns response', () async {
        https.onRequest(
          name: 'testFunction',
          (request) async => Response.ok('Hello, World!'),
        );

        final func = _findFunction(firebase, 'test-function')!;
        final request = Request(
          'GET',
          Uri.parse('http://localhost/test-function'),
        );
        final response = await func.handler(request);

        expect(response.statusCode, 200);
        expect(await response.readAsString(), 'Hello, World!');
      });

      test('catches HttpsError and returns proper error response', () async {
        https.onRequest(name: 'errorFunction', (request) async {
          throw NotFoundError('Resource not found');
        });

        final func = _findFunction(firebase, 'error-function')!;
        final request = Request(
          'GET',
          Uri.parse('http://localhost/error-function'),
        );
        final response = await func.handler(request);

        expect(response.statusCode, 404);
        expect(response.headers['Content-Type'], 'application/json');

        final body = jsonDecode(await response.readAsString());
        expect(body['error']['status'], 'NOT_FOUND');
        expect(body['error']['message'], 'Resource not found');
      });

      test('catches unexpected errors and returns internal error', () async {
        https.onRequest(name: 'crashFunction', (request) async {
          throw Exception('Unexpected crash');
        });

        final func = _findFunction(firebase, 'crash-function')!;
        final request = Request(
          'GET',
          Uri.parse('http://localhost/crash-function'),
        );
        final response = await func.handler(request);

        expect(response.statusCode, 500);
        expect(response.headers['Content-Type'], 'application/json');

        final body = jsonDecode(await response.readAsString());
        expect(body['error']['status'], 'INTERNAL');
      });

      test('marks function as external', () {
        https.onRequest(
          name: 'externalFunction',
          (request) async => Response.ok('OK'),
        );

        final func = _findFunction(firebase, 'external-function')!;
        expect(func.external, isTrue);
      });

      test('uses correct HTTP status codes for different errors', () async {
        https.onRequest(name: 'unauthorizedFunction', (request) async {
          throw UnauthenticatedError('Not logged in');
        });

        final func = _findFunction(firebase, 'unauthorized-function')!;
        final request = Request('GET', Uri.parse('http://localhost/test'));
        final response = await func.handler(request);

        expect(response.statusCode, 401);
      });
    });

    group('onCall', () {
      Request createCallableRequest({
        Map<String, dynamic> data = const {},
        Map<String, String> headers = const {},
      }) {
        final body = jsonEncode({'data': data});
        return Request(
          'POST',
          Uri.parse('http://localhost/test-function'),
          headers: {'content-type': 'application/json', ...headers},
          body: body,
        );
      }

      test('registers function with firebase', () {
        https.onCall(
          name: 'callableFunction',
          (request, response) async => CallableResult('OK'),
        );

        expect(_findFunction(firebase, 'callable-function'), isNotNull);
      });

      test('handler returns wrapped result', () async {
        https.onCall(name: 'greetFunction', (request, response) async {
          final data = request.data as Map<String, dynamic>;
          final name = data['name'] as String;
          return CallableResult({'message': 'Hello, $name!'});
        });

        final func = _findFunction(firebase, 'greet-function')!;
        final request = createCallableRequest(data: {'name': 'World'});
        final response = await func.handler(request);

        expect(response.statusCode, 200);
        expect(response.headers['content-type'], 'application/json');

        final body = jsonDecode(await response.readAsString());
        expect(body['result'], {'message': 'Hello, World!'});
      });

      test('validates request is POST', () async {
        https.onCall(
          name: 'postOnlyFunction',
          (request, response) async => CallableResult('OK'),
        );

        final func = _findFunction(firebase, 'post-only-function')!;
        final request = Request(
          'GET',
          Uri.parse('http://localhost/post-only-function'),
          headers: {'content-type': 'application/json'},
        );
        final response = await func.handler(request);

        expect(response.statusCode, 400);
        final body = jsonDecode(await response.readAsString());
        expect(body['error']['status'], 'INVALID_ARGUMENT');
      });

      test('validates content-type is application/json', () async {
        https.onCall(
          name: 'jsonOnlyFunction',
          (request, response) async => CallableResult('OK'),
        );

        final func = _findFunction(firebase, 'json-only-function')!;
        final request = Request(
          'POST',
          Uri.parse('http://localhost/json-only-function'),
          headers: {'content-type': 'text/plain'},
          body: '{"data": "test"}',
        );
        final response = await func.handler(request);

        expect(response.statusCode, 400);
      });

      test('catches HttpsError and returns proper status', () async {
        https.onCall(name: 'errorFunction', (request, response) async {
          throw PermissionDeniedError('Not authorized');
        });

        final func = _findFunction(firebase, 'error-function')!;
        final request = createCallableRequest();
        final response = await func.handler(request);

        expect(response.statusCode, 403);
        final body = jsonDecode(await response.readAsString());
        expect(body['error']['status'], 'PERMISSION_DENIED');
        expect(body['error']['message'], 'Not authorized');
      });

      test('catches unexpected errors as internal errors', () async {
        https.onCall(name: 'crashFunction', (request, response) async {
          throw StateError('Something broke');
        });

        final func = _findFunction(firebase, 'crash-function')!;
        final request = createCallableRequest();
        final response = await func.handler(request);

        expect(response.statusCode, 500);
        final body = jsonDecode(await response.readAsString());
        expect(body['error']['status'], 'INTERNAL');
      });

      test('returns JSON when client does not accept SSE', () async {
        https.onCall(name: 'nonStreamFunction', (request, response) async {
          return CallableResult('result');
        });

        final func = _findFunction(firebase, 'non-stream-function')!;
        final request = createCallableRequest();
        final response = await func.handler(request);

        expect(response.statusCode, 200);
        expect(response.headers['content-type'], 'application/json');

        final body = jsonDecode(await response.readAsString());
        expect(body['result'], 'result');
      });

      test('JsonResult returns Map data correctly', () async {
        https.onCall(name: 'jsonResultFunction', (request, response) async {
          return JsonResult({'status': 'ok', 'count': 42});
        });

        final func = _findFunction(firebase, 'json-result-function')!;
        final request = createCallableRequest();
        final response = await func.handler(request);

        final body = jsonDecode(await response.readAsString());
        expect(body['result'], {'status': 'ok', 'count': 42});
      });
    });

    group('onCallWithData', () {
      Request createCallableRequest({
        Map<String, dynamic> data = const {},
        Map<String, String> headers = const {},
      }) {
        final body = jsonEncode({'data': data});
        return Request(
          'POST',
          Uri.parse('http://localhost/test-function'),
          headers: {'content-type': 'application/json', ...headers},
          body: body,
        );
      }

      test('registers function with firebase', () {
        https.onCallWithData<_GreetRequest, _GreetResponse>(
          name: 'typedFunction',
          fromJson: _GreetRequest.fromJson,
          (request, response) async {
            return _GreetResponse('Hello, ${request.data.name}!');
          },
        );

        expect(_findFunction(firebase, 'typed-function'), isNotNull);
      });

      test('deserializes input using fromJson', () async {
        https.onCallWithData<_GreetRequest, String>(
          name: 'typedFunction',
          fromJson: _GreetRequest.fromJson,
          (request, response) async {
            expect(request.data, isA<_GreetRequest>());
            expect(request.data.name, 'World');
            return 'Hello, ${request.data.name}!';
          },
        );

        final func = _findFunction(firebase, 'typed-function')!;
        final request = createCallableRequest(data: {'name': 'World'});
        final response = await func.handler(request);

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.readAsString());
        expect(body['result'], 'Hello, World!');
      });

      test('returns typed output correctly', () async {
        https.onCallWithData<_GreetRequest, _GreetResponse>(
          name: 'typedOutputFunction',
          fromJson: _GreetRequest.fromJson,
          (request, response) async {
            return _GreetResponse('Hello, ${request.data.name}!');
          },
        );

        final func = _findFunction(firebase, 'typed-output-function')!;
        final request = createCallableRequest(data: {'name': 'World'});
        final response = await func.handler(request);

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.readAsString());
        // _GreetResponse is encoded via its toJson method
        expect(body['result'], {'message': 'Hello, World!'});
      });

      test('validates request is POST', () async {
        https.onCallWithData<_GreetRequest, String>(
          name: 'postOnlyTypedFunction',
          fromJson: _GreetRequest.fromJson,
          (request, response) async => 'OK',
        );

        final func = _findFunction(firebase, 'post-only-typed-function')!;
        final request = Request(
          'GET',
          Uri.parse('http://localhost/post-only-typed-function'),
          headers: {'content-type': 'application/json'},
        );
        final response = await func.handler(request);

        expect(response.statusCode, 400);
      });

      test('catches HttpsError and returns proper status', () async {
        https.onCallWithData<_GreetRequest, String>(
          name: 'errorTypedFunction',
          fromJson: _GreetRequest.fromJson,
          (request, response) async {
            throw InvalidArgumentError('Name cannot be empty');
          },
        );

        final func = _findFunction(firebase, 'error-typed-function')!;
        final request = createCallableRequest(data: {'name': ''});
        final response = await func.handler(request);

        expect(response.statusCode, 400);
        final body = jsonDecode(await response.readAsString());
        expect(body['error']['status'], 'INVALID_ARGUMENT');
        expect(body['error']['message'], 'Name cannot be empty');
      });
    });

    group('Options', () {
      test('HttpsOptions can be provided', () {
        https.onRequest(
          name: 'optionsFunction',
          options: const HttpsOptions(cors: Cors(['https://example.com'])),
          (request) async => Response.ok('OK'),
        );

        expect(_findFunction(firebase, 'options-function'), isNotNull);
      });

      test('CallableOptions can be provided', () {
        https.onCall(
          name: 'callableOptionsFunction',
          options: const CallableOptions(
            heartBeatIntervalSeconds: HeartBeatIntervalSeconds(30),
          ),
          (request, response) async => CallableResult('OK'),
        );

        expect(_findFunction(firebase, 'callable-options-function'), isNotNull);
      });
    });
  });
}

// Test helper classes
class _GreetRequest {
  _GreetRequest(this.name);

  factory _GreetRequest.fromJson(Map<String, dynamic> json) {
    return _GreetRequest(json['name'] as String);
  }

  final String name;
}

class _GreetResponse {
  _GreetResponse(this.message);

  final String message;

  Map<String, dynamic> toJson() => {'message': message};

  @override
  String toString() => message;
}
