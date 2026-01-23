/// Main entry point for E2E tests.
/// Sets up a single emulator instance and runs all E2E test groups.
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'helpers/auth_client.dart';
import 'helpers/database_client.dart';
import 'helpers/emulator.dart';
import 'helpers/firestore_client.dart';
import 'helpers/http_client.dart';
import 'helpers/pubsub_client.dart';
import 'tests/database_tests.dart';
import 'tests/firestore_tests.dart';
import 'tests/https_onrequest_tests.dart';
import 'tests/identity_tests.dart';
import 'tests/integration_tests.dart';
import 'tests/pubsub_tests.dart';
import 'tests/scheduler_tests.dart';

void main() {
  late EmulatorHelper emulator;
  late FunctionsHttpClient client;
  late PubSubClient pubsubClient;
  late FirestoreClient firestoreClient;
  late DatabaseClient databaseClient;
  late AuthClient authClient;

  // Debug: Show Directory.current.path at module load time
  print('DEBUG e2e_test: Directory.current.path = ${Directory.current.path}');

  final examplePath = '${Directory.current.path}/example/basic'.replaceAll(
    '/test/e2e',
    '',
  );

  print('DEBUG e2e_test: examplePath = $examplePath');

  setUpAll(() async {
    print('');
    print('========================================');
    print('Setting up Firebase Emulator for E2E tests');
    print('========================================');
    print('');

    // Build the functions first
    print('Building functions...');
    final buildResult = await Process.run('dart', [
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs',
    ], workingDirectory: examplePath);

    if (buildResult.exitCode != 0) {
      throw Exception('Failed to build functions: ${buildResult.stderr}');
    }

    print('✓ Functions built successfully');

    // Debug: Check if functions.yaml exists after build
    final functionsYamlPath = '$examplePath/.dart_tool/firebase/functions.yaml';
    final functionsYamlFile = File(functionsYamlPath);
    print(
      'DEBUG: After build, functions.yaml exists = ${functionsYamlFile.existsSync()}',
    );
    print('DEBUG: functionsYamlPath = $functionsYamlPath');

    print('');

    // Start the emulator
    emulator = EmulatorHelper(projectPath: examplePath);
    await emulator.start();

    // Create HTTP client
    client = FunctionsHttpClient(emulator.functionsUrl);

    // Create Pub/Sub client
    pubsubClient = PubSubClient(emulator.pubsubUrl, 'demo-test');

    // Create Firestore client
    firestoreClient = FirestoreClient(emulator.firestoreUrl);

    // Create Database client
    databaseClient = DatabaseClient(emulator.databaseUrl, 'demo-test');

    // Create Auth client
    authClient = AuthClient(emulator.authUrl, 'demo-test');

    // Give emulator a moment to fully initialize
    await Future<void>.delayed(const Duration(seconds: 2));
  });

  tearDownAll(() async {
    print('');
    print('========================================');
    print('Cleaning up');
    print('========================================');
    print('');

    client.close();
    pubsubClient.close();
    firestoreClient.close();
    databaseClient.close();
    authClient.close();
    await emulator.stop();
  });

  // Run all test groups (pass closures to defer value access)
  runHttpsOnRequestTests(() => client, () => emulator);
  runIntegrationTests(() => examplePath);
  runPubSubTests(() => examplePath, () => pubsubClient, () => emulator);
  runFirestoreTests(() => examplePath, () => firestoreClient, () => emulator);
  runDatabaseTests(() => examplePath, () => databaseClient, () => emulator);
  runIdentityTests(() => examplePath, () => authClient, () => emulator);
  runSchedulerTests(
    () => examplePath,
    () => emulator,
    () => emulator.functionsPort,
  );
}
