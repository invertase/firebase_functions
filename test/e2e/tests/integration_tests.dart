import 'dart:io';

import 'package:test/test.dart';

/// Integration test group
void runIntegrationTests(String Function() getExamplePath) {
  group('Integration', () {
    late String examplePath;

    setUpAll(() {
      examplePath = getExamplePath();
    });
    test('functions.yaml was generated correctly', () {
      final manifestPath = '$examplePath/functions.yaml';
      final manifestFile = File(manifestPath);

      expect(
        manifestFile.existsSync(),
        isTrue,
        reason: 'functions.yaml should exist',
      );

      final manifestContent = manifestFile.readAsStringSync();
      expect(
        manifestContent,
        contains('hello-world'),
        reason: 'Manifest should contain hello-world function',
      );
    });
  });
}
