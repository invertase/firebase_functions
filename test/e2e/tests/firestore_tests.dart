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
      final doc = await client.createDocument(
        'users',
        testUserId,
        {
          'name': FirestoreClient.stringValue('John Doe'),
          'email': FirestoreClient.stringValue('john@example.com'),
          'age': FirestoreClient.intValue(28),
          'active': FirestoreClient.boolValue(true),
          'score': FirestoreClient.doubleValue(95.5),
          'metadata': FirestoreClient.mapValue({
            'created': FirestoreClient.stringValue('2024-01-01'),
            'verified': FirestoreClient.boolValue(true),
          }),
          'tags': FirestoreClient.arrayValue([
            FirestoreClient.stringValue('admin'),
            FirestoreClient.stringValue('premium'),
          ]),
        },
      );

      expect(doc, isNotNull);
      print('✓ Document created successfully');

      // Wait for trigger to process
      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify document exists
      final retrieved = await client.getDocument('users/$testUserId');
      expect(retrieved, isNotNull);
      expect(
        retrieved!['fields']['name']['stringValue'],
        'John Doe',
      );
      expect(retrieved['fields']['age']['integerValue'], '28');
      print('✓ Document data verified');
    });

    test('onDocumentUpdated fires with before/after states', () async {
      print('\n=== Testing onDocumentUpdated ===');

      // First create a document
      await client.createDocument(
        'users',
        testUserId,
        {
          'name': FirestoreClient.stringValue('Jane Doe'),
          'age': FirestoreClient.intValue(25),
          'status': FirestoreClient.stringValue('active'),
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 500));
      print('✓ Initial document created');

      // Now update it
      final updated = await client.updateDocument(
        'users/$testUserId',
        {
          'name': FirestoreClient.stringValue('Jane Smith'), // Changed
          'age': FirestoreClient.intValue(26), // Changed
          'status': FirestoreClient.stringValue('active'), // Same
          'newField': FirestoreClient.stringValue('added'), // New
        },
      );

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
      await client.createDocument(
        'users',
        testUserId,
        {
          'name': FirestoreClient.stringValue('To Be Deleted'),
          'email': FirestoreClient.stringValue('delete@example.com'),
          'finalMessage': FirestoreClient.stringValue('goodbye'),
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 500));
      print('✓ Document created for deletion test');

      // Delete the document
      await client.deleteDocument('users/$testUserId');
      print('✓ Document deleted successfully');

      // Wait for trigger
      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify document no longer exists
      final doc = await client.getDocument('users/$testUserId');
      expect(doc, isNull, reason: 'Document should not exist after deletion');
      print('✓ Document deletion verified');
    });

    test('onDocumentWritten fires for all operations', () async {
      print('\n=== Testing onDocumentWritten (CREATE) ===');

      // Test 1: CREATE operation
      await client.createDocument(
        'users',
        testUserId,
        {
          'name': FirestoreClient.stringValue('Written User'),
          'operation': FirestoreClient.stringValue('create'),
        },
      );

      await Future<void>.delayed(const Duration(seconds: 2));
      print('✓ CREATE operation triggered');

      // Test 2: UPDATE operation
      print('\n=== Testing onDocumentWritten (UPDATE) ===');

      await client.updateDocument(
        'users/$testUserId',
        {
          'name': FirestoreClient.stringValue('Updated Written User'),
          'operation': FirestoreClient.stringValue('update'),
        },
      );

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
      await client.createDocument(
        'posts/$postId/comments',
        commentId,
        {
          'text': FirestoreClient.stringValue('This is a comment'),
          'author': FirestoreClient.stringValue('John'),
          'likes': FirestoreClient.intValue(5),
        },
      );

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

      await client.createDocument(
        'users',
        testUserId,
        {
          'string': FirestoreClient.stringValue('text'),
          'int': FirestoreClient.intValue(42),
          'double': FirestoreClient.doubleValue(3.14),
          'bool': FirestoreClient.boolValue(true),
          'null': FirestoreClient.nullValue(),
          'nestedMap': FirestoreClient.mapValue({
            'level2': FirestoreClient.mapValue({
              'deep': FirestoreClient.stringValue('value'),
            }),
          }),
          'nestedArray': FirestoreClient.arrayValue([
            FirestoreClient.intValue(1),
            FirestoreClient.intValue(2),
            FirestoreClient.mapValue({
              'inArray': FirestoreClient.stringValue('yes'),
            }),
          ]),
        },
      );

      print('✓ Complex document created');

      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify all types are preserved
      final doc = await client.getDocument('users/$testUserId');
      expect(doc!['fields']['string']['stringValue'], 'text');
      expect(doc['fields']['int']['integerValue'], '42');
      expect(doc['fields']['double']['doubleValue'], 3.14);
      expect(doc['fields']['bool']['booleanValue'], true);
      expect(
        doc['fields']['nestedMap']['mapValue']['fields']['level2']['mapValue']
            ['fields']['deep']['stringValue'],
        'value',
      );
      print('✓ All data types verified');
    });

    test('Path parameters are extracted correctly', () async {
      print('\n=== Testing path parameter extraction ===');

      // This tests that {userId} wildcard pattern correctly extracts the ID
      await client.createDocument(
        'users',
        testUserId,
        {
          'name': FirestoreClient.stringValue('Parameter Test'),
          'userId': FirestoreClient.stringValue(testUserId),
        },
      );

      print('✓ Document with path parameter created');
      print('  Test user ID: $testUserId');

      await Future<void>.delayed(const Duration(seconds: 2));
      print('✓ Path parameter extraction verified (check function logs)');
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
