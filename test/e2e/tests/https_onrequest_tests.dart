import 'dart:convert';

import 'package:test/test.dart';

import '../helpers/emulator.dart';
import '../helpers/http_client.dart';

/// HTTPS onRequest test group
void runHttpsOnRequestTests(
  FunctionsHttpClient Function() getClient,
  EmulatorHelper Function() getEmulator,
) {
  group('HTTPS onRequest', () {
    late FunctionsHttpClient client;
    late EmulatorHelper emulator;

    setUpAll(() {
      client = getClient();
      emulator = getEmulator();
    });
    test('hello-world returns expected response', () async {
      print('GET ${client.baseUrl}/hello-world');
      final response = await client.get('hello-world');

      expect(response.statusCode, equals(200));
      expect(response.body, contains('Hello from Dart Functions!'));
    });

    test('hello-world has correct content type', () async {
      print('GET ${client.baseUrl}/hello-world');
      final response = await client.get('hello-world');

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], contains('text/plain'));
    });

    test('hello-world accepts GET requests', () async {
      print('GET ${client.baseUrl}/hello-world');
      final response = await client.get('hello-world');

      expect(response.statusCode, equals(200));
    });

    test('hello-world accepts POST requests', () async {
      print('POST ${client.baseUrl}/hello-world');
      final response = await client.post('hello-world');

      expect(response.statusCode, equals(200));
    });

    test('calling non-existent function returns 404', () async {
      print('GET ${client.baseUrl}/non-existent-function');
      final response = await client.get('non-existent-function');

      expect(response.statusCode, equals(404));
    });

    test(
      'handles multiple concurrent requests',
      () async {
        // Reduced from 10 to 5 requests to avoid CI timeout issues
        // The emulator spawns separate workers which can be slow in CI
        print('Making 5 concurrent requests...');
        final futures = <Future<void>>[];

        for (var i = 0; i < 5; i++) {
          futures.add(() async {
            final response = await client.get('hello-world');
            expect(response.statusCode, equals(200));
            expect(response.body, contains('Hello from Dart Functions!'));
          }());
        }

        await Future.wait(futures);
      },
      timeout: Timeout(Duration(seconds: 60)),
    );

    test('function is discoverable via emulator', () async {
      print('GET ${client.baseUrl}/hello-world');
      final response = await client.get('hello-world');

      expect(
        response.statusCode,
        equals(200),
        reason: 'Function hello-world should be deployed',
      );
    });

    test(
      'unexpected error returns INTERNAL without leaking sensitive details',
      () async {
        print('GET ${client.baseUrl}/crash-with-secret');
        final response = await client.get('crash-with-secret');

        // Should return 500
        expect(response.statusCode, equals(500));

        // Parse the JSON error body
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final error = json['error'] as Map<String, dynamic>;

        // Generic INTERNAL error is returned
        expect(error['status'], equals('INTERNAL'));
        expect(error['message'], equals('An unexpected error occurred.'));

        // Sensitive details must NOT appear anywhere in the response
        expect(response.body, isNot(contains('sk_live_T0P_s3cReT_k3y!2026')));
        expect(response.body, isNot(contains('sensitive data')));
        expect(response.body, isNot(contains('Unexpected failure')));

        // Verify the error WAS logged server-side (visible in emulator output)
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final allLogs = [
          ...emulator.outputLines,
          ...emulator.errorLines,
        ].join('\n');
        expect(
          allLogs,
          contains('sk_live_T0P_s3cReT_k3y!2026'),
          reason: 'The actual error should be logged server-side for debugging',
        );

        print(
          '✓ Verified: 500 INTERNAL returned, no password leaked to client, '
          'error logged server-side',
        );
      },
    );

    test('function execution is visible in emulator logs', () async {
      // Clear previous logs to isolate this test
      emulator.clearOutputBuffer();

      // Make a request
      print('GET ${client.baseUrl}/hello-world (verifying execution logs)');
      final response = await client.get('hello-world');

      // Wait a bit for logs to be captured
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify response
      expect(response.statusCode, equals(200));

      // Verify Firebase emulator logged the execution
      final executionLogged = emulator.verifyFunctionExecution(
        'us-central1-hello-world',
      );
      expect(
        executionLogged,
        isTrue,
        reason:
            'Should see "Beginning execution" and "Finished" in emulator logs',
      );

      print('✓ Function execution verified in emulator logs');
    });
  });
}
