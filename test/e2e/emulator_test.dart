@Tags(['e2e', 'emulator'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'helpers/emulator.dart';
import 'helpers/http_client.dart';

/// End-to-end tests with Firebase Functions Emulator.
///
/// These tests require:
/// - Firebase CLI installed
/// - Dart functions built (dart run build_runner build)
/// - No other service running on ports 5001, 8085
///
/// Run with: dart test --tags=e2e test/e2e/
void main() {
  late EmulatorHelper emulator;
  late FunctionsHttpClient client;

  // Path to the example project with functions
  final examplePath = Directory.current.path.endsWith('firebase-functions-dart')
      ? '${Directory.current.path}/example/basic'
      : 'example/basic';

  setUpAll(() async {
    print('\n========================================');
    print('Setting up Firebase Emulator for E2E tests');
    print('========================================\n');

    // Ensure functions are built
    print('Building functions...');
    final buildResult = await Process.run(
      'dart',
      ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
      workingDirectory: examplePath,
    );

    if (buildResult.exitCode != 0) {
      print('Build stdout: ${buildResult.stdout}');
      print('Build stderr: ${buildResult.stderr}');
      throw Exception('Failed to build functions');
    }

    print('✓ Functions built successfully\n');

    // Start emulator
    emulator = EmulatorHelper(projectPath: examplePath);
    await emulator.start();

    // Create HTTP client
    client = FunctionsHttpClient(emulator.functionsUrl);

    // Give emulator a moment to fully initialize
    await Future<void>.delayed(const Duration(seconds: 2));
  });

  tearDownAll(() async {
    print('\n========================================');
    print('Cleaning up');
    print('========================================\n');

    client.close();
    await emulator.stop();
  });

  group('HTTPS Functions (onRequest)', () {
    test('helloWorld returns expected response', () async {
      final response = await client.get('helloWorld');

      expect(response.statusCode, equals(200));
      expect(response.body, contains('Hello from Dart Functions!'));
    });

    test('helloWorld has correct content type', () async {
      final response = await client.get('helloWorld');

      expect(
        response.headers['content-type'],
        contains('text/plain'),
      );
    });
  });

  group('Callable Functions (onCall)', () {
    test('greet returns greeting with name', () async {
      final response = await client.call(
        'greet',
        data: {'name': 'Alice'},
      );

      expect(response.statusCode, equals(200));

      final result = client.parseCallableResponse(response);

      expect(result, isA<Map<String, dynamic>>());
      expect(result['message'], equals('Hello Alice!'));
    });

    test('greet uses default name when not provided', () async {
      final response = await client.call('greet');

      expect(response.statusCode, equals(200));

      final result = client.parseCallableResponse(response);

      expect(result['message'], equals('Hello World!'));
    });

    test('greet returns valid JSON structure', () async {
      final response = await client.call(
        'greet',
        data: {'name': 'Bob'},
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Callable functions wrap result
      expect(json, containsPair('result', isA<Map<String, dynamic>>()));

      final result = json['result'] as Map<String, dynamic>;
      expect(result, containsPair('message', isA<String>()));
    });
  });

  group('Streaming Callable Functions', () {
    test('streamNumbers returns completion message', () async {
      final response = await client.call('streamNumbers');

      expect(response.statusCode, equals(200));

      final result = client.parseCallableResponse(response);

      expect(result, isA<Map<String, dynamic>>());
      expect(result['message'], contains('streaming'));
    });

    // TODO: Test actual streaming when SSE is supported in emulator
    // The emulator may not fully support streaming yet, but the function
    // should at least return a valid response
  });

  group('Error Handling', () {
    test('calling non-existent function returns 404', () async {
      final response = await client.get('nonExistentFunction');

      expect(response.statusCode, equals(404));
    });

    test('callable function with invalid data structure', () async {
      // Send malformed request
      final response = await client.post(
        'greet',
        body: {'invalidField': 'test'},
      );

      // Should still work (function handles missing data field)
      expect(response.statusCode, equals(200));
    });
  });

  group('HTTP Methods', () {
    test('onRequest accepts GET requests', () async {
      final response = await client.get('helloWorld');
      expect(response.statusCode, equals(200));
    });

    test('onRequest accepts POST requests', () async {
      final response = await client.post('helloWorld');
      expect(response.statusCode, equals(200));
    });

    test('callable functions require POST', () async {
      // Try GET on a callable function (should fail or redirect)
      final response = await client.get('greet');

      // Emulator behavior may vary, but it should handle this
      // Either 404, 405 Method Not Allowed, or redirect
      expect(
        [200, 404, 405].contains(response.statusCode),
        isTrue,
        reason: 'Expected 200 (if routed), 404, or 405',
      );
    });
  });

  group('Concurrency', () {
    test('handles multiple concurrent requests', () async {
      final futures = List.generate(
        10,
        (i) => client.call('greet', data: {'name': 'User$i'}),
      );

      final responses = await Future.wait(futures);

      // All should succeed
      for (var i = 0; i < responses.length; i++) {
        expect(responses[i].statusCode, equals(200));
        final result = client.parseCallableResponse(responses[i]);
        expect(result['message'], equals('Hello User$i!'));
      }
    });
  });

  group('Integration', () {
    test('all functions are discoverable', () async {
      // Try to call each function to verify it's deployed
      final functions = [
        'helloWorld',
        'greet',
        'streamNumbers',
        // Note: Pub/Sub functions aren't HTTP-accessible directly
      ];

      for (final functionName in functions) {
        final response = await client.get(functionName);

        // Should be accessible (200) or method not allowed (405) for callables
        expect(
          [200, 405].contains(response.statusCode),
          isTrue,
          reason: 'Function $functionName should be deployed',
        );
      }
    });

    test('functions.yaml was generated correctly', () async {
      final manifestFile = File('$examplePath/.dart_tool/firebase/functions.yaml');

      expect(manifestFile.existsSync(), isTrue);

      final content = await manifestFile.readAsString();

      // Should contain all our functions
      expect(content, contains('helloWorld'));
      expect(content, contains('greet'));
      expect(content, contains('streamNumbers'));
      expect(content, contains('onMessagePublished_my_topic'));

      // Should have correct structure
      expect(content, contains('specVersion:'));
      expect(content, contains('endpoints:'));
      expect(content, contains('httpsTrigger'));
      expect(content, contains('callableTrigger'));
      expect(content, contains('eventTrigger'));
    });
  });
}
