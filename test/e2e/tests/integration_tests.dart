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
      final manifestPath = '$examplePath/.dart_tool/firebase/functions.yaml';
      final manifestFile = File(manifestPath);

      // Debug output
      print('DEBUG: examplePath = $examplePath');
      print('DEBUG: manifestPath = $manifestPath');
      print('DEBUG: Directory.current.path = ${Directory.current.path}');
      print('DEBUG: manifestFile.existsSync() = ${manifestFile.existsSync()}');

      // Check if .dart_tool directory exists
      final dartToolDir = Directory('$examplePath/.dart_tool');
      print('DEBUG: .dart_tool exists = ${dartToolDir.existsSync()}');

      if (dartToolDir.existsSync()) {
        final firebaseDir = Directory('$examplePath/.dart_tool/firebase');
        print('DEBUG: .dart_tool/firebase exists = ${firebaseDir.existsSync()}');

        if (firebaseDir.existsSync()) {
          print('DEBUG: Contents of .dart_tool/firebase:');
          for (final entity in firebaseDir.listSync()) {
            print('DEBUG:   ${entity.path}');
          }
        }
      }

      expect(
        manifestFile.existsSync(),
        isTrue,
        reason: 'functions.yaml should exist',
      );

      final manifestContent = manifestFile.readAsStringSync();
      expect(
        manifestContent,
        contains('helloWorld'),
        reason: 'Manifest should contain helloWorld function',
      );
    });
  });
}
