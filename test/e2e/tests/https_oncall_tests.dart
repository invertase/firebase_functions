import 'dart:convert';

import 'package:test/test.dart';

import '../helpers/emulator.dart';
import '../helpers/http_client.dart';

/// HTTPS onCall and onCallWithData test group
void runHttpsOnCallTests(
  FunctionsHttpClient Function() getClient,
  EmulatorHelper Function() getEmulator,
) {
  group('HTTPS onCall', () {
    late FunctionsHttpClient client;
    late EmulatorHelper emulator;

    setUpAll(() {
      client = getClient();
      emulator = getEmulator();
    });

    test('greet returns expected response with name', () async {
      final response = await client.call('greet', data: {'name': 'Dart'});

      expect(response.statusCode, equals(200));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      expect(
        json['result'],
        equals(<String, dynamic>{'message': 'Hello, Dart!'}),
      );
    });

    test('greet returns default name when no name provided', () async {
      final response = await client.call('greet', data: <String, dynamic>{});

      expect(response.statusCode, equals(200));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      expect(
        json['result'],
        equals(<String, dynamic>{'message': 'Hello, World!'}),
      );
    });

    test('greet returns correct content type', () async {
      final response = await client.call('greet', data: {'name': 'Test'});

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], contains('application/json'));
    });

    test('divide returns correct result', () async {
      final response = await client.call('divide', data: {'a': 10, 'b': 2});

      expect(response.statusCode, equals(200));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      expect(json['result'], equals(<String, dynamic>{'result': 5.0}));
    });

    test('divide throws INVALID_ARGUMENT when args missing', () async {
      final response = await client.call('divide', data: <String, dynamic>{});

      expect(response.statusCode, equals(400));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>;
      expect(error['status'], equals('INVALID_ARGUMENT'));
      expect(error['message'], contains('required'));
    });

    test('divide throws FAILED_PRECONDITION on divide by zero', () async {
      final response = await client.call('divide', data: {'a': 10, 'b': 0});

      expect(response.statusCode, equals(400));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>;
      expect(error['status'], equals('FAILED_PRECONDITION'));
      expect(error['message'], contains('divide by zero'));
    });

    test('getAuthInfo returns unauthenticated when no auth token', () async {
      final response = await client.call(
        'get-auth-info',
        data: <String, dynamic>{},
      );

      expect(response.statusCode, equals(200));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final result = json['result'] as Map<String, dynamic>;
      expect(result['authenticated'], equals(false));
    });

    test('callable rejects GET requests', () async {
      final response = await client.get('greet');

      // Callable functions only accept POST
      expect(response.statusCode, isNot(equals(200)));
    });

    test('callable rejects invalid content type', () async {
      final response = await client.post(
        'greet',
        body: {'data': 'test'},
        headers: {'Content-Type': 'text/plain'},
      );

      expect(response.statusCode, equals(400));
    });

    test('countdown returns result without streaming', () async {
      final response = await client.call('countdown', data: {'start': 3});

      expect(response.statusCode, equals(200));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      expect(
        json['result'],
        equals(<String, dynamic>{'message': 'Countdown complete!'}),
      );
    });

    test('function execution is visible in emulator logs', () async {
      emulator.clearOutputBuffer();

      await client.call('greet', data: {'name': 'LogTest'});

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final executionLogged = emulator.verifyFunctionExecution(
        'us-central1-greet',
      );
      expect(
        executionLogged,
        isTrue,
        reason:
            'Should see "Beginning execution" and "Finished" in emulator logs',
      );
    });
  });

  group('HTTPS onCallWithData', () {
    late FunctionsHttpClient client;

    setUpAll(() {
      client = getClient();
    });

    test('greetTyped returns expected response with name', () async {
      final response = await client.call('greet-typed', data: {'name': 'Dart'});

      expect(response.statusCode, equals(200));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      expect(
        json['result'],
        equals(<String, dynamic>{'message': 'Hello, Dart!'}),
      );
    });

    test('greetTyped uses default name when not provided', () async {
      final response = await client.call(
        'greet-typed',
        data: <String, dynamic>{},
      );

      expect(response.statusCode, equals(200));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      expect(
        json['result'],
        equals(<String, dynamic>{'message': 'Hello, World!'}),
      );
    });

    test('greetTyped returns correct content type', () async {
      final response = await client.call('greet-typed', data: {'name': 'Test'});

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], contains('application/json'));
    });

    test('greetTyped rejects GET requests', () async {
      final response = await client.get('greet-typed');

      expect(response.statusCode, isNot(equals(200)));
    });
  });
}
