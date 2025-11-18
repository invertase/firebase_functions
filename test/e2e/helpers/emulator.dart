import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Helper for managing Firebase Functions Emulator lifecycle in tests.
class EmulatorHelper {
  Process? _process;
  final String projectPath;
  final int functionsPort;
  final int pubsubPort;
  final Duration startupTimeout;

  EmulatorHelper({
    required this.projectPath,
    this.functionsPort = 5001,
    this.pubsubPort = 8085,
    this.startupTimeout = const Duration(seconds: 30),
  });

  /// Starts the Firebase emulator and waits for it to be ready.
  Future<void> start() async {
    print('Starting Firebase emulator...');

    // Check if firebase CLI is available
    final firebaseCmd = await _findFirebaseCli();
    if (firebaseCmd == null) {
      throw Exception(
        'Firebase CLI not found. Please install: npm install -g firebase-tools',
      );
    }

    print('Using Firebase CLI: $firebaseCmd');

    // Parse command into executable and base arguments
    final cmdParts = firebaseCmd.split(' ');
    final executable = cmdParts.first;
    final baseArgs = cmdParts.skip(1).toList();

    // Start the emulator
    _process = await Process.start(
      executable,
      [
        ...baseArgs,
        'emulators:start',
        '--only',
        'functions,pubsub',
        '--project',
        'demo-test',
      ],
      workingDirectory: projectPath,
      environment: {
        'FIREBASE_EMULATOR_HUB': 'true',
        ...Platform.environment,
      },
    );

    // Capture output for debugging
    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      print('[EMULATOR] $line');
    });

    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      print('[EMULATOR ERROR] $line');
    });

    // Wait for emulator to be ready
    print('Waiting for emulator to be ready...');
    await _waitForReady();
    print('✓ Emulator is ready');
  }

  /// Stops the Firebase emulator.
  Future<void> stop() async {
    if (_process == null) return;

    print('Stopping Firebase emulator...');

    // Try graceful shutdown first
    _process!.kill(ProcessSignal.sigterm);

    // Wait a bit for graceful shutdown
    await Future.delayed(const Duration(seconds: 2));

    // Force kill if still running
    if (!_process!.kill(ProcessSignal.sigkill)) {
      print('Warning: Could not kill emulator process');
    }

    _process = null;
    print('✓ Emulator stopped');
  }

  /// Waits for the emulator to be ready by polling the health endpoint.
  Future<void> _waitForReady() async {
    final client = HttpClient();
    final deadline = DateTime.now().add(startupTimeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        // Try to connect to the functions emulator
        final request = await client.getUrl(
          Uri.parse('http://localhost:$functionsPort'),
        );
        final response = await request.close();
        await response.drain();

        // If we get a response, emulator is ready
        print('Emulator responding on port $functionsPort');
        client.close();
        return;
      } catch (e) {
        // Not ready yet, wait and retry
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    client.close();
    throw TimeoutException(
      'Emulator did not start within ${startupTimeout.inSeconds} seconds',
    );
  }

  /// Finds the Firebase CLI executable.
  Future<String?> _findFirebaseCli() async {
    // First, try to find the custom firebase-tools with Dart support
    // This is in the parent directory structure: ../../firebase-tools
    final customFirebasePath = _findCustomFirebaseCli();
    if (customFirebasePath != null) {
      try {
        final result = await Process.run(
          'node',
          [customFirebasePath, '--version'],
        );
        if (result.exitCode == 0) {
          print('Using custom firebase-tools with Dart support: $customFirebasePath');
          return 'node $customFirebasePath';
        }
      } catch (e) {
        // Custom version not found or failed, try standard locations
      }
    }

    // Try common locations
    final candidates = [
      'firebase', // In PATH
      'npx firebase', // Via npx
      '/usr/local/bin/firebase',
      Platform.environment['HOME'] != null
          ? '${Platform.environment['HOME']}/.npm-global/bin/firebase'
          : null,
    ].where((c) => c != null).cast<String>();

    for (final cmd in candidates) {
      try {
        final result = await Process.run(
          cmd.split(' ').first,
          [...cmd.split(' ').skip(1), '--version'],
        );

        if (result.exitCode == 0) {
          return cmd;
        }
      } catch (e) {
        // Command not found, try next
        continue;
      }
    }

    return null;
  }

  /// Finds the custom firebase-tools CLI with Dart support.
  /// Returns the path to lib/bin/firebase.js if found.
  String? _findCustomFirebaseCli() {
    // Start from current directory and traverse up looking for firebase-tools
    var dir = Directory.current;

    for (var i = 0; i < 5; i++) {  // Only check up to 5 levels
      final firebaseToolsPath = '${dir.path}/firebase-tools/lib/bin/firebase.js';
      if (File(firebaseToolsPath).existsSync()) {
        return firebaseToolsPath;
      }

      final parentDir = dir.parent;
      if (parentDir.path == dir.path) {
        break;  // Reached root
      }
      dir = parentDir;
    }

    return null;
  }

  /// Gets the base URL for the functions emulator.
  String get functionsUrl =>
      'http://localhost:$functionsPort/demo-test/us-central1';

  /// Gets the base URL for the Pub/Sub emulator.
  String get pubsubUrl => 'http://localhost:$pubsubPort';
}
