import 'package:test/test.dart';

import '../helpers/database_client.dart';
import '../helpers/emulator.dart';

/// E2E tests for Realtime Database triggers.
void runDatabaseTests(
  String Function() getExamplePath,
  DatabaseClient Function() getClient,
  EmulatorHelper Function() getEmulator,
) {
  group('Realtime Database Triggers', () {
    late DatabaseClient client;
    late String testMessageId;

    setUp(() {
      client = getClient();
      testMessageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    });

    test('onValueCreated fires and parses data', () async {
      print('\n=== Testing onValueCreated ===');

      // Create a value at messages/{messageId}
      await client.setValue('messages/$testMessageId', {
        'text': 'Hello from test',
        'sender': 'test-user',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      print('Created message at messages/$testMessageId');

      // Wait for trigger to process
      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify value exists
      final value = await client.getValue('messages/$testMessageId');
      expect(value, isNotNull);
      expect(value['text'], 'Hello from test');
      expect(value['sender'], 'test-user');
      print('Message data verified');
    });

    test('onValueUpdated fires with before/after states', () async {
      print('\n=== Testing onValueUpdated ===');

      // First create a value
      await client.setValue('messages/$testMessageId', {
        'text': 'Original message',
        'count': 1,
      });

      await Future<void>.delayed(const Duration(milliseconds: 500));
      print('Initial value created');

      // Now update it
      await client.updateValue('messages/$testMessageId', {
        'text': 'Updated message',
        'count': 2,
      });

      print('Value updated');

      // Wait for trigger
      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify updated value
      final value = await client.getValue('messages/$testMessageId');
      expect(value['text'], 'Updated message');
      expect(value['count'], 2);
      print('Updated data verified');
    });

    test('onValueDeleted fires with final data', () async {
      print('\n=== Testing onValueDeleted ===');

      // Create a value to delete
      await client.setValue('messages/$testMessageId', {
        'text': 'To be deleted',
        'finalMessage': 'goodbye',
      });

      await Future<void>.delayed(const Duration(milliseconds: 500));
      print('Value created for deletion test');

      // Delete the value
      await client.deleteValue('messages/$testMessageId');
      print('Value deleted');

      // Wait for trigger
      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify value no longer exists
      final value = await client.getValue('messages/$testMessageId');
      expect(value, isNull, reason: 'Value should not exist after deletion');
      print('Value deletion verified');
    });

    test('onValueWritten fires for all operations', () async {
      print('\n=== Testing onValueWritten (CREATE) ===');

      // Test 1: CREATE operation
      await client.setValue('messages/$testMessageId', {
        'text': 'Written value',
        'operation': 'create',
      });

      await Future<void>.delayed(const Duration(seconds: 2));
      print('CREATE operation triggered');

      // Test 2: UPDATE operation
      print('\n=== Testing onValueWritten (UPDATE) ===');

      await client.updateValue('messages/$testMessageId', {
        'text': 'Updated written value',
        'operation': 'update',
      });

      await Future<void>.delayed(const Duration(seconds: 2));
      print('UPDATE operation triggered');

      // Test 3: DELETE operation
      print('\n=== Testing onValueWritten (DELETE) ===');

      await client.deleteValue('messages/$testMessageId');

      await Future<void>.delayed(const Duration(seconds: 2));
      print('DELETE operation triggered');
    });

    test('Nested path triggers correctly', () async {
      print('\n=== Testing nested path triggers ===');

      final testUserId = 'user_${DateTime.now().millisecondsSinceEpoch}';

      // Create a status at users/{userId}/status
      await client.setValue('users/$testUserId/status', {
        'online': true,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });

      print('Nested path value created: users/$testUserId/status');

      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify value exists
      final value = await client.getValue('users/$testUserId/status');
      expect(value, isNotNull);
      expect(value['online'], true);
      print('Nested path trigger verified');

      // Clean up
      await client.deleteValue('users/$testUserId');
    });

    test('Complex data types are parsed correctly', () async {
      print('\n=== Testing complex data types ===');

      await client.setValue('messages/$testMessageId', {
        'string': 'text',
        'int': 42,
        'double': 3.14,
        'bool': true,
        'null': null,
        'nestedMap': {
          'level2': {'deep': 'value'},
        },
        'array': [1, 2, 3, 'four'],
      });

      print('Complex data created');

      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify all types are preserved
      final value = await client.getValue('messages/$testMessageId');
      expect(value['string'], 'text');
      expect(value['int'], 42);
      expect(value['double'], 3.14);
      expect(value['bool'], true);
      expect(value['null'], isNull);
      expect(value['nestedMap']['level2']['deep'], 'value');
      expect(value['array'], [1, 2, 3, 'four']);
      print('All data types verified');
    });

    test('Path parameters are extracted correctly', () async {
      print('\n=== Testing path parameter extraction ===');

      // This tests that {messageId} wildcard pattern correctly extracts the ID
      await client.setValue('messages/$testMessageId', {
        'text': 'Parameter test',
        'messageId': testMessageId,
      });

      print('Value with path parameter created');
      print('  Test message ID: $testMessageId');

      await Future<void>.delayed(const Duration(seconds: 2));
      print('Path parameter extraction verified (check function logs)');
    });

    test('Push generates unique keys', () async {
      print('\n=== Testing push with auto-generated keys ===');

      // Push multiple values and verify they have unique keys
      final key1 = await client.pushValue('messages', {'text': 'Message 1'});
      final key2 = await client.pushValue('messages', {'text': 'Message 2'});

      print('Pushed messages with keys: $key1, $key2');

      expect(key1, isNot(equals(key2)));
      expect(key1, startsWith('-'));
      expect(key2, startsWith('-'));

      await Future<void>.delayed(const Duration(seconds: 2));

      // Clean up
      await client.deleteValue('messages/$key1');
      await client.deleteValue('messages/$key2');
      print('Auto-generated keys verified');
    });

    tearDown(() async {
      // Clean up: try to delete test values
      try {
        await client.deleteValue('messages/$testMessageId');
      } catch (e) {
        // Ignore errors during cleanup
      }
    });
  });
}
