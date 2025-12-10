import 'dart:async';

import 'package:firebase_functions/src/common/on_init.dart';
import 'package:test/test.dart';

void main() {
  group('onInit', () {
    setUp(() {
      resetInit();
    });

    tearDown(() {
      resetInit();
    });

    test('callback is called before first handler execution', () async {
      var initCalled = false;

      onInit(() {
        initCalled = true;
      });

      // Before any handler runs, init should not be called
      expect(initCalled, false);
      expect(didInit, false);

      // Create a wrapped handler
      final handler = withInit<int, int>((x) => x * 2);

      // Execute the handler
      final result = await handler(5);

      expect(result, 10);
      expect(initCalled, true);
      expect(didInit, true);
    });

    test('callback is called only once', () async {
      var callCount = 0;

      onInit(() {
        callCount++;
      });

      final handler = withInit<int, int>((x) => x);

      // Execute multiple times
      await handler(1);
      await handler(2);
      await handler(3);

      // Should only be called once
      expect(callCount, 1);
    });

    test('async callback is awaited', () async {
      var initCompleted = false;

      onInit(() async {
        await Future.delayed(Duration(milliseconds: 50));
        initCompleted = true;
      });

      final handler = withInit<String, int>((x) {
        // When this runs, init should have completed
        expect(initCompleted, true, reason: 'Init should complete before handler');
        return 'result $x';
      });

      final result = await handler(42);
      expect(result, 'result 42');
      expect(initCompleted, true);
    });

    test('works without any callback registered', () async {
      // No onInit called

      final handler = withInit<int, int>((x) => x * 3);
      final result = await handler(7);

      expect(result, 21);
      expect(didInit, true);
    });

    test('latest callback overwrites previous', () async {
      var firstCalled = false;
      var secondCalled = false;

      onInit(() {
        firstCalled = true;
      });

      onInit(() {
        secondCalled = true;
      });

      final handler = withInit<void, void>((_) {});
      await handler(null);

      expect(firstCalled, false, reason: 'First callback should be overwritten');
      expect(secondCalled, true);
    });

    test('withInitVoid works for void handlers', () async {
      var initCalled = false;
      var handlerCalled = false;

      onInit(() {
        initCalled = true;
      });

      final handler = withInitVoid<String>((arg) {
        handlerCalled = true;
        expect(arg, 'test');
      });

      await handler('test');

      expect(initCalled, true);
      expect(handlerCalled, true);
    });

    test('resetInit allows init to run again', () async {
      var callCount = 0;

      onInit(() {
        callCount++;
      });

      final handler = withInit<int, int>((x) => x);

      await handler(1);
      expect(callCount, 1);

      // Reset
      resetInit();

      // Re-register
      onInit(() {
        callCount++;
      });

      await handler(2);
      expect(callCount, 2);
    });

    test('handler error does not prevent future init', () async {
      var initCalled = false;

      onInit(() {
        initCalled = true;
      });

      final throwingHandler = withInit<int, int>((x) {
        throw Exception('Handler error');
      });

      // Before first call, init should not be called
      expect(initCalled, false);
      expect(didInit, false);

      // First call - init runs but handler throws
      await expectLater(
        () async => await throwingHandler(1),
        throwsException,
      );

      // Init should have been marked as complete even though handler threw
      expect(didInit, true);
      expect(initCalled, true);
    });

    test('FutureOr<void> callback works', () async {
      var syncCalled = false;

      // Synchronous callback
      onInit(() {
        syncCalled = true;
      });

      final handler = withInit<int, int>((x) => x);
      await handler(1);

      expect(syncCalled, true);
    });
  });

  group('Multiple handlers share init state', () {
    setUp(() => resetInit());
    tearDown(() => resetInit());

    test('init runs once for multiple handlers', () async {
      var initCount = 0;

      onInit(() {
        initCount++;
      });

      final handler1 = withInit<int, int>((x) => x + 1);
      final handler2 = withInit<int, int>((x) => x + 2);

      // First handler triggers init
      final result1 = await handler1(10);
      expect(result1, 11);
      expect(initCount, 1);

      // Second handler doesn't trigger init again
      final result2 = await handler2(10);
      expect(result2, 12);
      expect(initCount, 1);
    });
  });
}
