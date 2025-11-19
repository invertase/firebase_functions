/// Snapshot test comparing Dart-generated manifest with Node.js reference.
///
/// This test ensures that the Dart builder generates manifests compatible
/// with the Node.js Firebase Functions SDK.
@Tags(['snapshot'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Manifest Snapshot Tests', () {
    late Map<String, dynamic> dartManifest;
    late Map<String, dynamic> nodejsManifest;

    setUpAll(() async {
      // Generate the manifest file by running build_runner
      print('Generating Dart manifest via build_runner...');
      final buildResult = await Process.run(
        'dart',
        ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
        workingDirectory: 'example/basic',
      );

      if (buildResult.exitCode != 0) {
        throw Exception(
          'build_runner failed: ${buildResult.stderr}\n${buildResult.stdout}',
        );
      }

      // Read Dart-generated YAML
      final dartYaml = File(
        'example/basic/.dart_tool/firebase/functions.yaml',
      ).readAsStringSync();
      final dartParsed = loadYaml(dartYaml) as Map;
      dartManifest = jsonDecode(jsonEncode(dartParsed)) as Map<String, dynamic>;

      // Read Node.js reference JSON
      final nodejsJson = File(
        'example/nodejs_reference/nodejs_manifest.json',
      ).readAsStringSync();
      nodejsManifest = jsonDecode(nodejsJson) as Map<String, dynamic>;
    });

    test('should have same specVersion', () {
      expect(
        dartManifest['specVersion'],
        equals(nodejsManifest['specVersion']),
      );
      expect(dartManifest['specVersion'], equals('v1alpha1'));
    });

    test('should discover same number of endpoints', () {
      final dartEndpoints = dartManifest['endpoints'] as Map;
      final nodejsEndpoints = nodejsManifest['endpoints'] as Map;

      expect(
        dartEndpoints.keys.length,
        equals(nodejsEndpoints.keys.length),
        reason: 'Should discover 2 functions (1 HTTPS + 1 Pub/Sub)',
      );
    });

    test('should have matching HTTPS onRequest function (helloWorld)', () {
      final dartFunc = _getEndpoint(dartManifest, 'helloWorld');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'helloWorld');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('helloWorld'));
      expect(dartFunc['platform'], equals('gcfv2'));
      expect(dartFunc['httpsTrigger'], isNotNull);
    });

    test('should have Pub/Sub function with correct naming', () {
      // Dart should sanitize topic name (remove hyphens) for function name
      final dartFuncName = 'onMessagePublished_mytopic';
      final dartFunc = _getEndpoint(dartManifest, dartFuncName);

      // Node.js uses same format
      final nodejsFuncName = 'onMessagePublished_mytopic';
      final nodejsFunc = _getEndpoint(nodejsManifest, nodejsFuncName);

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      // Both should have eventTrigger
      expect(dartFunc!['eventTrigger'], isNotNull);
      expect(nodejsFunc!['eventTrigger'], isNotNull);
    });

    test('should use eventFilters format for Pub/Sub', () {
      final dartFunc =
          _getEndpoint(dartManifest, 'onMessagePublished_mytopic')!;
      final nodejsFunc =
          _getEndpoint(nodejsManifest, 'onMessagePublished_mytopic')!;

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc['eventTrigger'] as Map;

      // Check event type
      expect(
        dartTrigger['eventType'],
        equals('google.cloud.pubsub.topic.v1.messagePublished'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.cloud.pubsub.topic.v1.messagePublished'),
      );

      // Check eventFilters structure (Node.js v2 format)
      expect(dartTrigger['eventFilters'], isNotNull);
      expect(nodejsTrigger['eventFilters'], isNotNull);

      final dartFilters = dartTrigger['eventFilters'] as Map;
      final nodejsFilters = nodejsTrigger['eventFilters'] as Map;

      expect(dartFilters['topic'], equals('my-topic'));
      expect(nodejsFilters['topic'], equals('my-topic'));

      // Check retry field
      expect(dartTrigger['retry'], equals(false));
      expect(nodejsTrigger['retry'], equals(false));
    });

    test('should have platform set to gcfv2', () {
      final dartEndpoints = dartManifest['endpoints'] as Map;
      final nodejsEndpoints = nodejsManifest['endpoints'] as Map;

      for (final endpoint in dartEndpoints.values) {
        expect((endpoint as Map)['platform'], equals('gcfv2'));
      }

      for (final endpoint in nodejsEndpoints.values) {
        expect((endpoint as Map)['platform'], equals('gcfv2'));
      }
    });

    test('snapshot comparison report', () {
      print('\n========== MANIFEST COMPARISON REPORT ==========\n');

      print('Dart Manifest:');
      print(
        '  - Endpoints: ${(dartManifest['endpoints'] as Map).keys.join(', ')}',
      );
      print('  - Spec Version: ${dartManifest['specVersion']}');
      print('  - Required APIs: ${dartManifest['requiredAPIs']}\n');

      print('Node.js Manifest:');
      print(
        '  - Endpoints: ${(nodejsManifest['endpoints'] as Map).keys.join(', ')}',
      );
      print('  - Spec Version: ${nodejsManifest['specVersion']}');
      print('  - Required APIs: ${nodejsManifest['requiredAPIs']}\n');

      _printDifferences(dartManifest, nodejsManifest);

      print('\n==============================================\n');
    });
  });
}

