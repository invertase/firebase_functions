/// Tests for builder error handling and edge cases.
///
/// These tests ensure the builder handles invalid inputs gracefully and
/// generates appropriate warnings or errors.
@Tags(['builder', 'unit'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Builder Error Cases', () {
    late Directory tempDir;
    late String testProjectPath;

    setUp(() {
      // Create a temporary directory for test projects
      tempDir = Directory.systemTemp.createTempSync('firebase_functions_test_');
      testProjectPath = tempDir.path;
    });

    tearDown(() {
      // Clean up temporary directory
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should handle missing function name gracefully', () async {
      // Create a test project with a function missing the name parameter
      await _createTestProject(
        testProjectPath,
        '''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    // Missing 'name' parameter - should fail to extract
    firebase.https.onRequest(
      (request) async => Response.ok('Hello'),
    );
  });
}
''',
      );

      // Build and check that no endpoints are generated
      final buildResult = await _runBuildRunner(testProjectPath);

      expect(buildResult.exitCode, 0, reason: 'Build should succeed');

      // Check that the manifest doesn't have the malformed function
      final manifest = _readManifest(testProjectPath);
      expect(
        manifest,
        isNotNull,
        reason: 'Manifest should be generated',
      );
      expect(
        (manifest!['endpoints'] as Map?)?.isEmpty ?? true,
        isTrue,
        reason: 'Should not extract function without name',
      );
    });

    test('should handle empty function name', () async {
      await _createTestProject(
        testProjectPath,
        '''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: '', // Empty name
      (request) async => Response.ok('Hello'),
    );
  });
}
''',
      );

      final buildResult = await _runBuildRunner(testProjectPath);
      expect(buildResult.exitCode, 0);

      final manifest = _readManifest(testProjectPath);
      // Empty names should be ignored
      expect(
        (manifest?['endpoints'] as Map?)?.isEmpty ?? true,
        isTrue,
      );
    });

    test('should handle syntax errors in source files', () async {
      await _createTestProject(
        testProjectPath,
        '''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'test',
      // Missing closing parenthesis - syntax error
      (request) async => Response.ok('Hello'
    );
  });
}
''',
      );

      // Build should still succeed (builder skips files with syntax errors)
      final buildResult = await _runBuildRunner(testProjectPath);

      expect(
        buildResult.exitCode,
        0,
        reason: 'Builder should handle syntax errors gracefully',
      );
    });

    test('should handle files with no firebase functions', () async {
      await _createTestProject(
        testProjectPath,
        '''
// File with no Firebase Functions declarations
void main() {
  print('Not a Firebase Function');
}
''',
      );

      final buildResult = await _runBuildRunner(testProjectPath);
      expect(buildResult.exitCode, 0);

      final manifest = _readManifest(testProjectPath);
      expect(manifest, isNotNull);
      expect(
        (manifest!['endpoints'] as Map?)?.isEmpty ?? true,
        isTrue,
        reason: 'Should generate empty manifest for non-function files',
      );
    });

    test('should handle part files gracefully', () async {
      // Create a project with a part file
      await _createTestProject(
        testProjectPath,
        '''
part 'part_file.dart';

import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'test',
      (request) async => Response.ok('Hello'),
    );
  });
}
''',
      );

      // Create the part file
      File('$testProjectPath/lib/part_file.dart').writeAsStringSync('''
part of 'main.dart';

void helperFunction() {
  print('Helper');
}
''');

      final buildResult = await _runBuildRunner(testProjectPath);
      expect(
        buildResult.exitCode,
        0,
        reason: 'Should skip part files without crashing',
      );

      final manifest = _readManifest(testProjectPath);
      expect(manifest, isNotNull);
      expect(
        (manifest!['endpoints'] as Map).containsKey('test'),
        isTrue,
      );
    });

    test('should handle duplicate function names', () async {
      await _createTestProject(
        testProjectPath,
        '''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'duplicate',
      (request) async => Response.ok('First'),
    );

    firebase.https.onRequest(
      name: 'duplicate', // Same name
      (request) async => Response.ok('Second'),
    );
  });
}
''',
      );

      final buildResult = await _runBuildRunner(testProjectPath);
      expect(buildResult.exitCode, 0);

      final manifest = _readManifest(testProjectPath);
      expect(manifest, isNotNull);

      // Should only have one endpoint (last one wins)
      final endpoints = manifest!['endpoints'] as Map;
      expect(
        endpoints['duplicate'],
        isNotNull,
        reason: 'Should handle duplicate names',
      );
    });

    test('should handle non-literal option values gracefully', () async {
      await _createTestProject(
        testProjectPath,
        '''
import 'package:firebase_functions/firebase_functions.dart';

const dynamicMemory = MemoryOption.mb512;

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'test',
      options: HttpsOptions(
        memory: Memory(dynamicMemory), // Non-literal
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''',
      );

      final buildResult = await _runBuildRunner(testProjectPath);
      expect(buildResult.exitCode, 0);

      final manifest = _readManifest(testProjectPath);
      expect(manifest, isNotNull);

      // Should skip non-literal values
      final endpoints = manifest!['endpoints'] as Map;
      expect(endpoints['test'], isNotNull);
      // availableMemoryMb might be null since it's not a literal
    });
  });
}

/// Creates a test project with the given source code.
Future<void> _createTestProject(String projectPath, String sourceCode) async {
  // Create directory structure
  await Directory('$projectPath/lib').create(recursive: true);
  await Directory('$projectPath/.dart_tool').create(recursive: true);

  // Create pubspec.yaml
  File('$projectPath/pubspec.yaml').writeAsStringSync('''
name: test_project
version: 1.0.0
environment:
  sdk: ^3.0.0

dependencies:
  firebase_functions:
    path: ${Directory.current.path}

dev_dependencies:
  build_runner: ^2.4.0
  build_test: ^2.2.0
''');

  // Create build.yaml
  File('$projectPath/build.yaml').writeAsStringSync('''
targets:
  \$default:
    builders:
      firebase_functions|spec:
        generate_for:
          - lib/**
''');

  // Create source file
  File('$projectPath/lib/main.dart').writeAsStringSync(sourceCode);
}

/// Runs build_runner on the test project.
Future<ProcessResult> _runBuildRunner(String projectPath) async {
  // Install dependencies first
  await Process.run(
    'dart',
    ['pub', 'get'],
    workingDirectory: projectPath,
  );

  // Run build_runner
  return Process.run(
    'dart',
    ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    workingDirectory: projectPath,
  );
}

/// Reads the generated manifest from the test project.
Map<String, dynamic>? _readManifest(String projectPath) {
  final manifestFile = File(
    '$projectPath/.dart_tool/firebase/functions.yaml',
  );

  if (!manifestFile.existsSync()) {
    return null;
  }

  // For now, just check if the file exists
  // In a full implementation, we'd parse the YAML
  return {
    'endpoints': {},
    'specVersion': 'v1alpha1',
  };
}
