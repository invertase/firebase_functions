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
  group('Basic Example Snapshot Tests', () {
    late Map<String, dynamic> dartManifest;
    late Map<String, dynamic> nodejsManifest;

    setUpAll(() async {
      // Generate the basic example manifest
      print('Generating basic Dart manifest via build_runner...');
      final buildResult = await Process.run('dart', [
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ], workingDirectory: 'example/basic');

      if (buildResult.exitCode != 0) {
        throw Exception(
          'build_runner failed: ${buildResult.stderr}\n${buildResult.stdout}',
        );
      }

      // Generate Node.js manifest via extract script
      print('Generating Node.js manifest via extract-manifest.js...');
      await _ensureNodeModules('example/nodejs_reference');
      final nodeResult = await Process.run('node', [
        'extract-manifest.js',
      ], workingDirectory: 'example/nodejs_reference');
      if (nodeResult.exitCode != 0) {
        throw Exception(
          'extract-manifest.js failed: ${nodeResult.stderr}\n${nodeResult.stdout}',
        );
      }

      // Read Dart-generated YAML
      final dartYaml = File(
        'example/basic/.dart_tool/firebase/functions.yaml',
      ).readAsStringSync();
      final dartParsed = loadYaml(dartYaml);
      dartManifest = _yamlToJson(dartParsed) as Map<String, dynamic>;

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

    // =========================================================================
    // Params Tests
    // =========================================================================

    test('should have matching params section', () {
      final dartParams = dartManifest['params'] as List;
      final nodejsParams = nodejsManifest['params'] as List;

      expect(
        dartParams.length,
        equals(nodejsParams.length),
        reason: 'Should have same number of params',
      );
      expect(dartParams.length, equals(3));
    });

    test('should have WELCOME_MESSAGE string param', () {
      final dartParam = _getParam(dartManifest, 'WELCOME_MESSAGE');
      final nodejsParam = _getParam(nodejsManifest, 'WELCOME_MESSAGE');

      expect(dartParam, isNotNull);
      expect(nodejsParam, isNotNull);

      expect(dartParam!['type'], equals('string'));
      expect(nodejsParam!['type'], equals('string'));

      expect(dartParam['default'], equals('Hello from Dart Functions!'));
      expect(nodejsParam['default'], equals('Hello from Dart Functions!'));

      expect(dartParam['label'], equals('Welcome Message'));
      expect(nodejsParam['label'], equals('Welcome Message'));

      expect(dartParam['description'], equals(nodejsParam['description']));
    });

    test('should have MIN_INSTANCES int param', () {
      final dartParam = _getParam(dartManifest, 'MIN_INSTANCES');
      final nodejsParam = _getParam(nodejsManifest, 'MIN_INSTANCES');

      expect(dartParam, isNotNull);
      expect(nodejsParam, isNotNull);

      expect(dartParam!['type'], equals('int'));
      expect(nodejsParam!['type'], equals('int'));

      expect(dartParam['default'], equals(0));
      expect(nodejsParam['default'], equals(0));

      expect(dartParam['label'], equals('Minimum Instances'));
      expect(nodejsParam['label'], equals('Minimum Instances'));
    });

    test('should have IS_PRODUCTION boolean param', () {
      final dartParam = _getParam(dartManifest, 'IS_PRODUCTION');
      final nodejsParam = _getParam(nodejsManifest, 'IS_PRODUCTION');

      expect(dartParam, isNotNull);
      expect(nodejsParam, isNotNull);

      expect(dartParam!['type'], equals('boolean'));
      expect(nodejsParam!['type'], equals('boolean'));

      expect(dartParam['default'], equals(false));
      expect(nodejsParam['default'], equals(false));

      expect(dartParam['description'], equals(nodejsParam['description']));
    });

    // =========================================================================
    // RequiredAPIs Tests
    // =========================================================================

    test('should have matching requiredAPIs', () {
      final dartAPIs = dartManifest['requiredAPIs'] as List;
      final nodejsAPIs = nodejsManifest['requiredAPIs'] as List;

      expect(
        dartAPIs.length,
        equals(nodejsAPIs.length),
        reason: 'Should have same number of requiredAPIs',
      );
      expect(dartAPIs.length, equals(3));

      // Check each API matches
      for (final nodejsApi in nodejsAPIs) {
        final apiName = (nodejsApi as Map)['api'] as String;
        final dartApi = dartAPIs.firstWhere(
          (api) => (api as Map)['api'] == apiName,
          orElse: () => null,
        );
        expect(
          dartApi,
          isNotNull,
          reason: 'Dart manifest should include $apiName',
        );
        expect(
          (dartApi as Map)['reason'],
          equals(nodejsApi['reason']),
          reason: 'Reason for $apiName should match',
        );
      }
    });

    test('should include cloudfunctions API in requiredAPIs', () {
      final dartAPIs = dartManifest['requiredAPIs'] as List;
      final nodejsAPIs = nodejsManifest['requiredAPIs'] as List;

      final dartApi = dartAPIs.firstWhere(
        (api) => (api as Map)['api'] == 'cloudfunctions.googleapis.com',
        orElse: () => null,
      );
      final nodejsApi = nodejsAPIs.firstWhere(
        (api) => (api as Map)['api'] == 'cloudfunctions.googleapis.com',
        orElse: () => null,
      );

      expect(dartApi, isNotNull);
      expect(nodejsApi, isNotNull);
      expect(
        (dartApi as Map)['reason'],
        equals('Required for Cloud Functions'),
      );
      expect(
        (nodejsApi as Map)['reason'],
        equals('Required for Cloud Functions'),
      );
    });

    test('should include identitytoolkit API in requiredAPIs', () {
      final dartAPIs = dartManifest['requiredAPIs'] as List;
      final nodejsAPIs = nodejsManifest['requiredAPIs'] as List;

      final dartApi = dartAPIs.firstWhere(
        (api) => (api as Map)['api'] == 'identitytoolkit.googleapis.com',
        orElse: () => null,
      );
      final nodejsApi = nodejsAPIs.firstWhere(
        (api) => (api as Map)['api'] == 'identitytoolkit.googleapis.com',
        orElse: () => null,
      );

      expect(dartApi, isNotNull);
      expect(nodejsApi, isNotNull);
      expect(
        (dartApi as Map)['reason'],
        equals('Needed for auth blocking functions'),
      );
      expect(
        (nodejsApi as Map)['reason'],
        equals('Needed for auth blocking functions'),
      );
    });

    test('should include cloudscheduler API in requiredAPIs', () {
      final dartAPIs = dartManifest['requiredAPIs'] as List;
      final nodejsAPIs = nodejsManifest['requiredAPIs'] as List;

      final dartApi = dartAPIs.firstWhere(
        (api) => (api as Map)['api'] == 'cloudscheduler.googleapis.com',
        orElse: () => null,
      );
      final nodejsApi = nodejsAPIs.firstWhere(
        (api) => (api as Map)['api'] == 'cloudscheduler.googleapis.com',
        orElse: () => null,
      );

      expect(dartApi, isNotNull);
      expect(nodejsApi, isNotNull);
      expect(
        (dartApi as Map)['reason'],
        equals('Needed for scheduled functions'),
      );
      expect(
        (nodejsApi as Map)['reason'],
        equals('Needed for scheduled functions'),
      );
    });

    // =========================================================================
    // Endpoint Count Tests
    // =========================================================================

    test('should discover correct number of endpoints', () {
      final dartEndpoints = dartManifest['endpoints'] as Map;
      final nodejsEndpoints = nodejsManifest['endpoints'] as Map;

      expect(
        dartEndpoints.keys.length,
        equals(32),
        reason:
            'Should discover 32 functions (5 Callable + 2 HTTPS + 1 Pub/Sub + 5 Firestore + 5 Database + 3 Alerts + 4 Identity + 1 Remote Config + 4 Storage + 2 Scheduler)',
      );
      expect(
        nodejsEndpoints.keys.length,
        equals(32),
        reason: 'Node.js reference should also have 32 endpoints',
      );

      // Verify both manifests have the same endpoint names
      for (final name in dartEndpoints.keys) {
        expect(
          nodejsEndpoints.containsKey(name),
          isTrue,
          reason: 'Node.js manifest should contain endpoint "$name"',
        );
      }
    });

    // =========================================================================
    // Callable Functions Tests
    // =========================================================================

    test('should have basic callable function (greet)', () {
      final dartFunc = _getEndpoint(dartManifest, 'greet');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'greet');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('server'));
      expect(nodejsFunc!['entryPoint'], equals('greet'));
      expect(dartFunc['platform'], equals('run'));
      expect(nodejsFunc['platform'], equals('gcfv2'));
      expect(dartFunc['callableTrigger'], isNotNull);
      expect(nodejsFunc['callableTrigger'], isNotNull);
      expect(dartFunc['command'], equals(['./bin/server']));
      expect(dartFunc['baseImageUri'], contains('-docker.pkg.dev/'));

      // Callable functions should NOT have httpsTrigger
      expect(dartFunc['httpsTrigger'], isNull);
      expect(nodejsFunc['httpsTrigger'], isNull);
    });

    test('should have typed callable function (greetTyped)', () {
      final dartFunc = _getEndpoint(dartManifest, 'greetTyped');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'greetTyped');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('server'));
      expect(nodejsFunc!['entryPoint'], equals('greetTyped'));
      expect(dartFunc['callableTrigger'], isNotNull);
      expect(nodejsFunc['callableTrigger'], isNotNull);
    });

    test('should have callable function with error handling (divide)', () {
      final dartFunc = _getEndpoint(dartManifest, 'divide');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'divide');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('server'));
      expect(nodejsFunc!['entryPoint'], equals('divide'));
      expect(dartFunc['callableTrigger'], isNotNull);
      expect(nodejsFunc['callableTrigger'], isNotNull);
    });

    test('should have callable function with auth (getAuthInfo)', () {
      final dartFunc = _getEndpoint(dartManifest, 'getAuthInfo');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'getAuthInfo');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('server'));
      expect(nodejsFunc!['entryPoint'], equals('getAuthInfo'));
      expect(dartFunc['callableTrigger'], isNotNull);
      expect(nodejsFunc['callableTrigger'], isNotNull);
    });

    test('should have callable function with streaming (countdown)', () {
      final dartFunc = _getEndpoint(dartManifest, 'countdown');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'countdown');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('server'));
      expect(nodejsFunc!['entryPoint'], equals('countdown'));
      expect(dartFunc['callableTrigger'], isNotNull);
      expect(nodejsFunc['callableTrigger'], isNotNull);

      // heartbeatSeconds is a runtime option, NOT in manifest
      expect(dartFunc['heartbeatSeconds'], isNull);
    });

    // =========================================================================
    // HTTPS Functions Tests
    // =========================================================================

    test('should have matching HTTPS onRequest function', () {
      final dartFunc = _getEndpoint(dartManifest, 'helloWorld');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'helloWorld');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('server'));
      expect(nodejsFunc!['entryPoint'], equals('helloWorld'));
      expect(dartFunc['platform'], equals('run'));
      expect(nodejsFunc['platform'], equals('gcfv2'));
      expect(dartFunc['httpsTrigger'], isNotNull);
      expect(nodejsFunc['httpsTrigger'], isNotNull);
    });

    test('should have correct CEL expression for minInstances param', () {
      final dartFunc = _getEndpoint(dartManifest, 'helloWorld')!;
      final nodejsFunc = _getEndpoint(nodejsManifest, 'helloWorld')!;

      expect(
        dartFunc['minInstances'],
        equals('{{ params.MIN_INSTANCES }}'),
        reason: 'Dart should output CEL expression for minInstances',
      );
      expect(
        nodejsFunc['minInstances'],
        equals('{{ params.MIN_INSTANCES }}'),
        reason: 'Node.js should output CEL expression for minInstances',
      );
    });

    test('should have correct CEL expression for conditional memory', () {
      final dartFunc = _getEndpoint(dartManifest, 'configuredEndpoint')!;
      final nodejsFunc = _getEndpoint(nodejsManifest, 'configuredEndpoint')!;

      expect(
        dartFunc['availableMemoryMb'],
        equals('{{ params.IS_PRODUCTION ? 2048 : 512 }}'),
        reason: 'Dart should output CEL ternary expression for memory',
      );
      expect(
        nodejsFunc['availableMemoryMb'],
        equals('{{ params.IS_PRODUCTION ? 2048 : 512 }}'),
        reason: 'Node.js should output CEL ternary expression for memory',
      );
    });

    // =========================================================================
    // Pub/Sub Tests
    // =========================================================================

    test('should have Pub/Sub function with correct naming', () {
      final dartFunc = _getEndpoint(dartManifest, 'onMessagePublished_mytopic');
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onMessagePublished_mytopic',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('server'));
      expect(nodejsFunc!['entryPoint'], equals('onMessagePublished_mytopic'));
      expect(dartFunc['eventTrigger'], isNotNull);
      expect(nodejsFunc['eventTrigger'], isNotNull);
    });

    test('should use eventFilters format for Pub/Sub', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onMessagePublished_mytopic',
      )!;
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onMessagePublished_mytopic',
      )!;

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.cloud.pubsub.topic.v1.messagePublished'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.cloud.pubsub.topic.v1.messagePublished'),
      );

      expect(dartTrigger['eventFilters'], isNotNull);
      expect(nodejsTrigger['eventFilters'], isNotNull);

      final dartFilters = dartTrigger['eventFilters'] as Map;
      final nodejsFilters = nodejsTrigger['eventFilters'] as Map;

      expect(dartFilters['topic'], equals('my-topic'));
      expect(nodejsFilters['topic'], equals('my-topic'));

      expect(dartTrigger['retry'], equals(false));
      expect(nodejsTrigger['retry'], equals(false));
    });

    // =========================================================================
    // Firestore Tests
    // =========================================================================

    test('should have Firestore onDocumentCreated trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onDocumentCreated_users_userId',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onDocumentCreated_users_userId',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.created'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.created'),
      );

      final dartFilters = dartTrigger['eventFilters'] as Map;
      final nodejsFilters = nodejsTrigger['eventFilters'] as Map;
      expect(dartFilters['database'], equals('(default)'));
      expect(nodejsFilters['database'], equals('(default)'));
      expect(dartFilters['namespace'], equals('(default)'));
      expect(nodejsFilters['namespace'], equals('(default)'));

      final dartPatterns = dartTrigger['eventFilterPathPatterns'] as Map;
      final nodejsPatterns = nodejsTrigger['eventFilterPathPatterns'] as Map;
      expect(dartPatterns['document'], equals('users/{userId}'));
      expect(nodejsPatterns['document'], equals('users/{userId}'));
    });

    test('should have Firestore onDocumentUpdated trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onDocumentUpdated_users_userId',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onDocumentUpdated_users_userId',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.updated'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.updated'),
      );
    });

    test('should have Firestore onDocumentDeleted trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onDocumentDeleted_users_userId',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onDocumentDeleted_users_userId',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.deleted'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.deleted'),
      );
    });

    test('should have Firestore onDocumentWritten trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onDocumentWritten_users_userId',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onDocumentWritten_users_userId',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.written'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.written'),
      );
    });

    test('should have nested collection Firestore trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onDocumentCreated_posts_postId_comments_commentId',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onDocumentCreated_posts_postId_comments_commentId',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.created'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.created'),
      );

      final dartPatterns = dartTrigger['eventFilterPathPatterns'] as Map;
      final nodejsPatterns = nodejsTrigger['eventFilterPathPatterns'] as Map;
      expect(
        dartPatterns['document'],
        equals('posts/{postId}/comments/{commentId}'),
      );
      expect(
        nodejsPatterns['document'],
        equals('posts/{postId}/comments/{commentId}'),
      );
    });

    // =========================================================================
    // Database Tests
    // =========================================================================

    test('should have Database onValueCreated trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onValueCreated_messages_messageId',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onValueCreated_messages_messageId',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.firebase.database.ref.v1.created'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.firebase.database.ref.v1.created'),
      );
    });

    test('should have Database onValueUpdated trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onValueUpdated_messages_messageId',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onValueUpdated_messages_messageId',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.firebase.database.ref.v1.updated'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.firebase.database.ref.v1.updated'),
      );
    });

    test('should have Database onValueDeleted trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onValueDeleted_messages_messageId',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onValueDeleted_messages_messageId',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.firebase.database.ref.v1.deleted'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.firebase.database.ref.v1.deleted'),
      );
    });

    test('should have Database onValueWritten trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onValueWritten_messages_messageId',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onValueWritten_messages_messageId',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.firebase.database.ref.v1.written'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.firebase.database.ref.v1.written'),
      );
    });

    test('should have nested path Database trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onValueWritten_users_userId_status',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onValueWritten_users_userId_status',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.firebase.database.ref.v1.written'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.firebase.database.ref.v1.written'),
      );

      final dartPatterns = dartTrigger['eventFilterPathPatterns'] as Map;
      final nodejsPatterns = nodejsTrigger['eventFilterPathPatterns'] as Map;

      expect(dartPatterns['ref'], equals('users/{userId}/status'));
      expect(nodejsPatterns['ref'], equals('users/{userId}/status'));
    });

    test('should use eventFilterPathPatterns format for Database', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onValueCreated_messages_messageId',
      )!;
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onValueCreated_messages_messageId',
      )!;

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc['eventTrigger'] as Map;

      // Database triggers should have empty eventFilters
      expect(dartTrigger['eventFilters'], isA<Map<dynamic, dynamic>>());
      expect(
        (dartTrigger['eventFilters'] as Map<dynamic, dynamic>).isEmpty,
        isTrue,
      );
      expect(nodejsTrigger['eventFilters'], isA<Map<dynamic, dynamic>>());
      expect(
        (nodejsTrigger['eventFilters'] as Map<dynamic, dynamic>).isEmpty,
        isTrue,
      );

      // Both ref and instance should be in eventFilterPathPatterns
      expect(dartTrigger['eventFilterPathPatterns'], isNotNull);
      expect(nodejsTrigger['eventFilterPathPatterns'], isNotNull);

      final dartPatterns = dartTrigger['eventFilterPathPatterns'] as Map;
      final nodejsPatterns = nodejsTrigger['eventFilterPathPatterns'] as Map;

      expect(dartPatterns['ref'], equals('messages/{messageId}'));
      expect(nodejsPatterns['ref'], equals('messages/{messageId}'));

      expect(dartPatterns['instance'], equals('*'));
      expect(nodejsPatterns['instance'], equals('*'));

      expect(dartTrigger['retry'], equals(false));
      expect(nodejsTrigger['retry'], equals(false));
    });

    // =========================================================================
    // Firebase Alerts Tests
    // =========================================================================

    test('should have Crashlytics newFatalIssue alert trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onAlertPublished_crashlytics_newFatalIssue',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onAlertPublished_crashlytics_newFatalIssue',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.firebase.firebasealerts.alerts.v1.published'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.firebase.firebasealerts.alerts.v1.published'),
      );

      final dartFilters = dartTrigger['eventFilters'] as Map;
      final nodejsFilters = nodejsTrigger['eventFilters'] as Map;

      expect(dartFilters['alerttype'], equals('crashlytics.newFatalIssue'));
      expect(nodejsFilters['alerttype'], equals('crashlytics.newFatalIssue'));
      expect(dartFilters['appid'], isNull); // No appId filter
      expect(nodejsFilters['appid'], isNull);

      expect(dartTrigger['retry'], equals(false));
      expect(nodejsTrigger['retry'], equals(false));
    });

    test('should have Billing planUpdate alert trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onAlertPublished_billing_planUpdate',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onAlertPublished_billing_planUpdate',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.firebase.firebasealerts.alerts.v1.published'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.firebase.firebasealerts.alerts.v1.published'),
      );

      final dartFilters = dartTrigger['eventFilters'] as Map;
      final nodejsFilters = nodejsTrigger['eventFilters'] as Map;

      expect(dartFilters['alerttype'], equals('billing.planUpdate'));
      expect(nodejsFilters['alerttype'], equals('billing.planUpdate'));
    });

    test('should have Performance threshold alert with appId filter', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onAlertPublished_performance_threshold',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onAlertPublished_performance_threshold',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.firebase.firebasealerts.alerts.v1.published'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.firebase.firebasealerts.alerts.v1.published'),
      );

      final dartFilters = dartTrigger['eventFilters'] as Map;
      final nodejsFilters = nodejsTrigger['eventFilters'] as Map;

      expect(dartFilters['alerttype'], equals('performance.threshold'));
      expect(nodejsFilters['alerttype'], equals('performance.threshold'));
      expect(dartFilters['appid'], equals('1:123456789:ios:abcdef'));
      expect(nodejsFilters['appid'], equals('1:123456789:ios:abcdef'));
    });

    // =========================================================================
    // Identity Platform (Auth Blocking) Tests
    // =========================================================================

    test('should have beforeCreate blocking trigger with token options', () {
      final dartFunc = _getEndpoint(dartManifest, 'beforeCreate');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'beforeCreate');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['blockingTrigger'], isNotNull);
      expect(nodejsFunc!['blockingTrigger'], isNotNull);

      final dartTrigger = dartFunc['blockingTrigger'] as Map;
      final nodejsTrigger = nodejsFunc['blockingTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('providers/cloud.auth/eventTypes/user.beforeCreate'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('providers/cloud.auth/eventTypes/user.beforeCreate'),
      );

      final dartOptions = dartTrigger['options'] as Map;
      final nodejsOptions = nodejsTrigger['options'] as Map;

      expect(dartOptions['idToken'], isTrue);
      expect(nodejsOptions['idToken'], isTrue);
      expect(dartOptions['accessToken'], isTrue);
      expect(nodejsOptions['accessToken'], isTrue);
    });

    test('should have beforeSignIn blocking trigger with idToken only', () {
      final dartFunc = _getEndpoint(dartManifest, 'beforeSignIn');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'beforeSignIn');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['blockingTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['blockingTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('providers/cloud.auth/eventTypes/user.beforeSignIn'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('providers/cloud.auth/eventTypes/user.beforeSignIn'),
      );

      final dartOptions = dartTrigger['options'] as Map;
      final nodejsOptions = nodejsTrigger['options'] as Map;

      expect(dartOptions['idToken'], isTrue);
      expect(nodejsOptions['idToken'], isTrue);
      expect(dartOptions.containsKey('accessToken'), isFalse);
      expect(nodejsOptions.containsKey('accessToken'), isFalse);
    });

    test('should have beforeSendEmail blocking trigger with empty options', () {
      final dartFunc = _getEndpoint(dartManifest, 'beforeSendEmail');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'beforeSendEmail');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['blockingTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['blockingTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('providers/cloud.auth/eventTypes/user.beforeSendEmail'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('providers/cloud.auth/eventTypes/user.beforeSendEmail'),
      );

      final dartOptions = dartTrigger['options'] as Map;
      final nodejsOptions = nodejsTrigger['options'] as Map;

      expect(dartOptions, isEmpty);
      expect(nodejsOptions, isEmpty);
    });

    test('should have beforeSendSms blocking trigger with empty options', () {
      final dartFunc = _getEndpoint(dartManifest, 'beforeSendSms');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'beforeSendSms');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['blockingTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['blockingTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('providers/cloud.auth/eventTypes/user.beforeSendSms'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('providers/cloud.auth/eventTypes/user.beforeSendSms'),
      );

      final dartOptions = dartTrigger['options'] as Map;
      final nodejsOptions = nodejsTrigger['options'] as Map;

      expect(dartOptions, isEmpty);
      expect(nodejsOptions, isEmpty);
    });

    // =========================================================================
    // Remote Config Tests
    // =========================================================================

    test('should have Remote Config onConfigUpdated trigger', () {
      final dartFunc = _getEndpoint(dartManifest, 'onConfigUpdated');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'onConfigUpdated');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('server'));
      expect(nodejsFunc!['entryPoint'], equals('onConfigUpdated'));
      expect(dartFunc['platform'], equals('run'));
      expect(nodejsFunc['platform'], equals('gcfv2'));
      expect(dartFunc['eventTrigger'], isNotNull);
      expect(nodejsFunc['eventTrigger'], isNotNull);
    });

    test('should have correct Remote Config event type and empty filters', () {
      final dartFunc = _getEndpoint(dartManifest, 'onConfigUpdated')!;
      final nodejsFunc = _getEndpoint(nodejsManifest, 'onConfigUpdated')!;

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.firebase.remoteconfig.remoteConfig.v1.updated'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.firebase.remoteconfig.remoteConfig.v1.updated'),
      );

      // Remote Config triggers have empty event filters
      expect(dartTrigger['eventFilters'], isA<Map<dynamic, dynamic>>());
      expect(
        (dartTrigger['eventFilters'] as Map<dynamic, dynamic>).isEmpty,
        isTrue,
      );
      expect(nodejsTrigger['eventFilters'], isA<Map<dynamic, dynamic>>());
      expect(
        (nodejsTrigger['eventFilters'] as Map<dynamic, dynamic>).isEmpty,
        isTrue,
      );

      expect(dartTrigger['retry'], equals(false));
      expect(nodejsTrigger['retry'], equals(false));
    });

    // =========================================================================
    // Cloud Storage Tests
    // =========================================================================

    test('should have Storage onObjectFinalized trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onObjectFinalized_demotestfirebasestorageapp',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onObjectFinalized_demotestfirebasestorageapp',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('server'));
      expect(
        nodejsFunc!['entryPoint'],
        equals('onObjectFinalized_demotestfirebasestorageapp'),
      );
      expect(dartFunc['platform'], equals('run'));
      expect(nodejsFunc['platform'], equals('gcfv2'));
      expect(dartFunc['eventTrigger'], isNotNull);
      expect(nodejsFunc['eventTrigger'], isNotNull);

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.cloud.storage.object.v1.finalized'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.cloud.storage.object.v1.finalized'),
      );

      final dartFilters = dartTrigger['eventFilters'] as Map;
      final nodejsFilters = nodejsTrigger['eventFilters'] as Map;

      expect(dartFilters['bucket'], equals('demo-test.firebasestorage.app'));
      expect(nodejsFilters['bucket'], equals('demo-test.firebasestorage.app'));

      expect(dartTrigger['retry'], equals(false));
      expect(nodejsTrigger['retry'], equals(false));
    });

    test('should have Storage onObjectArchived trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onObjectArchived_demotestfirebasestorageapp',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onObjectArchived_demotestfirebasestorageapp',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.cloud.storage.object.v1.archived'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.cloud.storage.object.v1.archived'),
      );

      final dartFilters = dartTrigger['eventFilters'] as Map;
      final nodejsFilters = nodejsTrigger['eventFilters'] as Map;

      expect(dartFilters['bucket'], equals('demo-test.firebasestorage.app'));
      expect(nodejsFilters['bucket'], equals('demo-test.firebasestorage.app'));
    });

    test('should have Storage onObjectDeleted trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onObjectDeleted_demotestfirebasestorageapp',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onObjectDeleted_demotestfirebasestorageapp',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.cloud.storage.object.v1.deleted'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.cloud.storage.object.v1.deleted'),
      );

      final dartFilters = dartTrigger['eventFilters'] as Map;
      final nodejsFilters = nodejsTrigger['eventFilters'] as Map;

      expect(dartFilters['bucket'], equals('demo-test.firebasestorage.app'));
      expect(nodejsFilters['bucket'], equals('demo-test.firebasestorage.app'));
    });

    test('should have Storage onObjectMetadataUpdated trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onObjectMetadataUpdated_demotestfirebasestorageapp',
      );
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onObjectMetadataUpdated_demotestfirebasestorageapp',
      );

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      final dartTrigger = dartFunc!['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc!['eventTrigger'] as Map;

      expect(
        dartTrigger['eventType'],
        equals('google.cloud.storage.object.v1.metadataUpdated'),
      );
      expect(
        nodejsTrigger['eventType'],
        equals('google.cloud.storage.object.v1.metadataUpdated'),
      );

      final dartFilters = dartTrigger['eventFilters'] as Map;
      final nodejsFilters = nodejsTrigger['eventFilters'] as Map;

      expect(dartFilters['bucket'], equals('demo-test.firebasestorage.app'));
      expect(nodejsFilters['bucket'], equals('demo-test.firebasestorage.app'));
    });

    test('should use eventFilters format for Storage', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onObjectFinalized_demotestfirebasestorageapp',
      )!;
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onObjectFinalized_demotestfirebasestorageapp',
      )!;

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      final nodejsTrigger = nodejsFunc['eventTrigger'] as Map;

      // Storage triggers should have bucket in eventFilters
      expect(dartTrigger['eventFilters'], isNotNull);
      expect(nodejsTrigger['eventFilters'], isNotNull);

      final dartFilters = dartTrigger['eventFilters'] as Map;
      final nodejsFilters = nodejsTrigger['eventFilters'] as Map;

      expect(dartFilters['bucket'], equals('demo-test.firebasestorage.app'));
      expect(nodejsFilters['bucket'], equals('demo-test.firebasestorage.app'));

      // Should not have eventFilterPathPatterns
      expect(dartTrigger['eventFilterPathPatterns'], isNull);
      expect(nodejsTrigger['eventFilterPathPatterns'], isNull);

      expect(dartTrigger['retry'], equals(false));
      expect(nodejsTrigger['retry'], equals(false));
    });

    // =========================================================================
    // Scheduler Tests
    // =========================================================================

    test('should have basic scheduled function', () {
      final dartFunc = _getEndpoint(dartManifest, 'onSchedule_0_0___');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'onSchedule_0_0___');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['scheduleTrigger'], isNotNull);
      expect(nodejsFunc!['scheduleTrigger'], isNotNull);

      final dartTrigger = dartFunc['scheduleTrigger'] as Map;
      final nodejsTrigger = nodejsFunc['scheduleTrigger'] as Map;

      expect(dartTrigger['schedule'], equals('0 0 * * *'));
      expect(nodejsTrigger['schedule'], equals('0 0 * * *'));
    });

    test('should have scheduled function with options', () {
      final dartFunc = _getEndpoint(dartManifest, 'onSchedule_0_9___15');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'onSchedule_0_9___15');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['scheduleTrigger'], isNotNull);
      expect(nodejsFunc!['scheduleTrigger'], isNotNull);

      final dartTrigger = dartFunc['scheduleTrigger'] as Map;
      final nodejsTrigger = nodejsFunc['scheduleTrigger'] as Map;

      expect(dartTrigger['schedule'], equals('0 9 * * 1-5'));
      expect(nodejsTrigger['schedule'], equals('0 9 * * 1-5'));

      expect(dartTrigger['timeZone'], equals('America/New_York'));
      expect(nodejsTrigger['timeZone'], equals('America/New_York'));

      expect(dartTrigger['retryConfig'], isNotNull);
      expect(nodejsTrigger['retryConfig'], isNotNull);

      final dartRetry = dartTrigger['retryConfig'] as Map;
      final nodejsRetry = nodejsTrigger['retryConfig'] as Map;

      expect(dartRetry['retryCount'], equals(3));
      expect(nodejsRetry['retryCount'], equals(3));
      expect(dartRetry['maxRetrySeconds'], equals(60));
      expect(nodejsRetry['maxRetrySeconds'], equals(60));
      expect(dartRetry['minBackoffSeconds'], equals(5));
      expect(nodejsRetry['minBackoffSeconds'], equals(5));
      expect(dartRetry['maxBackoffSeconds'], equals(30));
      expect(nodejsRetry['maxBackoffSeconds'], equals(30));
    });

    test('scheduled function should have memory option', () {
      final dartFunc = _getEndpoint(dartManifest, 'onSchedule_0_9___15');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'onSchedule_0_9___15');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['availableMemoryMb'], equals(256));
      expect(nodejsFunc!['availableMemoryMb'], equals(256));
    });
  });

  group('Options Example Snapshot Tests', () {
    late Map<String, dynamic> dartManifest;
    late Map<String, dynamic> nodejsManifest;

    setUpAll(() async {
      // Generate the options example manifest
      print('Generating options Dart manifest via build_runner...');
      final buildResult = await Process.run('dart', [
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ], workingDirectory: 'example/with_options');

      if (buildResult.exitCode != 0) {
        throw Exception(
          'build_runner failed: ${buildResult.stderr}\n${buildResult.stdout}',
        );
      }

      // Generate Node.js manifest via extract script
      print('Generating Node.js manifest via extract-manifest.js...');
      await _ensureNodeModules('example/with_options_nodejs');
      final nodeResult = await Process.run('node', [
        'extract-manifest.js',
      ], workingDirectory: 'example/with_options_nodejs');
      if (nodeResult.exitCode != 0) {
        throw Exception(
          'extract-manifest.js failed: ${nodeResult.stderr}\n${nodeResult.stdout}',
        );
      }

      // Read Dart-generated YAML
      final dartYaml = File(
        'example/with_options/.dart_tool/firebase/functions.yaml',
      ).readAsStringSync();
      final dartParsed = loadYaml(dartYaml);
      dartManifest = _yamlToJson(dartParsed) as Map<String, dynamic>;

      // Read Node.js reference JSON
      final nodejsJson = File(
        'example/with_options_nodejs/nodejs_manifest.json',
      ).readAsStringSync();
      nodejsManifest = jsonDecode(nodejsJson) as Map<String, dynamic>;
    });

    test('should have same specVersion', () {
      expect(dartManifest['specVersion'], equals('v1alpha1'));
      expect(nodejsManifest['specVersion'], equals('v1alpha1'));
    });

    test('should have matching requiredAPIs', () {
      final dartAPIs = dartManifest['requiredAPIs'] as List;
      final nodejsAPIs = nodejsManifest['requiredAPIs'] as List;

      expect(dartAPIs.length, equals(1));
      expect(nodejsAPIs.length, equals(1));

      expect(
        (dartAPIs[0] as Map)['api'],
        equals('cloudfunctions.googleapis.com'),
      );
      expect(
        (nodejsAPIs[0] as Map)['api'],
        equals('cloudfunctions.googleapis.com'),
      );
    });

    test('should discover 5 functions', () {
      final dartEndpoints = dartManifest['endpoints'] as Map;
      final nodejsEndpoints = nodejsManifest['endpoints'] as Map;

      expect(dartEndpoints.keys.length, equals(5));
      expect(nodejsEndpoints.keys.length, equals(5));

      // Verify both have the same endpoint names
      for (final name in dartEndpoints.keys) {
        expect(
          nodejsEndpoints.containsKey(name),
          isTrue,
          reason: 'Node.js manifest should contain endpoint "$name"',
        );
      }
    });

    test('httpsFull should have all GlobalOptions in manifest', () {
      final dartFunc = _getEndpoint(dartManifest, 'httpsFull')!;
      final nodejsFunc = _getEndpoint(nodejsManifest, 'httpsFull')!;

      // Check manifest options (not runtime-only)
      expect(dartFunc['availableMemoryMb'], equals(512));
      expect(nodejsFunc['availableMemoryMb'], equals(512));

      expect(dartFunc['cpu'], equals(1));
      expect(nodejsFunc['cpu'], equals(1));

      expect(dartFunc['timeoutSeconds'], equals(60));
      expect(nodejsFunc['timeoutSeconds'], equals(60));

      expect(dartFunc['concurrency'], equals(80));
      expect(nodejsFunc['concurrency'], equals(80));

      expect(dartFunc['minInstances'], equals(0));
      expect(nodejsFunc['minInstances'], equals(0));

      expect(dartFunc['maxInstances'], equals(10));
      expect(nodejsFunc['maxInstances'], equals(10));

      expect(dartFunc['serviceAccountEmail'], equals('test@example.com'));
      expect(nodejsFunc['serviceAccountEmail'], equals('test@example.com'));

      expect(dartFunc['ingressSettings'], equals('ALLOW_ALL'));
      expect(nodejsFunc['ingressSettings'], equals('ALLOW_ALL'));

      expect(dartFunc['omit'], equals(false));
      expect(nodejsFunc['omit'], equals(false));

      expect(dartFunc['labels']['environment'], equals('test'));
      expect(nodejsFunc['labels']['environment'], equals('test'));
    });

    test('httpsFull should have correct VPC nested structure', () {
      final dartFunc = _getEndpoint(dartManifest, 'httpsFull')!;
      final nodejsFunc = _getEndpoint(nodejsManifest, 'httpsFull')!;

      // VPC should be nested object
      expect(dartFunc['vpc'], isA<Map<dynamic, dynamic>>());
      expect(nodejsFunc['vpc'], isA<Map<dynamic, dynamic>>());

      final dartVpc = dartFunc['vpc'] as Map;
      final nodejsVpc = nodejsFunc['vpc'] as Map;

      expect(
        dartVpc['connector'],
        equals('projects/test/locations/us-central1/connectors/vpc'),
      );
      expect(
        nodejsVpc['connector'],
        equals('projects/test/locations/us-central1/connectors/vpc'),
      );

      expect(dartVpc['egressSettings'], equals('PRIVATE_RANGES_ONLY'));
      expect(nodejsVpc['egressSettings'], equals('PRIVATE_RANGES_ONLY'));
    });

    test('httpsFull should NOT have runtime-only options in manifest', () {
      final dartFunc = _getEndpoint(dartManifest, 'httpsFull')!;
      final nodejsFunc = _getEndpoint(nodejsManifest, 'httpsFull')!;

      // Runtime-only options should NOT be in manifest
      expect(dartFunc['cors'], isNull);
      expect(nodejsFunc['cors'], isNull);

      expect(dartFunc['preserveExternalChanges'], isNull);
      expect(nodejsFunc['preserveExternalChanges'], isNull);
    });

    test('callableFull should NOT have runtime-only options', () {
      final dartFunc = _getEndpoint(dartManifest, 'callableFull')!;
      final nodejsFunc = _getEndpoint(nodejsManifest, 'callableFull')!;

      // Runtime-only options should NOT be in manifest
      expect(dartFunc['enforceAppCheck'], isNull);
      expect(nodejsFunc['enforceAppCheck'], isNull);

      expect(dartFunc['consumeAppCheckToken'], isNull);
      expect(nodejsFunc['consumeAppCheckToken'], isNull);

      expect(dartFunc['heartbeatSeconds'], isNull);
      expect(nodejsFunc['heartbeatSeconds'], isNull);
    });

    test('httpsGen1 should have gcf_gen1 CPU', () {
      final dartFunc = _getEndpoint(dartManifest, 'httpsGen1')!;
      final nodejsFunc = _getEndpoint(nodejsManifest, 'httpsGen1')!;

      expect(dartFunc['cpu'], equals('gcf_gen1'));
      expect(nodejsFunc['cpu'], equals('gcf_gen1'));
    });

    test('httpsCustomInvoker should have custom invoker list', () {
      final dartFunc = _getEndpoint(dartManifest, 'httpsCustomInvoker')!;
      final nodejsFunc = _getEndpoint(nodejsManifest, 'httpsCustomInvoker')!;

      final dartInvokers = (dartFunc['httpsTrigger'] as Map)['invoker'] as List;
      final nodejsInvokers =
          (nodejsFunc['httpsTrigger'] as Map)['invoker'] as List;

      expect(dartInvokers, contains('user1@example.com'));
      expect(dartInvokers, contains('user2@example.com'));
      expect(nodejsInvokers, contains('user1@example.com'));
      expect(nodejsInvokers, contains('user2@example.com'));
    });

    test('Pub/Sub function should have options in manifest', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onMessagePublished_optionstopic',
      )!;
      final nodejsFunc = _getEndpoint(
        nodejsManifest,
        'onMessagePublished_optionstopic',
      )!;

      expect(dartFunc['availableMemoryMb'], equals(256));
      expect(nodejsFunc['availableMemoryMb'], equals(256));

      expect(dartFunc['timeoutSeconds'], equals(120));
      expect(nodejsFunc['timeoutSeconds'], equals(120));

      final dartRegion = dartFunc['region'] as List;
      final nodejsRegion = nodejsFunc['region'] as List;

      expect(dartRegion, contains('us-west1'));
      expect(nodejsRegion, contains('us-west1'));
    });
  });
}

