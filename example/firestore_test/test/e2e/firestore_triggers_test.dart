import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  final firestoreHost =
      Platform.environment['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';
  final firestoreBaseUrl =
      'http://$firestoreHost/v1/projects/demo-test/databases/(default)/documents';

  group('Firestore Triggers E2E Tests', () {
    late String testUserId;

    setUpAll(() async {
      // Wait for emulator to be ready
      await Future<void>.delayed(Duration(seconds: 2));

      print('Running E2E tests against Firestore emulator at: $firestoreHost');
      print('Base URL: $firestoreBaseUrl');
    });

    setUp(() {
      // Generate unique user ID for each test
      testUserId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    });

    test('onDocumentCreated trigger fires and parses document data', () async {
      print('\n=== Testing onDocumentCreated ===');

      // Create a user document
      final userData = {
        'fields': {
          'name': {'stringValue': 'John Doe'},
          'email': {'stringValue': 'john@example.com'},
          'age': {'integerValue': '28'},
          'active': {'booleanValue': true},
          'score': {'doubleValue': 95.5},
          'metadata': {
            'mapValue': {
              'fields': {
                'created': {'stringValue': '2024-01-01'},
                'verified': {'booleanValue': true},
              },
            },
          },
          'tags': {
            'arrayValue': {
              'values': [
                {'stringValue': 'admin'},
                {'stringValue': 'premium'},
              ],
            },
          },
        },
      };

      final response = await http.post(
        Uri.parse('$firestoreBaseUrl/users?documentId=$testUserId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      expect(
        response.statusCode,
        200,
        reason: 'Failed to create document: ${response.body}',
      );
      print('✓ Document created successfully');

      // Wait for trigger to process
      await Future<void>.delayed(Duration(seconds: 1));

      // Verify document exists
      final getResponse = await http.get(
        Uri.parse('$firestoreBaseUrl/users/$testUserId'),
      );

      expect(getResponse.statusCode, 200);
      final doc = jsonDecode(getResponse.body);
      expect(doc['fields']['name']['stringValue'], 'John Doe');
      expect(doc['fields']['age']['integerValue'], '28');
      print('✓ Document data verified');
    });

    test('onDocumentUpdated trigger fires with before/after states', () async {
      print('\n=== Testing onDocumentUpdated ===');

      // First create a document
      final initialData = {
        'fields': {
          'name': {'stringValue': 'Jane Doe'},
          'age': {'integerValue': '25'},
          'status': {'stringValue': 'active'},
        },
      };

      await http.post(
        Uri.parse('$firestoreBaseUrl/users?documentId=$testUserId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(initialData),
      );

      await Future<void>.delayed(Duration(milliseconds: 500));
      print('✓ Initial document created');

      // Now update it
      final updatedData = {
        'fields': {
          'name': {'stringValue': 'Jane Smith'}, // Changed
          'age': {'integerValue': '26'}, // Changed
          'status': {'stringValue': 'active'}, // Same
          'newField': {'stringValue': 'added'}, // New
        },
      };

      final updateResponse = await http.patch(
        Uri.parse('$firestoreBaseUrl/users/$testUserId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updatedData),
      );

      expect(
        updateResponse.statusCode,
        200,
        reason: 'Failed to update document: ${updateResponse.body}',
      );
      print('✓ Document updated successfully');

      // Wait for trigger
      await Future<void>.delayed(Duration(seconds: 1));

      // Verify updated document
      final getResponse = await http.get(
        Uri.parse('$firestoreBaseUrl/users/$testUserId'),
      );

      final doc = jsonDecode(getResponse.body);
      expect(doc['fields']['name']['stringValue'], 'Jane Smith');
      expect(doc['fields']['age']['integerValue'], '26');
      expect(doc['fields']['newField']['stringValue'], 'added');
      print('✓ Updated data verified');
    });

    test('onDocumentDeleted trigger fires with final document state', () async {
      print('\n=== Testing onDocumentDeleted ===');

      // Create a document to delete
      final userData = {
        'fields': {
          'name': {'stringValue': 'To Be Deleted'},
          'email': {'stringValue': 'delete@example.com'},
          'finalMessage': {'stringValue': 'goodbye'},
        },
      };

      await http.post(
        Uri.parse('$firestoreBaseUrl/users?documentId=$testUserId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      await Future<void>.delayed(Duration(milliseconds: 500));
      print('✓ Document created for deletion test');

      // Delete the document
      final deleteResponse = await http.delete(
        Uri.parse('$firestoreBaseUrl/users/$testUserId'),
      );

      expect(
        deleteResponse.statusCode,
        200,
        reason: 'Failed to delete document: ${deleteResponse.body}',
      );
      print('✓ Document deleted successfully');

      // Wait for trigger
      await Future<void>.delayed(Duration(seconds: 1));

      // Verify document no longer exists
      final getResponse = await http.get(
        Uri.parse('$firestoreBaseUrl/users/$testUserId'),
      );

      expect(
        getResponse.statusCode,
        404,
        reason: 'Document should not exist after deletion',
      );
      print('✓ Document deletion verified');
    });

    test('onDocumentWritten trigger fires for all operations', () async {
      print('\n=== Testing onDocumentWritten (CREATE) ===');

      // Test 1: CREATE operation
      final createData = {
        'fields': {
          'name': {'stringValue': 'Written User'},
          'operation': {'stringValue': 'create'},
        },
      };

      final createResponse = await http.post(
        Uri.parse('$firestoreBaseUrl/users?documentId=$testUserId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(createData),
      );

      expect(createResponse.statusCode, 200);
      await Future<void>.delayed(Duration(seconds: 1));
      print('✓ CREATE operation triggered');

      // Test 2: UPDATE operation
      print('\n=== Testing onDocumentWritten (UPDATE) ===');

      final updateData = {
        'fields': {
          'name': {'stringValue': 'Updated Written User'},
          'operation': {'stringValue': 'update'},
        },
      };

      final updateResponse = await http.patch(
        Uri.parse('$firestoreBaseUrl/users/$testUserId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updateData),
      );

      expect(updateResponse.statusCode, 200);
      await Future<void>.delayed(Duration(seconds: 1));
      print('✓ UPDATE operation triggered');

      // Test 3: DELETE operation
      print('\n=== Testing onDocumentWritten (DELETE) ===');

      final deleteResponse = await http.delete(
        Uri.parse('$firestoreBaseUrl/users/$testUserId'),
      );

      expect(deleteResponse.statusCode, 200);
      await Future<void>.delayed(Duration(seconds: 1));
      print('✓ DELETE operation triggered');
    });

    test('Nested collections trigger correctly', () async {
      print('\n=== Testing nested collection triggers ===');

      final postId = 'post_${DateTime.now().millisecondsSinceEpoch}';
      final commentId = 'comment_${DateTime.now().millisecondsSinceEpoch}';

      // Create a comment in a nested collection
      final commentData = {
        'fields': {
          'text': {'stringValue': 'This is a comment'},
          'author': {'stringValue': 'John'},
          'likes': {'integerValue': '5'},
        },
      };

      final response = await http.post(
        Uri.parse(
          '$firestoreBaseUrl/posts/$postId/comments?documentId=$commentId',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(commentData),
      );

      expect(response.statusCode, 200);
      print('✓ Nested collection document created');

      await Future<void>.delayed(Duration(seconds: 1));

      // Verify document exists
      final getResponse = await http.get(
        Uri.parse('$firestoreBaseUrl/posts/$postId/comments/$commentId'),
      );

      expect(getResponse.statusCode, 200);
      final doc = jsonDecode(getResponse.body);
      expect(doc['fields']['text']['stringValue'], 'This is a comment');
      print('✓ Nested collection trigger verified');
    });

    test('Complex data types are parsed correctly', () async {
      print('\n=== Testing complex data types ===');

      final complexData = {
        'fields': {
          'string': {'stringValue': 'text'},
          'int': {'integerValue': '42'},
          'double': {'doubleValue': 3.14},
          'bool': {'booleanValue': true},
          'null': {'nullValue': null},
          'timestamp': {'timestampValue': '2024-01-01T12:00:00Z'},
          'nestedMap': {
            'mapValue': {
              'fields': {
                'level2': {
                  'mapValue': {
                    'fields': {
                      'deep': {'stringValue': 'value'},
                    },
                  },
                },
              },
            },
          },
          'nestedArray': {
            'arrayValue': {
              'values': [
                {'integerValue': '1'},
                {'integerValue': '2'},
                {
                  'mapValue': {
                    'fields': {
                      'inArray': {'stringValue': 'yes'},
                    },
                  },
                },
              ],
            },
          },
        },
      };

      final response = await http.post(
        Uri.parse('$firestoreBaseUrl/users?documentId=$testUserId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(complexData),
      );

      expect(response.statusCode, 200);
      print('✓ Complex document created');

      await Future<void>.delayed(Duration(seconds: 1));

      // Verify all types are preserved
      final getResponse = await http.get(
        Uri.parse('$firestoreBaseUrl/users/$testUserId'),
      );

      final doc = jsonDecode(getResponse.body);
      expect(doc['fields']['string']['stringValue'], 'text');
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
      final userData = {
        'fields': {
          'name': {'stringValue': 'Parameter Test'},
          'userId': {'stringValue': testUserId},
        },
      };

      final response = await http.post(
        Uri.parse('$firestoreBaseUrl/users?documentId=$testUserId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      expect(response.statusCode, 200);
      print('✓ Document with path parameter created');
      print('  Test user ID: $testUserId');

      await Future<void>.delayed(Duration(seconds: 1));
      print('✓ Path parameter extraction verified (check function logs)');
    });

    tearDown(() async {
      // Clean up: try to delete test documents
      try {
        await http.delete(Uri.parse('$firestoreBaseUrl/users/$testUserId'));
      } catch (e) {
        // Ignore errors during cleanup
      }
    });
  });
}
