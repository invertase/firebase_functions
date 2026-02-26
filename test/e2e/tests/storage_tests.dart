import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../helpers/emulator.dart';
import '../helpers/storage_client.dart';

/// Storage trigger test group
void runStorageTests(
  String Function() getExamplePath,
  StorageClient Function() getStorageClient,
  EmulatorHelper Function() getEmulator,
) {
  group('Storage onObjectFinalized', () {
    late String examplePath;
    late StorageClient storageClient;
    late EmulatorHelper emulator;

    setUpAll(() {
      examplePath = getExamplePath();
      storageClient = getStorageClient();
      emulator = getEmulator();
    });

    test('function is registered with emulator', () {
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
        contains('on-object-finalized-demotestfirebasestorageapp'),
        reason: 'Manifest should contain Storage finalized function',
      );
      expect(
        manifestContent,
        contains('on-object-deleted-demotestfirebasestorageapp'),
        reason: 'Manifest should contain Storage deleted function',
      );
    });

    test('upload triggers onObjectFinalized', () async {
      emulator.clearOutputBuffer();

      print('Uploading test file...');

      final content = Uint8List.fromList(
        utf8.encode('Hello from E2E storage test!'),
      );
      await storageClient.uploadObject(
        'test/e2e-upload.txt',
        data: content,
        contentType: 'text/plain',
      );

      print('File uploaded, waiting for trigger...');

      // Wait for function to process the event
      await Future<void>.delayed(const Duration(seconds: 3));

      final logs = emulator.outputLines;
      final functionExecuted = logs.any(
        (line) => line.contains('Object finalized in bucket'),
      );
      expect(
        functionExecuted,
        isTrue,
        reason:
            'onObjectFinalized should be triggered on upload. '
            'Logs: ${logs.where((l) => l.contains("storage") || l.contains("Object") || l.contains("finalized")).join("\n")}',
      );

      print('✓ onObjectFinalized triggered');
    });

    test('function receives correct object metadata', () async {
      emulator.clearOutputBuffer();

      final content = Uint8List.fromList(utf8.encode('Metadata test content'));
      await storageClient.uploadObject(
        'test/metadata-test.txt',
        data: content,
        contentType: 'text/plain',
      );

      await Future<void>.delayed(const Duration(seconds: 3));

      final logs = emulator.outputLines;

      final hasName = logs.any(
        (line) => line.contains('test/metadata-test.txt'),
      );
      // The Storage emulator may report a different content type than what
      // was uploaded, so just check that a Content Type line is logged.
      final hasContentType = logs.any((line) => line.contains('Content Type:'));

      expect(hasName, isTrue, reason: 'Function should log the object name');
      expect(
        hasContentType,
        isTrue,
        reason: 'Function should log the content type',
      );

      print('✓ Object metadata received correctly');
    });

    test('delete triggers onObjectDeleted', () async {
      // First upload an object
      final content = Uint8List.fromList(utf8.encode('File to delete'));
      await storageClient.uploadObject(
        'test/to-delete.txt',
        data: content,
        contentType: 'text/plain',
      );

      // Wait for upload trigger to complete
      await Future<void>.delayed(const Duration(seconds: 2));

      // Clear logs and delete
      emulator.clearOutputBuffer();

      print('Deleting test file...');
      await storageClient.deleteObject('test/to-delete.txt');

      // Wait for function to process the event
      await Future<void>.delayed(const Duration(seconds: 3));

      final logs = emulator.outputLines;
      final functionExecuted = logs.any(
        (line) => line.contains('Object deleted in bucket'),
      );
      expect(
        functionExecuted,
        isTrue,
        reason:
            'onObjectDeleted should be triggered on delete. '
            'Logs: ${logs.where((l) => l.contains("storage") || l.contains("Object") || l.contains("deleted")).join("\n")}',
      );

      print('✓ onObjectDeleted triggered');
    });

    test('handles multiple uploads in sequence', () async {
      emulator.clearOutputBuffer();

      print('Uploading multiple files...');

      for (var i = 1; i <= 3; i++) {
        final content = Uint8List.fromList(utf8.encode('File $i content'));
        await storageClient.uploadObject(
          'test/sequential-$i.txt',
          data: content,
          contentType: 'text/plain',
        );
        print('  Uploaded file $i');
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      // Wait for all triggers
      await Future<void>.delayed(const Duration(seconds: 4));

      final logs = emulator.outputLines;
      final triggerCount = logs
          .where((line) => line.contains('Object finalized in bucket'))
          .length;

      expect(
        triggerCount,
        greaterThanOrEqualTo(3),
        reason: 'All 3 uploads should trigger onObjectFinalized',
      );

      print('✓ All sequential uploads triggered');
    });
  });

  group('Storage onObjectArchived', () {
    late String examplePath;
    late StorageClient storageClient;
    late EmulatorHelper emulator;

    setUpAll(() async {
      examplePath = getExamplePath();
      storageClient = getStorageClient();
      emulator = getEmulator();

      // Enable versioning so overwriting an object archives the old version
      try {
        await storageClient.enableVersioning();
        print('✓ Bucket versioning enabled');
      } catch (e) {
        print('Warning: Could not enable versioning: $e');
      }
    });

    test('function is registered with emulator', () {
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
        contains('on-object-archived-demotestfirebasestorageapp'),
        reason: 'Manifest should contain Storage archived function',
      );
    });

    test('overwriting object triggers onObjectArchived', () async {
      emulator.clearOutputBuffer();

      final objectPath = 'test/archive-test.txt';

      // Upload the object for the first time
      final content1 = Uint8List.fromList(
        utf8.encode('Original content for archiving'),
      );
      await storageClient.uploadObject(
        objectPath,
        data: content1,
        contentType: 'text/plain',
      );

      // Wait for finalized trigger to complete
      await Future<void>.delayed(const Duration(seconds: 2));

      // Clear logs so we only capture the archive event
      emulator.clearOutputBuffer();

      print('Overwriting object to trigger archive...');

      // Upload again with same path — archives the old version
      final content2 = Uint8List.fromList(
        utf8.encode('New content replacing archived version'),
      );
      await storageClient.uploadObject(
        objectPath,
        data: content2,
        contentType: 'text/plain',
      );

      // Wait for function to process the event
      await Future<void>.delayed(const Duration(seconds: 3));

      final logs = emulator.outputLines;
      final functionExecuted = logs.any(
        (line) => line.contains('Object archived in bucket'),
      );
      expect(
        functionExecuted,
        isTrue,
        reason:
            'onObjectArchived should be triggered when overwriting an object. '
            'Logs: ${logs.where((l) => l.contains("storage") || l.contains("Object") || l.contains("archived")).join("\n")}',
      );

      print('✓ onObjectArchived triggered');
    });

    test('function receives correct event data', () async {
      emulator.clearOutputBuffer();

      final objectPath = 'test/archive-metadata.txt';

      // Upload the initial object
      final content1 = Uint8List.fromList(
        utf8.encode('Initial content for metadata test'),
      );
      await storageClient.uploadObject(
        objectPath,
        data: content1,
        contentType: 'text/plain',
      );

      // Wait for finalized trigger
      await Future<void>.delayed(const Duration(seconds: 2));

      // Clear logs
      emulator.clearOutputBuffer();

      // Overwrite to trigger archive
      final content2 = Uint8List.fromList(
        utf8.encode('Replacement content'),
      );
      await storageClient.uploadObject(
        objectPath,
        data: content2,
        contentType: 'text/plain',
      );

      await Future<void>.delayed(const Duration(seconds: 3));

      final logs = emulator.outputLines;

      // Verify the function logged the object name
      final hasName = logs.any(
        (line) => line.contains(objectPath),
      );

      expect(
        hasName,
        isTrue,
        reason: 'Function should log the archived object name',
      );

      print('✓ Archive event data received correctly');
    });

    test('handles multiple overwrites in sequence', () async {
      emulator.clearOutputBuffer();

      final objectPath = 'test/archive-sequential.txt';

      print('Uploading initial object...');

      // Upload initial object
      final initial = Uint8List.fromList(
        utf8.encode('Initial version'),
      );
      await storageClient.uploadObject(
        objectPath,
        data: initial,
        contentType: 'text/plain',
      );

      await Future<void>.delayed(const Duration(seconds: 2));

      // Clear logs before overwrite sequence
      emulator.clearOutputBuffer();

      print('Overwriting object multiple times...');

      // Overwrite 3 times — each should archive the previous version
      for (var i = 1; i <= 3; i++) {
        final content = Uint8List.fromList(
          utf8.encode('Version $i content'),
        );
        await storageClient.uploadObject(
          objectPath,
          data: content,
          contentType: 'text/plain',
        );
        print('  Uploaded version $i');
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      // Wait for all triggers
      await Future<void>.delayed(const Duration(seconds: 4));

      final logs = emulator.outputLines;
      final archiveCount = logs
          .where((line) => line.contains('Object archived in bucket'))
          .length;

      expect(
        archiveCount,
        greaterThanOrEqualTo(3),
        reason: 'All 3 overwrites should trigger onObjectArchived',
      );

      print('✓ All sequential overwrites triggered archive events');
    });
  });
}
