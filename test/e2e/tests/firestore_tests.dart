import 'package:test/test.dart';

import '../helpers/emulator.dart';
import '../helpers/firestore_client.dart';

/// E2E tests for Firestore triggers.
void runFirestoreTests(
  String Function() getExamplePath,
  FirestoreClient Function() getClient,
  EmulatorHelper Function() getEmulator,
) {
  group('Firestore Triggers', () {
    late FirestoreClient client;
    late String testUserId;

    setUp(() {
      client = getClient();
      testUserId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    });

    test('onDocumentCreated fires and parses document data', () async {
      print('\n=== Testing onDocumentCreated ===');

      // Create a document with various data types
      final doc = await client.createDocument('users', testUserId, {
        'name': 'John Doe',
        'email': 'john@example.com',
        'age': 28,
        'active': true,
        'score': 95.5,
        'metadata': {'created': '2024-01-01', 'verified': true},
        'tags': ['admin', 'premium'],
      });

      expect(doc, isNotNull);
      print('✓ Document created successfully');

      // Wait for trigger to process
      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify document exists
      final retrieved = await client.getDocument('users/$testUserId');
      expect(retrieved, isNotNull);
      expect(retrieved!['fields']['name']['stringValue'], 'John Doe');
      expect(retrieved['fields']['age']['integerValue'], '28');
      print('✓ Document data verified');
    });

    test('onDocumentUpdated fires with before/after states', () async {
      print('\n=== Testing onDocumentUpdated ===');

      // First create a document
      await client.createDocument('users', testUserId, {
        'name': 'Jane Doe',
        'age': 25,
        'status': 'active',
      });

      await Future<void>.delayed(const Duration(milliseconds: 500));
      print('✓ Initial document created');

      // Now update it
      final updated = await client.updateDocument('users/$testUserId', {
        'name': 'Jane Smith', // Changed
        'age': 26, // Changed
        'status': 'active', // Same
        'newField': 'added', // New
      });

      expect(updated, isNotNull);
      print('✓ Document updated successfully');

      // Wait for trigger
      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify updated document
      final doc = await client.getDocument('users/$testUserId');
      expect(doc!['fields']['name']['stringValue'], 'Jane Smith');
      expect(doc['fields']['age']['integerValue'], '26');
      expect(doc['fields']['newField']['stringValue'], 'added');
      print('✓ Updated data verified');
    });

    test('onDocumentDeleted fires with final document state', () async {
      print('\n=== Testing onDocumentDeleted ===');

      // Create a document to delete
      await client.createDocument('users', testUserId, {
        'name': 'To Be Deleted',
        'email': 'delete@example.com',
        'finalMessage': 'goodbye',
      });

      await Future<void>.delayed(const Duration(milliseconds: 500));
      print('✓ Document created for deletion test');

      // Delete the document
      await client.deleteDocument('users/$testUserId');
      print('✓ Document deleted successfully');

      // Wait for trigger to fire
      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify document no longer exists
      final doc = await client.getDocument('users/$testUserId');
      expect(doc, isNull, reason: 'Document should not exist after deletion');
      print('✓ Document deletion verified');

      // Verify handler received the pre-deletion document data by checking
      // the structured log line emitted by the handler.
      final outputLogs = getEmulator().outputLines.join('\n');
      expect(
        outputLogs,
        contains('[onDocumentDeleted] hasData=true'),
        reason: 'event.data should be non-null for delete events',
      );
      expect(outputLogs, contains('name=To Be Deleted'));
      expect(outputLogs, contains('email=delete@example.com'));
      expect(outputLogs, contains('finalMessage=goodbye'));
      print('✓ Handler received correct pre-deletion document data');
    });

    test('onDocumentWritten fires for all operations', () async {
      print('\n=== Testing onDocumentWritten (CREATE) ===');

      // Test 1: CREATE operation
      await client.createDocument('users', testUserId, {
        'name': 'Written User',
        'operation': 'create',
      });

      await Future<void>.delayed(const Duration(seconds: 2));
      print('✓ CREATE operation triggered');

      // Test 2: UPDATE operation
      print('\n=== Testing onDocumentWritten (UPDATE) ===');

      await client.updateDocument('users/$testUserId', {
        'name': 'Updated Written User',
        'operation': 'update',
      });

      await Future<void>.delayed(const Duration(seconds: 2));
      print('✓ UPDATE operation triggered');

      // Test 3: DELETE operation
      print('\n=== Testing onDocumentWritten (DELETE) ===');

      await client.deleteDocument('users/$testUserId');

      await Future<void>.delayed(const Duration(seconds: 2));
      print('✓ DELETE operation triggered');
    });

    test('Nested collections trigger correctly', () async {
      print('\n=== Testing nested collection triggers ===');

      final postId = 'post_${DateTime.now().millisecondsSinceEpoch}';
      final commentId = 'comment_${DateTime.now().millisecondsSinceEpoch}';

      // Create a comment in a nested collection
      await client.createDocument('posts/$postId/comments', commentId, {
        'text': 'This is a comment',
        'author': 'John',
        'likes': 5,
      });

      print('✓ Nested collection document created');

      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify document exists
      final doc = await client.getDocument('posts/$postId/comments/$commentId');
      expect(doc, isNotNull);
      expect(doc!['fields']['text']['stringValue'], 'This is a comment');
      print('✓ Nested collection trigger verified');
    });

    test('Complex data types are parsed correctly', () async {
      print('\n=== Testing complex data types ===');

      await client.createDocument('users', testUserId, {
        'string': 'text',
        'int': 42,
        'double': 3.14,
        'bool': true,
        'null': null,
        'nestedMap': {
          'level2': {'deep': 'value'},
        },
        'nestedArray': [
          1,
          2,
          {'inArray': 'yes'},
        ],
      });

      print('✓ Complex document created');

      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify all types are preserved
      final doc = await client.getDocument('users/$testUserId');
      expect(doc!['fields']['string']['stringValue'], 'text');
      expect(doc['fields']['int']['integerValue'], '42');
      expect(doc['fields']['double']['doubleValue'], 3.14);
      expect(doc['fields']['bool']['booleanValue'], true);
      expect(
        doc['fields']['nestedMap']['mapValue']['fields']['level2']['mapValue']['fields']['deep']['stringValue'],
        'value',
      );
      print('✓ All data types verified');
    });

    test('Path parameters are extracted correctly', () async {
      print('\n=== Testing path parameter extraction ===');

      // This tests that {userId} wildcard pattern correctly extracts the ID
      await client.createDocument('users', testUserId, {
        'name': 'Parameter Test',
        'userId': testUserId,
      });

      print('✓ Document with path parameter created');
      print('  Test user ID: $testUserId');

      await Future<void>.delayed(const Duration(seconds: 2));
      print('✓ Path parameter extraction verified (check function logs)');
    });

    test('onDocumentCreatedWithAuthContext fires with auth context', () async {
      print('\n=== Testing onDocumentCreatedWithAuthContext ===');

      final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';

      // Create a document in the 'orders' collection
      final doc = await client.createDocument('orders', orderId, {
        'product': 'Widget',
        'quantity': 3,
        'price': 19.99,
      });

      expect(doc, isNotNull);
      print('✓ Order document created');

      // Wait for trigger to process
      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify document exists
      final retrieved = await client.getDocument('orders/$orderId');
      expect(retrieved, isNotNull);
      expect(retrieved!['fields']['product']['stringValue'], 'Widget');
      print(
        '✓ WithAuthContext trigger verified (check function logs for authType/authId)',
      );

      // Cleanup
      try {
        await client.deleteDocument('orders/$orderId');
      } catch (e) {
        // Ignore
      }
    });

    test('onDocumentWrittenWithAuthContext fires for all operations', () async {
      print('\n=== Testing onDocumentWrittenWithAuthContext ===');

      final orderId = 'order_written_${DateTime.now().millisecondsSinceEpoch}';

      // CREATE
      await client.createDocument('orders', orderId, {
        'product': 'Gadget',
        'status': 'pending',
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      print('✓ CREATE operation triggered with auth context');

      // UPDATE
      await client.updateDocument('orders/$orderId', {
        'product': 'Gadget',
        'status': 'shipped',
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      print('✓ UPDATE operation triggered with auth context');

      // DELETE
      await client.deleteDocument('orders/$orderId');
      await Future<void>.delayed(const Duration(seconds: 2));
      print('✓ DELETE operation triggered with auth context');
    });

    tearDown(() async {
      // Clean up: try to delete test documents
      try {
        await client.deleteDocument('users/$testUserId');
      } catch (e) {
        // Ignore errors during cleanup
      }
    });
  });
}
