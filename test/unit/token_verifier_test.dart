import 'dart:convert';

import 'package:firebase_functions/src/identity/token_verifier.dart';
import 'package:test/test.dart';

void main() {
  group('AuthBlockingTokenVerifier', () {
    group('emulator mode (unsafe decode)', () {
      late AuthBlockingTokenVerifier verifier;

      setUp(() {
        verifier = AuthBlockingTokenVerifier(
          projectId: 'demo-test',
          isEmulator: true, // Emulator mode - no verification
        );
      });

      test('decodes valid JWT without verification', () async {
        // Create a test JWT (header.payload.signature)
        final header = base64Url
            .encode(
              utf8.encode(jsonEncode({'alg': 'RS256', 'kid': 'test-key'})),
            )
            .replaceAll('=', '');
        final payload = base64Url
            .encode(
              utf8.encode(
                jsonEncode({
                  'iss': 'https://securetoken.google.com/demo-test',
                  'aud': 'demo-test.cloudfunctions.net/',
                  'sub': 'user-123',
                  'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
                  'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  'event_type': 'beforeCreate',
                  'user_record': {
                    'uid': 'user-123',
                    'email': 'test@example.com',
                  },
                }),
              ),
            )
            .replaceAll('=', '');
        final jwt = '$header.$payload.fake-signature';

        final result = await verifier.verifyToken(jwt);

        expect(result['sub'], equals('user-123'));
        expect(result['event_type'], equals('beforeCreate'));
        expect(result['user_record'], isA<Map<String, dynamic>>());
      });

      test('decodes JWT with any signature in emulator mode', () async {
        final header = base64Url
            .encode(utf8.encode(jsonEncode({'alg': 'none'})))
            .replaceAll('=', '');
        final payload = base64Url
            .encode(
              utf8.encode(
                jsonEncode({'sub': 'test-user', 'event_type': 'beforeSignIn'}),
              ),
            )
            .replaceAll('=', '');
        final jwt = '$header.$payload.invalid-sig';

        final result = await verifier.verifyToken(jwt);

        expect(result['sub'], equals('test-user'));
      });

      test('throws on invalid JWT format', () async {
        expect(
          () => verifier.verifyToken('not-a-jwt'),
          throwsA(isA<Exception>()),
        );
      });

      test('throws on JWT with wrong number of parts', () async {
        expect(
          () => verifier.verifyToken('only.two'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('claims validation', () {
      late AuthBlockingTokenVerifier verifier;

      setUp(() {
        verifier = AuthBlockingTokenVerifier(
          projectId: 'test-project',
          isEmulator: true, // Use emulator mode to skip signature verification
        );
      });

      test('accepts valid issuer', () async {
        final jwt = _createTestJwt({
          'iss': 'https://securetoken.google.com/test-project',
          'aud': 'test-project.cloudfunctions.net/',
          'sub': 'user-123',
          'exp': _futureTimestamp(),
          'iat': _nowTimestamp(),
          'event_type': 'beforeCreate',
        });

        // Should not throw
        await verifier.verifyToken(jwt);
      });

      test('accepts valid audience', () async {
        final jwt = _createTestJwt({
          'iss': 'https://securetoken.google.com/test-project',
          'aud': 'test-project.cloudfunctions.net/',
          'sub': 'user-123',
          'exp': _futureTimestamp(),
          'iat': _nowTimestamp(),
          'event_type': 'beforeCreate',
        });

        await verifier.verifyToken(jwt);
      });

      test('accepts run.app audience when specified', () async {
        final jwt = _createTestJwt({
          'iss': 'https://securetoken.google.com/test-project',
          'aud': 'run.app',
          'sub': 'user-123',
          'exp': _futureTimestamp(),
          'iat': _nowTimestamp(),
          'event_type': 'beforeCreate',
        });

        await verifier.verifyToken(jwt, audience: 'run.app');
      });

      test('accepts beforeSendEmail without subject', () async {
        final jwt = _createTestJwt({
          'iss': 'https://securetoken.google.com/test-project',
          'aud': 'test-project.cloudfunctions.net/',
          'exp': _futureTimestamp(),
          'iat': _nowTimestamp(),
          'event_type': 'beforeSendEmail',
        });

        // Should not throw - beforeSendEmail doesn't require sub
        await verifier.verifyToken(jwt);
      });

      test('accepts beforeSendSms without subject', () async {
        final jwt = _createTestJwt({
          'iss': 'https://securetoken.google.com/test-project',
          'aud': 'test-project.cloudfunctions.net/',
          'exp': _futureTimestamp(),
          'iat': _nowTimestamp(),
          'event_type': 'beforeSendSms',
        });

        // Should not throw - beforeSendSms doesn't require sub
        await verifier.verifyToken(jwt);
      });
    });

    group('certificate cache', () {
      test('clearCertificateCache resets cache', () {
        // Just verify it doesn't throw
        AuthBlockingTokenVerifier.clearCertificateCache();
      });
    });
  });
}

/// Creates a test JWT with the given payload.
String _createTestJwt(Map<String, dynamic> payload) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'RS256', 'kid': 'test'})))
      .replaceAll('=', '');
  final payloadEncoded = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  return '$header.$payloadEncoded.fake-signature';
}

/// Returns a timestamp 1 hour in the future (seconds since epoch).
int _futureTimestamp() =>
    (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;

/// Returns the current timestamp (seconds since epoch).
int _nowTimestamp() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
