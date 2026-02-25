import 'dart:io';

import 'package:test/test.dart';

// ignore: unused_import
import '../helpers/emulator.dart';

/// Scheduler test group
///
/// Note: The Firebase Emulator doesn't have a Cloud Scheduler emulator.
/// Unlike other triggers (Pub/Sub, Firestore), the emulator doesn't expose
/// scheduler functions as HTTP endpoints. Therefore, we can only test:
/// - Manifest generation (YAML output)
/// - Unit tests (direct handler invocation)
///
/// The actual function invocation tests are skipped because the emulator
/// returns 404 for scheduler function paths.
void runSchedulerTests(
  String Function() getExamplePath,
  EmulatorHelper Function() getEmulator,
  int Function() getServerPort,
) {
  group('Scheduler onSchedule', () {
    late String examplePath;

    setUpAll(() {
      examplePath = getExamplePath();
    });

    test('function is registered in manifest', () {
      // Verify the function was loaded in manifest
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
        contains('onschedule_0_0___'),
        reason: 'Manifest should contain basic scheduler function',
      );
      expect(
        manifestContent,
        contains('scheduleTrigger'),
        reason: 'Manifest should have scheduleTrigger',
      );
      expect(
        manifestContent,
        contains('schedule: 0 0 * * *'),
        reason: 'Manifest should have schedule cron expression',
      );
    });

    test('function with options is registered in manifest', () {
      final manifestPath = '$examplePath/functions.yaml';
      final manifestFile = File(manifestPath);
      final manifestContent = manifestFile.readAsStringSync();

      expect(
        manifestContent,
        contains('onschedule_0_9___15'),
        reason: 'Manifest should contain scheduler function with options',
      );
      expect(
        manifestContent,
        contains('timeZone: America/New_York'),
        reason: 'Manifest should have timeZone',
      );
      expect(
        manifestContent,
        contains('retryConfig:'),
        reason: 'Manifest should have retryConfig',
      );
      expect(
        manifestContent,
        contains('retryCount: 3'),
        reason: 'Manifest should have retryCount',
      );
    });

    test('cloudscheduler API is in requiredAPIs', () {
      final manifestPath = '$examplePath/functions.yaml';
      final manifestFile = File(manifestPath);
      final manifestContent = manifestFile.readAsStringSync();

      expect(
        manifestContent,
        contains('cloudscheduler.googleapis.com'),
        reason: 'Manifest should require cloudscheduler API',
      );
    });

    // =========================================================================
    // The following tests are skipped because the Firebase Emulator doesn't
    // support Cloud Scheduler. In production, Cloud Scheduler sends HTTP POST
    // requests to the function URL, but the emulator doesn't expose scheduler
    // functions as HTTP endpoints (returns 404).
    //
    // The scheduler functionality is verified by:
    // - Unit tests (test/unit/scheduler_namespace_test.dart)
    // - Manifest generation tests (above)
    // =========================================================================

    test(
      'function triggers when called directly',
      skip: 'Firebase Emulator does not support Cloud Scheduler triggers',
      () async {},
    );

    test(
      'function receives job name from header',
      skip: 'Firebase Emulator does not support Cloud Scheduler triggers',
      () async {},
    );

    test(
      'function receives schedule time from header',
      skip: 'Firebase Emulator does not support Cloud Scheduler triggers',
      () async {},
    );

    test(
      'function handles missing headers gracefully',
      skip: 'Firebase Emulator does not support Cloud Scheduler triggers',
      () async {},
    );

    test(
      'function with options triggers correctly',
      skip: 'Firebase Emulator does not support Cloud Scheduler triggers',
      () async {},
    );
  });
}
