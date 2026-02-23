import 'dart:async';
import 'dart:convert';

import 'package:firebase_functions/src/logger/logger.dart';
import 'package:test/test.dart';

void main() {
  group('Logger', () {
    late String lastStdout;
    late String lastStderr;
    late Logger testLogger;

    setUp(() {
      lastStdout = '';
      lastStderr = '';
      testLogger = Logger(
        stdoutWriter: (line) => lastStdout = line,
        stderrWriter: (line) => lastStderr = line,
      );
    });

    Map<String, Object?> parseStdout() =>
        jsonDecode(lastStdout) as Map<String, Object?>;

    Map<String, Object?> parseStderr() =>
        jsonDecode(lastStderr) as Map<String, Object?>;

    group('logging methods', () {
      test('should write message to output', () {
        testLogger.log('hello world');
        expect(parseStdout(), {'severity': 'INFO', 'message': 'hello world'});
      });

      test('should merge structured data from jsonPayload', () {
        testLogger.log('hello world', {'additional': 'context'});
        expect(parseStdout(), {
          'severity': 'INFO',
          'message': 'hello world',
          'additional': 'context',
        });
      });

      test('should handle null message', () {
        testLogger.log(null);
        expect(parseStdout(), {'severity': 'INFO', 'message': 'null'});
      });

      test('should overwrite message field in structured data when '
          'message is provided', () {
        testLogger.log('this instead', {'test': true, 'message': 'not this'});
        expect(parseStdout(), {
          'severity': 'INFO',
          'message': 'this instead',
          'test': true,
        });
      });

      test('should not overwrite message field when only structured data '
          'is provided', () {
        testLogger.log({'test': true, 'message': 'this'});
        expect(parseStdout(), {
          'severity': 'INFO',
          'message': 'this',
          'test': true,
        });
      });

      test('should handle structured data without message', () {
        testLogger.log({'test': true, 'count': 42});
        expect(parseStdout(), {'severity': 'INFO', 'test': true, 'count': 42});
      });

      test('should handle empty string message', () {
        testLogger.log('');
        expect(parseStdout(), {'severity': 'INFO'});
      });
    });

    group('severity methods', () {
      test('debug writes DEBUG severity to stdout', () {
        testLogger.debug('test');
        expect(parseStdout(), {'severity': 'DEBUG', 'message': 'test'});
      });

      test('info writes INFO severity to stdout', () {
        testLogger.info('test');
        expect(parseStdout(), {'severity': 'INFO', 'message': 'test'});
      });

      test('log writes INFO severity to stdout', () {
        testLogger.log('test');
        expect(parseStdout(), {'severity': 'INFO', 'message': 'test'});
      });

      test('warn writes WARNING severity to stderr', () {
        testLogger.warn('test');
        expect(parseStderr(), {'severity': 'WARNING', 'message': 'test'});
      });

      test('error writes ERROR severity to stderr', () {
        testLogger.error('test');
        expect(parseStderr(), {'severity': 'ERROR', 'message': 'test'});
      });
    });

    group('severity methods with structured data', () {
      test('debug with jsonPayload', () {
        testLogger.debug('msg', {'key': 'value'});
        expect(parseStdout(), {
          'severity': 'DEBUG',
          'message': 'msg',
          'key': 'value',
        });
      });

      test('warn with jsonPayload', () {
        testLogger.warn('msg', {'key': 'value'});
        expect(parseStderr(), {
          'severity': 'WARNING',
          'message': 'msg',
          'key': 'value',
        });
      });

      test('error with jsonPayload', () {
        testLogger.error('msg', {'key': 'value'});
        expect(parseStderr(), {
          'severity': 'ERROR',
          'message': 'msg',
          'key': 'value',
        });
      });
    });

    group('write', () {
      test('should remove circular references', () {
        final circ = <String, Object?>{'b': 'foo'};
        circ['circ'] = circ;

        testLogger.write({
          'severity': 'ERROR',
          'message': 'testing circular',
          'circ': circ,
        });
        expect(parseStderr(), {
          'severity': 'ERROR',
          'message': 'testing circular',
          'circ': {'b': 'foo', 'circ': '[Circular]'},
        });
      });

      test('should remove circular references in arrays', () {
        final circ = <String, Object?>{'b': 'foo'};
        circ['circ'] = <Object?>[circ];

        testLogger.write({
          'severity': 'ERROR',
          'message': 'testing circular',
          'circ': circ,
        });
        expect(parseStderr(), {
          'severity': 'ERROR',
          'message': 'testing circular',
          'circ': {
            'b': 'foo',
            'circ': ['[Circular]'],
          },
        });
      });

      test('should not detect duplicate object as circular', () {
        final obj = <String, Object?>{'a': 'foo'};
        testLogger.write({
          'severity': 'ERROR',
          'message': 'testing circular',
          'a': obj,
          'b': obj,
        });
        expect(parseStderr(), {
          'severity': 'ERROR',
          'message': 'testing circular',
          'a': {'a': 'foo'},
          'b': {'a': 'foo'},
        });
      });

      test('should not detect duplicate object in array as circular', () {
        final obj = <String, Object?>{'a': 'foo'};
        final arr = <Object?>[
          {'a': obj, 'b': obj},
          {'a': obj, 'b': obj},
        ];
        testLogger.write({
          'severity': 'ERROR',
          'message': 'testing circular',
          'a': arr,
          'b': arr,
        });
        expect(parseStderr(), {
          'severity': 'ERROR',
          'message': 'testing circular',
          'a': [
            {
              'a': {'a': 'foo'},
              'b': {'a': 'foo'},
            },
            {
              'a': {'a': 'foo'},
              'b': {'a': 'foo'},
            },
          ],
          'b': [
            {
              'a': {'a': 'foo'},
              'b': {'a': 'foo'},
            },
            {
              'a': {'a': 'foo'},
              'b': {'a': 'foo'},
            },
          ],
        });
      });

      test('should handle objects with toJson()', () {
        final date = DateTime.utc(1994, 8, 26, 12, 24);
        testLogger.write({
          'severity': 'ERROR',
          'message': 'testing toJSON',
          'obj': {'a': date},
        });
        expect(parseStderr(), {
          'severity': 'ERROR',
          'message': 'testing toJSON',
          'obj': {'a': '1994-08-26T12:24:00.000Z'},
        });
      });

      test('should not alter parameters that are logged', () {
        final circ = <String, Object?>{'b': 'foo'};
        circ['array'] = <Object?>[circ];
        circ['object'] = circ;

        testLogger.write({
          'severity': 'ERROR',
          'message': 'testing circular',
          'circ': circ,
        });

        // Verify original object is not mutated.
        expect(circ['b'], 'foo');
        expect((circ['object'] as Map)['b'], 'foo');
        expect(
          ((circ['object'] as Map)['array'] as List)[0]['object'] is Map,
          isTrue,
        );
      });

      for (final severity in ['DEBUG', 'INFO', 'NOTICE']) {
        test('should output $severity severity to stdout', () {
          testLogger.write({'severity': severity, 'message': 'test'});
          expect(parseStdout(), {'severity': severity, 'message': 'test'});
        });
      }

      for (final severity in [
        'WARNING',
        'ERROR',
        'CRITICAL',
        'ALERT',
        'EMERGENCY',
      ]) {
        test('should output $severity severity to stderr', () {
          testLogger.write({'severity': severity, 'message': 'test'});
          expect(parseStderr(), {'severity': severity, 'message': 'test'});
        });
      }
    });

    group('trace context', () {
      test(
        'should add trace header when traceId is in Zone',
        () {
          runZoned(
            () {
              testLogger.write({'severity': 'INFO', 'message': 'traced'});
              expect(parseStdout(), {
                'severity': 'INFO',
                'message': 'traced',
                'logging.googleapis.com/trace':
                    'projects/test-project/traces/abc123',
              });
            },
            zoneValues: {
              traceIdKey: 'abc123',
              // Simulate GCLOUD_PROJECT env var via a zone-aware override
            },
          );
        },
        skip: 'Requires GCLOUD_PROJECT env var to be set',
      );
    });
  });

  group('removeCircular', () {
    test('should return primitives as-is', () {
      expect(removeCircular(null), isNull);
      expect(removeCircular(true), true);
      expect(removeCircular(42), 42);
      expect(removeCircular(3.14), 3.14);
      expect(removeCircular('hello'), 'hello');
    });

    test('should handle DateTime', () {
      final date = DateTime.utc(2024, 1, 15, 10, 30);
      expect(removeCircular(date), '2024-01-15T10:30:00.000Z');
    });

    test('should handle simple maps', () {
      expect(removeCircular({'a': 1, 'b': 'hello'}), {'a': 1, 'b': 'hello'});
    });

    test('should handle simple lists', () {
      expect(removeCircular([1, 2, 3]), [1, 2, 3]);
    });

    test('should handle nested structures', () {
      expect(
        removeCircular({
          'a': {
            'b': [1, 2, 3],
          },
        }),
        {
          'a': {
            'b': [1, 2, 3],
          },
        },
      );
    });

    test('should replace circular map reference', () {
      final map = <String, Object?>{'key': 'value'};
      map['self'] = map;

      expect(removeCircular(map), {'key': 'value', 'self': '[Circular]'});
    });

    test('should replace circular list reference', () {
      final list = <Object?>['value'];
      list.add(list);

      expect(removeCircular(list), ['value', '[Circular]']);
    });

    test('should handle deeply nested circular references', () {
      final a = <String, Object?>{'name': 'a'};
      final b = <String, Object?>{'name': 'b', 'parent': a};
      a['child'] = b;

      expect(removeCircular(a), {
        'name': 'a',
        'child': {'name': 'b', 'parent': '[Circular]'},
      });
    });
  });

  group('LogSeverity', () {
    test('should have correct string values', () {
      expect(LogSeverity.debug.value, 'DEBUG');
      expect(LogSeverity.info.value, 'INFO');
      expect(LogSeverity.notice.value, 'NOTICE');
      expect(LogSeverity.warning.value, 'WARNING');
      expect(LogSeverity.error.value, 'ERROR');
      expect(LogSeverity.critical.value, 'CRITICAL');
      expect(LogSeverity.alert.value, 'ALERT');
      expect(LogSeverity.emergency.value, 'EMERGENCY');
    });
  });
}
