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
