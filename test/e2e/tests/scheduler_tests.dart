import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../helpers/emulator.dart';

/// Scheduler test group
///
/// Note: The Firebase Emulator doesn't have a Cloud Scheduler emulator,
/// so we test scheduler functions by directly calling their HTTP endpoints.
/// This simulates what Cloud Scheduler does in production.
void runSchedulerTests(
  String Function() getExamplePath,
  EmulatorHelper Function() getEmulator,
  int Function() getServerPort,
) {
  group('Scheduler onSchedule', () {
    late String examplePath;
    late EmulatorHelper emulator;
    late int serverPort;

    setUpAll(() {
      examplePath = getExamplePath();
      emulator = getEmulator();
      serverPort = getServerPort();
    });

    test('function is registered in manifest', () {
      // Verify the function was loaded in manifest
      final manifestPath = '$examplePath/.dart_tool/firebase/functions.yaml';
      final manifestFile = File(manifestPath);

      expect(
        manifestFile.existsSync(),
        isTrue,
        reason: 'functions.yaml should exist',
      );

      final manifestContent = manifestFile.readAsStringSync();
      expect(
        manifestContent,
        contains('onSchedule_0_0___'),
        reason: 'Manifest should contain basic scheduler function',
      );
      expect(
        manifestContent,
        contains('scheduleTrigger'),
        reason: 'Manifest should have scheduleTrigger',
      );
      expect(
        manifestContent,
        contains('schedule: "0 0 * * *"'),
        reason: 'Manifest should have schedule cron expression',
      );
    });

    test('function with options is registered in manifest', () {
      final manifestPath = '$examplePath/.dart_tool/firebase/functions.yaml';
      final manifestFile = File(manifestPath);
      final manifestContent = manifestFile.readAsStringSync();

      expect(
        manifestContent,
        contains('onSchedule_0_9___15'),
        reason: 'Manifest should contain scheduler function with options',
      );
      expect(
        manifestContent,
        contains('timeZone: "America/New_York"'),
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
      final manifestPath = '$examplePath/.dart_tool/firebase/functions.yaml';
      final manifestFile = File(manifestPath);
      final manifestContent = manifestFile.readAsStringSync();

      expect(
        manifestContent,
        contains('cloudscheduler.googleapis.com'),
        reason: 'Manifest should require cloudscheduler API',
      );
    });

    test('function triggers when called directly', () async {
      // Clear logs
      emulator.clearOutputBuffer();

      print('Calling scheduler function directly via HTTP...');

      // Call the function directly (simulating Cloud Scheduler)
      final uri = Uri.parse('http://localhost:$serverPort/onSchedule_0_0___');
      final response = await http.post(
        uri,
        headers: {
          'x-cloudscheduler-jobname':
              'projects/demo-test/locations/us-central1/jobs/test-job',
          'x-cloudscheduler-scheduletime': '2024-01-01T00:00:00Z',
        },
      );

      expect(
        response.statusCode,
        equals(200),
        reason: 'Scheduler function should return 200',
      );

      // Wait for function to complete
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Check logs for function execution
      final logs = emulator.outputLines;
      final functionExecuted = logs.any(
        (line) => line.contains('Scheduled function triggered'),
      );

      expect(
        functionExecuted,
        isTrue,
        reason: 'Scheduler function should be triggered and log execution',
      );

      print('✓ Scheduler function triggered successfully');
    });

    test('function receives job name from header', () async {
      emulator.clearOutputBuffer();

      final uri = Uri.parse('http://localhost:$serverPort/onSchedule_0_0___');
      final response = await http.post(
        uri,
        headers: {
          'x-cloudscheduler-jobname': 'projects/demo-test/jobs/my-daily-job',
          'x-cloudscheduler-scheduletime': '2024-06-15T12:00:00Z',
        },
      );

      expect(response.statusCode, equals(200));

      await Future<void>.delayed(const Duration(milliseconds: 500));

      final logs = emulator.outputLines;
      final hasJobName = logs.any(
        (line) => line.contains('projects/demo-test/jobs/my-daily-job'),
      );

      expect(
        hasJobName,
        isTrue,
        reason: 'Function should log the job name from headers',
      );

      print('✓ Job name received correctly');
    });

    test('function receives schedule time from header', () async {
      emulator.clearOutputBuffer();

      final uri = Uri.parse('http://localhost:$serverPort/onSchedule_0_0___');
      final response = await http.post(
        uri,
        headers: {
          'x-cloudscheduler-jobname': 'test-job',
          'x-cloudscheduler-scheduletime': '2024-12-25T08:30:00Z',
        },
      );

      expect(response.statusCode, equals(200));

      await Future<void>.delayed(const Duration(milliseconds: 500));

      final logs = emulator.outputLines;
      final hasScheduleTime = logs.any(
        (line) => line.contains('2024-12-25T08:30:00Z'),
      );

      expect(
        hasScheduleTime,
        isTrue,
        reason: 'Function should log the schedule time from headers',
      );

      print('✓ Schedule time received correctly');
    });

    test('function handles missing headers gracefully', () async {
      emulator.clearOutputBuffer();

      // Call without Cloud Scheduler headers (manual invocation)
      final uri = Uri.parse('http://localhost:$serverPort/onSchedule_0_0___');
      final response = await http.post(uri);

      expect(
        response.statusCode,
        equals(200),
        reason: 'Function should handle manual invocation without headers',
      );

      print('✓ Manual invocation handled correctly');
    });

    test('function with options triggers correctly', () async {
      emulator.clearOutputBuffer();

      final uri = Uri.parse('http://localhost:$serverPort/onSchedule_0_9___15');
      final response = await http.post(
        uri,
        headers: {
          'x-cloudscheduler-jobname': 'test-morning-job',
          'x-cloudscheduler-scheduletime': '2024-01-15T09:00:00-05:00',
        },
      );

      expect(
        response.statusCode,
        equals(200),
        reason: 'Scheduler function with options should return 200',
      );

      await Future<void>.delayed(const Duration(milliseconds: 500));

      final logs = emulator.outputLines;
      final functionExecuted = logs.any(
        (line) => line.contains('Weekday morning report'),
      );

      expect(
        functionExecuted,
        isTrue,
        reason: 'Scheduler function with options should be triggered',
      );

      print('✓ Scheduler function with options triggered successfully');
    });
  });
}