/// Gets an endpoint from the manifest.
Map<String, dynamic>? _getEndpoint(Map<String, dynamic> manifest, String name) {
  final endpoints = manifest['endpoints'] as Map?;
  return endpoints?[name] as Map<String, dynamic>?;
}

/// Prints structural differences between manifests.
void _printDifferences(
  Map<String, dynamic> dartManifest,
  Map<String, dynamic> nodejsManifest,
) {
  print('Key Differences:');

  // Compare top-level fields
  final dartKeys = dartManifest.keys.toSet();
  final nodejsKeys = nodejsManifest.keys.toSet();

  final onlyInDart = dartKeys.difference(nodejsKeys);
  final onlyInNodejs = nodejsKeys.difference(dartKeys);

  if (onlyInDart.isNotEmpty) {
    print('  ✓ Fields only in Dart: ${onlyInDart.join(', ')}');
  }
  if (onlyInNodejs.isNotEmpty) {
    print('  ℹ Fields only in Node.js: ${onlyInNodejs.join(', ')}');
  }

  // Compare endpoint structures
  final dartEndpoints = dartManifest['endpoints'] as Map;
  final nodejsEndpoints = nodejsManifest['endpoints'] as Map;

  print('\nEndpoint Structure Differences:');

  // Sample one endpoint from each
  final dartSample = dartEndpoints.values.first as Map;
  final nodejsSample = nodejsEndpoints.values.first as Map;

  final dartEndpointKeys = dartSample.keys.toSet();
  final nodejsEndpointKeys = nodejsSample.keys.toSet();

  final onlyInDartEndpoint = dartEndpointKeys.difference(nodejsEndpointKeys);
  final onlyInNodejsEndpoint = nodejsEndpointKeys.difference(dartEndpointKeys);

  if (onlyInDartEndpoint.isNotEmpty) {
    print(
      '  ✓ Fields only in Dart endpoints: ${onlyInDartEndpoint.join(', ')}',
    );
  }
  if (onlyInNodejsEndpoint.isNotEmpty) {
    print(
      '  ℹ Fields only in Node.js endpoints: ${onlyInNodejsEndpoint.join(', ')}',
    );
  }

  // Check for null vs omitted fields
  var nodejsNullCount = 0;
  for (final entry in nodejsSample.entries) {
    if (entry.value == null) nodejsNullCount++;
  }

  print(
    '\n  ℹ Node.js includes $nodejsNullCount null fields (Dart omits them)',
  );
}
