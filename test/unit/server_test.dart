import 'package:firebase_functions/src/server.dart';
import 'package:test/test.dart';

void main() {
  group('server', () {
    group('extractTraceId', () {
      test('extracts valid trace ID with span and option', () {
        const header = '4bf92f3577b34da6a3ce929d0e0e4736/12345;o=1';
        expect(extractTraceId(header), '4bf92f3577b34da6a3ce929d0e0e4736');
      });

      test('extracts valid trace ID with uppercase hex', () {
        const header = '4BF92F3577B34DA6A3CE929D0E0E4736/12345;o=1';
        expect(extractTraceId(header), '4BF92F3577B34DA6A3CE929D0E0E4736');
      });

      test('extracts valid trace ID without span or option', () {
        const header = '1234567890abcdef1234567890abcdef';
        expect(extractTraceId(header), '1234567890abcdef1234567890abcdef');
      });

      test('handles null and empty', () {
        expect(extractTraceId(null), isNull);
        expect(extractTraceId(''), isNull);
      });

      test('rejects malformed traces', () {
        // Too short
        expect(extractTraceId('1234/567;o=1'), isNull);

        // Too long
        expect(extractTraceId('1234567890abcdef1234567890abcdef0/5'), isNull);

        // Invalid hex
        expect(extractTraceId('1234567890xyzdef1234567890abcdef/5'), isNull);
      });
    });
  });
}