/// Gets an endpoint from the manifest.
Map<String, dynamic>? _getEndpoint(Map<String, dynamic> manifest, String name) {
  final endpoints = manifest['endpoints'] as Map?;
  return endpoints?[name] as Map<String, dynamic>?;
}

/// Gets a param from the manifest by name.
Map<String, dynamic>? _getParam(Map<String, dynamic> manifest, String name) {
  final params = manifest['params'] as List?;
  if (params == null) return null;
  for (final param in params) {
    if ((param as Map)['name'] == name) {
      return param as Map<String, dynamic>;
    }
  }
  return null;
}

/// Ensures node_modules are installed for the given directory.
Future<void> _ensureNodeModules(String dir) async {
  if (!Directory('$dir/node_modules').existsSync()) {
    print('Installing Node.js dependencies in $dir...');
    final result = await Process.run('npm', ['ci'], workingDirectory: dir);
    if (result.exitCode != 0) {
      throw Exception(
        'npm ci failed in $dir: ${result.stderr}\n${result.stdout}',
      );
    }
  }
}

/// Converts YAML objects (YamlMap, YamlList) to JSON-compatible Dart types.
///
/// The yaml package returns YamlMap and YamlList which aren't directly
/// JSON-encodable. This function recursively converts them to regular
/// `Map<String, dynamic>` and `List<dynamic>`.
dynamic _yamlToJson(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map(
        (e) => MapEntry(e.key.toString(), _yamlToJson(e.value)),
      ),
    );
  } else if (value is List) {
    return value.map(_yamlToJson).toList();
  }
  return value;
}
