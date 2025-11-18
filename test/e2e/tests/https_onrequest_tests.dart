import 'package:test/test.dart';

import '../helpers/http_client.dart';

/// HTTPS onRequest test group
void runHttpsOnRequestTests(FunctionsHttpClient Function() getClient) {
  group('HTTPS onRequest', () {
    late FunctionsHttpClient client;

    setUpAll(() {
      client = getClient();
    });
    test('helloWorld returns expected response', () async {
      print('GET ${client.baseUrl}/helloWorld');
      final response = await client.get('helloWorld');

      expect(response.statusCode, equals(200));
      expect(response.body, contains('Hello from Dart Functions!'));
    });

    test('helloWorld has correct content type', () async {
      print('GET ${client.baseUrl}/helloWorld');
      final response = await client.get('helloWorld');

      expect(response.statusCode, equals(200));
      expect(
        response.headers['content-type'],
        contains('text/plain'),
      );
    });

    test('helloWorld accepts GET requests', () async {
      print('GET ${client.baseUrl}/helloWorld');
      final response = await client.get('helloWorld');

      expect(response.statusCode, equals(200));
    });

    test('helloWorld accepts POST requests', () async {
      print('POST ${client.baseUrl}/helloWorld');
      final response = await client.post('helloWorld');

      expect(response.statusCode, equals(200));
    });

    test('calling non-existent function returns 404', () async {
      print('GET ${client.baseUrl}/nonExistentFunction');
      final response = await client.get('nonExistentFunction');

      expect(response.statusCode, equals(404));
    });

    test('handles multiple concurrent requests', () async {
      print('Making 10 concurrent requests...');
      final futures = <Future<void>>[];

      for (var i = 0; i < 10; i++) {
        futures.add(() async {
          final response = await client.get('helloWorld');
          expect(response.statusCode, equals(200));
          expect(response.body, contains('Hello from Dart Functions!'));
        }());
      }

      await Future.wait(futures);
    });

    test('function is discoverable via emulator', () async {
      print('GET ${client.baseUrl}/helloWorld');
      final response = await client.get('helloWorld');

      expect(
        response.statusCode,
        equals(200),
        reason: 'Function helloWorld should be deployed',
      );
    });
  });
}
