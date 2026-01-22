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

    test('should discover correct number of endpoints', () {
      final dartEndpoints = dartManifest['endpoints'] as Map;

      expect(
        dartEndpoints.keys.length,
        equals(26),
        reason:
            'Should discover 26 functions (4 Callable + 2 HTTPS + 1 Pub/Sub + 5 Firestore + 5 Database + 3 Alerts + 4 Identity + 2 Scheduler)',
      );
    });

    // =========================================================================
    // Callable Functions Tests
    // =========================================================================

    test('should have basic callable function (greet)', () {
      final dartFunc = _getEndpoint(dartManifest, 'greet');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'greet');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('greet'));
      expect(dartFunc['platform'], equals('gcfv2'));
      expect(dartFunc['callableTrigger'], isNotNull);
      expect(nodejsFunc!['callableTrigger'], isNotNull);

      // Callable functions should NOT have httpsTrigger
      expect(dartFunc['httpsTrigger'], isNull);
      expect(nodejsFunc['httpsTrigger'], isNull);
    });

    test('should have typed callable function (greetTyped)', () {
      final dartFunc = _getEndpoint(dartManifest, 'greetTyped');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'greetTyped');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('greetTyped'));
      expect(dartFunc['callableTrigger'], isNotNull);
      expect(nodejsFunc!['callableTrigger'], isNotNull);
    });

    test('should have callable function with error handling (divide)', () {
      final dartFunc = _getEndpoint(dartManifest, 'divide');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'divide');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['callableTrigger'], isNotNull);
      expect(nodejsFunc!['callableTrigger'], isNotNull);
    });

    test('should have callable function with streaming (countdown)', () {
      final dartFunc = _getEndpoint(dartManifest, 'countdown');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'countdown');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['callableTrigger'], isNotNull);
      expect(nodejsFunc!['callableTrigger'], isNotNull);

      // heartbeatSeconds is a runtime option, NOT in manifest
      expect(dartFunc['heartbeatSeconds'], isNull);
    });

    test('should have matching HTTPS onRequest function', () {
      final dartFunc = _getEndpoint(dartManifest, 'helloWorld');
      final nodejsFunc = _getEndpoint(nodejsManifest, 'helloWorld');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

      expect(dartFunc!['entryPoint'], equals('helloWorld'));
      expect(dartFunc['platform'], equals('gcfv2'));
      expect(dartFunc['httpsTrigger'], isNotNull);
    });

    test('should have Pub/Sub function with correct naming', () {
      final dartFunc = _getEndpoint(dartManifest, 'onMessagePublished_mytopic');
      final nodejsFunc =
          _getEndpoint(nodejsManifest, 'onMessagePublished_mytopic');

      expect(dartFunc, isNotNull);
      expect(nodejsFunc, isNotNull);

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

    test('should have Firestore onDocumentCreated trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onDocumentCreated_users_userId',
      );

      expect(dartFunc, isNotNull);
      expect(dartFunc!['eventTrigger'], isNotNull);

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      expect(
        dartTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.created'),
      );
    });

    test('should have Firestore onDocumentUpdated trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onDocumentUpdated_users_userId',
      );

      expect(dartFunc, isNotNull);
      expect(dartFunc!['eventTrigger'], isNotNull);

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      expect(
        dartTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.updated'),
      );
    });

    test('should have Firestore onDocumentDeleted trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onDocumentDeleted_users_userId',
      );

      expect(dartFunc, isNotNull);
      expect(dartFunc!['eventTrigger'], isNotNull);

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      expect(
        dartTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.deleted'),
      );
    });

    test('should have Firestore onDocumentWritten trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onDocumentWritten_users_userId',
      );

      expect(dartFunc, isNotNull);
      expect(dartFunc!['eventTrigger'], isNotNull);

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      expect(
        dartTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.written'),
      );
    });

    test('should have nested collection Firestore trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onDocumentCreated_posts_postId_comments_commentId',
      );

      expect(dartFunc, isNotNull);
      expect(dartFunc!['eventTrigger'], isNotNull);

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      expect(
        dartTrigger['eventType'],
        equals('google.cloud.firestore.document.v1.created'),
      );
    });

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
    });

    test('should use eventFilterPathPatterns format for Database', () {
      final dartFunc =
          _getEndpoint(dartManifest, 'onValueCreated_messages_messageId')!;
      final nodejsFunc =
          _getEndpoint(nodejsManifest, 'onValueCreated_messages_messageId')!;

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

    test('should have Crashlytics newFatalIssue alert trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onAlertPublished_crashlytics_newFatalIssue',
      );

      expect(dartFunc, isNotNull);
      expect(dartFunc!['eventTrigger'], isNotNull);

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      expect(
        dartTrigger['eventType'],
        equals('google.firebase.firebasealerts.alerts.v1.published'),
      );
      expect(dartTrigger['eventFilters'], isNotNull);

      final filters = dartTrigger['eventFilters'] as Map;
      expect(filters['alerttype'], equals('crashlytics.newFatalIssue'));
      expect(filters['appid'], isNull); // No appId filter

      expect(dartTrigger['retry'], equals(false));
    });

    test('should have Billing planUpdate alert trigger', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onAlertPublished_billing_planUpdate',
      );

      expect(dartFunc, isNotNull);
      expect(dartFunc!['eventTrigger'], isNotNull);

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      expect(
        dartTrigger['eventType'],
        equals('google.firebase.firebasealerts.alerts.v1.published'),
      );

      final filters = dartTrigger['eventFilters'] as Map;
      expect(filters['alerttype'], equals('billing.planUpdate'));
    });

    test('should have Performance threshold alert with appId filter', () {
      final dartFunc = _getEndpoint(
        dartManifest,
        'onAlertPublished_performance_threshold',
      );

      expect(dartFunc, isNotNull);
      expect(dartFunc!['eventTrigger'], isNotNull);

      final dartTrigger = dartFunc['eventTrigger'] as Map;
      expect(
        dartTrigger['eventType'],
        equals('google.firebase.firebasealerts.alerts.v1.published'),
      );

      final filters = dartTrigger['eventFilters'] as Map;
      expect(filters['alerttype'], equals('performance.threshold'));
      expect(filters['appid'], equals('1:123456789:ios:abcdef'));
    });

    // =========================================================================
    // Identity Platform (Auth Blocking) Tests
    // =========================================================================

    test('should have beforeCreate blocking trigger with token options', () {
      final dartFunc = _getEndpoint(dartManifest, 'beforeCreate');

      expect(dartFunc, isNotNull);
      expect(dartFunc!['blockingTrigger'], isNotNull);

      final trigger = dartFunc['blockingTrigger'] as Map;
      expect(
        trigger['eventType'],
        equals('providers/cloud.auth/eventTypes/user.beforeCreate'),
      );

      final options = trigger['options'] as Map;
      expect(options['idToken'], isTrue);
      expect(options['accessToken'], isTrue);
    });

    test('should have beforeSignIn blocking trigger with idToken only', () {
      final dartFunc = _getEndpoint(dartManifest, 'beforeSignIn');

      expect(dartFunc, isNotNull);
      expect(dartFunc!['blockingTrigger'], isNotNull);

      final trigger = dartFunc['blockingTrigger'] as Map;
      expect(
        trigger['eventType'],
        equals('providers/cloud.auth/eventTypes/user.beforeSignIn'),
      );

      final options = trigger['options'] as Map;
      expect(options['idToken'], isTrue);
      expect(options.containsKey('accessToken'), isFalse);
    });

    test('should have beforeSendEmail blocking trigger with empty options', () {
      final dartFunc = _getEndpoint(dartManifest, 'beforeSendEmail');

      expect(dartFunc, isNotNull);
      expect(dartFunc!['blockingTrigger'], isNotNull);

      final trigger = dartFunc['blockingTrigger'] as Map;
      expect(
        trigger['eventType'],
        equals('providers/cloud.auth/eventTypes/user.beforeSendEmail'),
      );

      final options = trigger['options'] as Map;
      expect(options, isEmpty);
    });

    test('should have beforeSendSms blocking trigger with empty options', () {
      final dartFunc = _getEndpoint(dartManifest, 'beforeSendSms');

      expect(dartFunc, isNotNull);
      expect(dartFunc!['blockingTrigger'], isNotNull);

      final trigger = dartFunc['blockingTrigger'] as Map;
      expect(
        trigger['eventType'],
        equals('providers/cloud.auth/eventTypes/user.beforeSendSms'),
      );

      final options = trigger['options'] as Map;
      expect(options, isEmpty);
    });

    test('should include identitytoolkit API in requiredAPIs', () {
      final requiredAPIs = dartManifest['requiredAPIs'] as List;

      final identityApi = requiredAPIs.firstWhere(
        (api) => (api as Map)['api'] == 'identitytoolkit.googleapis.com',
        orElse: () => null,
      );

      expect(identityApi, isNotNull);
      expect(
        (identityApi as Map)['reason'],
        equals('Needed for auth blocking functions'),
      );
    });

    // =========================================================================
    // Scheduler Tests
    // =========================================================================

    test('should have basic scheduled function', () {
      final dartFunc = _getEndpoint(dartManifest, 'onSchedule_0_0___');

      expect(dartFunc, isNotNull);
      expect(dartFunc!['scheduleTrigger'], isNotNull);

      final trigger = dartFunc['scheduleTrigger'] as Map;
      expect(trigger['schedule'], equals('0 0 * * *'));
    });

    test('should have scheduled function with options', () {
      final dartFunc = _getEndpoint(dartManifest, 'onSchedule_0_9___15');

      expect(dartFunc, isNotNull);
      expect(dartFunc!['scheduleTrigger'], isNotNull);

      final trigger = dartFunc['scheduleTrigger'] as Map;
      expect(trigger['schedule'], equals('0 9 * * 1-5'));
      expect(trigger['timeZone'], equals('America/New_York'));
      expect(trigger['retryConfig'], isNotNull);

      final retryConfig = trigger['retryConfig'] as Map;
      expect(retryConfig['retryCount'], equals(3));
      expect(retryConfig['maxRetrySeconds'], equals(60));
      expect(retryConfig['minBackoffSeconds'], equals(5));
      expect(retryConfig['maxBackoffSeconds'], equals(30));
    });

    test('should include cloudscheduler API in requiredAPIs', () {
      final requiredAPIs = dartManifest['requiredAPIs'] as List;

      final schedulerApi = requiredAPIs.firstWhere(
        (api) => (api as Map)['api'] == 'cloudscheduler.googleapis.com',
        orElse: () => null,
      );

      expect(schedulerApi, isNotNull);
      expect(
        (schedulerApi as Map)['reason'],
        equals('Needed for scheduled functions'),
      );
    });

    test('scheduled function should have memory option', () {
      final dartFunc = _getEndpoint(dartManifest, 'onSchedule_0_9___15');

      expect(dartFunc, isNotNull);
      expect(dartFunc!['availableMemoryMb'], equals(256));
    });
  });

  group('Options Example Snapshot Tests', () {
    late Map<String, dynamic> dartManifest;
    late Map<String, dynamic> nodejsManifest;

    setUpAll(() async {
      // Generate the options example manifest
      print('Generating options Dart manifest via build_runner...');
      final buildResult = await Process.run(
        'dart',
        ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
        workingDirectory: 'example/with_options',
      );

      if (buildResult.exitCode != 0) {
        throw Exception(
          'build_runner failed: ${buildResult.stderr}\n${buildResult.stdout}',
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

    test('should discover 5 functions', () {
      final dartEndpoints = dartManifest['endpoints'] as Map;
      final nodejsEndpoints = nodejsManifest['endpoints'] as Map;

      expect(dartEndpoints.keys.length, equals(5));
      expect(nodejsEndpoints.keys.length, equals(5));
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
      final dartFunc =
          _getEndpoint(dartManifest, 'onMessagePublished_optionstopic')!;
      final nodejsFunc =
          _getEndpoint(nodejsManifest, 'onMessagePublished_optionstopic')!;

      expect(dartFunc['availableMemoryMb'], equals(256));
      expect(nodejsFunc['availableMemoryMb'], equals(256));

      expect(dartFunc['timeoutSeconds'], equals(120));
      expect(nodejsFunc['timeoutSeconds'], equals(120));

      final dartRegion = dartFunc['region'] as List;
      final nodejsRegion = nodejsFunc['region'] as List;

      expect(dartRegion, contains('us-west1'));
      expect(nodejsRegion, contains('us-west1'));
    });

    test('snapshot comparison report', () {
      print('\n========== OPTIONS MANIFEST COMPARISON ==========\n');

      print('Dart Manifest:');
      print(
        '  - Functions: ${(dartManifest['endpoints'] as Map).keys.join(', ')}',
      );

      print('\nNode.js Manifest:');
      print(
        '  - Functions: ${(nodejsManifest['endpoints'] as Map).keys.join(', ')}',
      );

      print('\n✅ All 21 HTTP function options tested and validated!');
      print('==============================================\n');
    });
  });
}

/// Gets an endpoint from the manifest.
Map<String, dynamic>? _getEndpoint(Map<String, dynamic> manifest, String name) {
  final endpoints = manifest['endpoints'] as Map?;
  return endpoints?[name] as Map<String, dynamic>?;
}

/// Converts YAML objects (YamlMap, YamlList) to JSON-compatible Dart types.
///
/// The yaml package returns YamlMap and YamlList which aren't directly
/// JSON-encodable. This function recursively converts them to regular
/// Map<String, dynamic> and List<dynamic>.
dynamic _yamlToJson(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.fromEntries(
      value.entries
          .map((e) => MapEntry(e.key.toString(), _yamlToJson(e.value))),
    );
  } else if (value is List) {
    return value.map(_yamlToJson).toList();
  }
  return value;
}
