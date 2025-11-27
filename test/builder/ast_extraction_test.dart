/// Unit tests for AST extraction logic in the builder.
///
/// These tests verify that the builder correctly extracts function declarations,
/// options, and parameters from Dart source code.
@Tags(['builder', 'unit'])
library;

import 'dart:io';

import 'package:firebase_functions/builder.dart' as builder;
import 'package:test/test.dart';

void main() {
  group('AST Extraction Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ast_extraction_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('HTTPS Function Extraction', () {
      test('should extract simple onRequest function', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'simpleFunction',
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        expect(manifest['endpoints'], isA<Map>());
        expect(manifest['endpoints']['simpleFunction'], isNotNull);
        expect(
          manifest['endpoints']['simpleFunction']['httpsTrigger'],
          isNotNull,
        );
      });

      test('should extract onCall function', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onCall(
      name: 'callableFunction',
      (request, response) async {
        return CallableResult({'message': 'Hello'});
      },
    );
  });
}
''');

        expect(manifest['endpoints']['callableFunction'], isNotNull);
        expect(
          manifest['endpoints']['callableFunction']['callableTrigger'],
          isNotNull,
        );
      });

      test('should extract function with memory option', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'functionWithMemory',
      options: const HttpsOptions(
        memory: Memory(MemoryOption.gb1),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['functionWithMemory'];
        expect(func, isNotNull);
        expect(func['availableMemoryMb'], equals(1024));
      });

      test('should extract function with CPU option', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'functionWithCpu',
      options: const HttpsOptions(
        cpu: Cpu(2),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['functionWithCpu'];
        expect(func, isNotNull);
        expect(func['cpu'], equals(2));
      });

      test('should extract GCF Gen1 CPU option', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'gen1Function',
      options: const HttpsOptions(
        cpu: Cpu.gcfGen1(),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['gen1Function'];
        expect(func, isNotNull);
        expect(func['cpu'], equals('gcf_gen1'));
      });

      test('should extract region option', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'regionalFunction',
      options: const HttpsOptions(
        region: Region(SupportedRegion.usEast1),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['regionalFunction'];
        expect(func, isNotNull);
        expect(func['region'], contains('us-east1'));
      });

      test('should extract timeout option', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'timeoutFunction',
      options: const HttpsOptions(
        timeoutSeconds: TimeoutSeconds(300),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['timeoutFunction'];
        expect(func, isNotNull);
        expect(func['timeoutSeconds'], equals(300));
      });

      test('should extract min/max instances', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'scaledFunction',
      options: const HttpsOptions(
        minInstances: Instances(1),
        maxInstances: Instances(100),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['scaledFunction'];
        expect(func, isNotNull);
        expect(func['minInstances'], equals(1));
        expect(func['maxInstances'], equals(100));
      });

      test('should extract concurrency option', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'concurrentFunction',
      options: const HttpsOptions(
        concurrency: Concurrency(80),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['concurrentFunction'];
        expect(func, isNotNull);
        expect(func['concurrency'], equals(80));
      });

      test('should extract service account option', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'serviceAccountFunction',
      options: const HttpsOptions(
        serviceAccount: ServiceAccount('test@example.com'),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['serviceAccountFunction'];
        expect(func, isNotNull);
        expect(func['serviceAccountEmail'], equals('test@example.com'));
      });

      test('should extract VPC options with nested structure', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'vpcFunction',
      options: const HttpsOptions(
        vpcConnector: VpcConnector('projects/test/connectors/vpc'),
        vpcConnectorEgressSettings: VpcConnectorEgressSettings(
          VpcEgressSetting.privateRangesOnly,
        ),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['vpcFunction'];
        expect(func, isNotNull);
        expect(func['vpc'], isA<Map>());
        expect(func['vpc']['connector'], equals('projects/test/connectors/vpc'));
        expect(func['vpc']['egressSettings'], equals('PRIVATE_RANGES_ONLY'));
      });

      test('should extract ingress settings', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'ingressFunction',
      options: const HttpsOptions(
        ingressSettings: Ingress(IngressSetting.allowInternalOnly),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['ingressFunction'];
        expect(func, isNotNull);
        expect(func['ingressSettings'], equals('ALLOW_INTERNAL_ONLY'));
      });

      test('should extract invoker options', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'publicFunction',
      options: const HttpsOptions(
        invoker: Invoker.public(),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['publicFunction'];
        expect(func, isNotNull);
        expect(func['httpsTrigger']['invoker'], contains('public'));
      });

      test('should extract custom invoker list', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'customInvokerFunction',
      options: const HttpsOptions(
        invoker: Invoker(['user1@example.com', 'user2@example.com']),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['customInvokerFunction'];
        expect(func, isNotNull);
        expect(func['httpsTrigger']['invoker'], contains('user1@example.com'));
        expect(func['httpsTrigger']['invoker'], contains('user2@example.com'));
      });

      test('should extract labels', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'labeledFunction',
      options: const HttpsOptions(
        labels: {'environment': 'test', 'team': 'backend'},
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['labeledFunction'];
        expect(func, isNotNull);
        expect(func['labels']['environment'], equals('test'));
        expect(func['labels']['team'], equals('backend'));
      });

      test('should NOT extract runtime-only options', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'runtimeOnlyFunction',
      options: const HttpsOptions(
        cors: Cors(['https://example.com']),
        preserveExternalChanges: PreserveExternalChanges(true),
      ),
      (request) async => Response.ok('Hello'),
    );
  });
}
''');

        final func = manifest['endpoints']['runtimeOnlyFunction'];
        expect(func, isNotNull);
        // Runtime-only options should NOT be in manifest
        expect(func['cors'], isNull);
        expect(func['preserveExternalChanges'], isNull);
      });
    });

    group('Pub/Sub Function Extraction', () {
      test('should extract Pub/Sub function', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.pubsub.onMessagePublished(
      topic: 'test-topic',
      (event) async {
        print('Message received');
      },
    );
  });
}
''');

        expect(manifest['endpoints']['onMessagePublished_testtopic'], isNotNull);
        final func = manifest['endpoints']['onMessagePublished_testtopic'];
        expect(func['eventTrigger'], isNotNull);
        expect(
          func['eventTrigger']['eventType'],
          equals('google.cloud.pubsub.topic.v1.messagePublished'),
        );
      });

      test('should sanitize topic name correctly', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.pubsub.onMessagePublished(
      topic: 'my-topic-with-dashes',
      (event) async {
        print('Message received');
      },
    );
  });
}
''');

        // Dashes should be removed from function name
        expect(
          manifest['endpoints']['onMessagePublished_mytopicwithdashes'],
          isNotNull,
        );
        // But kept in eventFilters
        final func = manifest['endpoints']['onMessagePublished_mytopicwithdashes'];
        expect(
          func['eventTrigger']['eventFilters']['topic'],
          equals('my-topic-with-dashes'),
        );
      });

      test('should extract Pub/Sub function with options', () async {
        final manifest = await _buildAndReadManifest('''
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.pubsub.onMessagePublished(
      topic: 'options-topic',
      options: const PubSubOptions(
        memory: Memory(MemoryOption.mb256),
        timeoutSeconds: TimeoutSeconds(120),
      ),
      (event) async {
        print('Message received');
      },
    );
  });
}
''');

        final func = manifest['endpoints']['onMessagePublished_optionstopic'];
        expect(func, isNotNull);
        expect(func['availableMemoryMb'], equals(256));
        expect(func['timeoutSeconds'], equals(120));
      });
    });
  });
}

/// Helper to build a test project and read the generated manifest.
Future<Map<String, dynamic>> _buildAndReadManifest(String sourceCode) async {
  // This is a placeholder implementation
  // In a full implementation, we would:
  // 1. Create a temporary project
  // 2. Run build_runner
  // 3. Parse the generated YAML
  // 4. Return the parsed manifest

  // For now, return a mock structure
  return {
    'specVersion': 'v1alpha1',
    'endpoints': {},
  };
}
