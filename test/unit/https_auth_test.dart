import 'dart:convert';

import 'package:firebase_functions/src/https/auth.dart';
import 'package:firebase_functions/src/https/callable.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  // All tests use skipTokenVerification: true since we can't easily mock
  // the certificate fetching in unit tests. Integration tests would cover
  // the production path with real certificates.

  group('extractAuthToken', () {
    test('returns missing when no Authorization header', () async {
      final request = _createRequest();

      final (status, auth) = await extractAuthToken(
        request,
        skipTokenVerification: true,
      );

      expect(status, TokenStatus.missing);
      expect(auth, isNull);
    });

    test(
      'returns invalid when Authorization header is not Bearer format',
      () async {
        final request = _createRequest(
          headers: {'authorization': 'Basic abc123'},
        );

        final (status, auth) = await extractAuthToken(
          request,
          skipTokenVerification: true,
        );

        expect(status, TokenStatus.invalid);
        expect(auth, isNull);
      },
    );

    test('returns invalid when token has no uid/sub claim', () async {
      final jwt = _createJwt({'email': 'test@example.com'});
      final request = _createRequest(headers: {'authorization': 'Bearer $jwt'});

      final (status, auth) = await extractAuthToken(
        request,
        skipTokenVerification: true,
      );

      expect(status, TokenStatus.invalid);
      expect(auth, isNull);
    });

    test('returns valid with AuthData for valid token', () async {
      final jwt = _createJwt({
        'sub': 'user123',
        'email': 'test@example.com',
        'custom_claim': 'value',
      });
      final request = _createRequest(headers: {'authorization': 'Bearer $jwt'});

      final (status, auth) = await extractAuthToken(
        request,
        skipTokenVerification: true,
      );

      expect(status, TokenStatus.valid);
      expect(auth, isNotNull);
      expect(auth!.uid, 'user123');
      expect(auth.token?['email'], 'test@example.com');
      expect(auth.token?['custom_claim'], 'value');
      expect(auth.rawToken, jwt);
    });

    test('extracts uid from user_id claim as fallback', () async {
      final jwt = _createJwt({'user_id': 'user456'});
      final request = _createRequest(headers: {'authorization': 'Bearer $jwt'});

      final (status, auth) = await extractAuthToken(
        request,
        skipTokenVerification: true,
      );

      expect(status, TokenStatus.valid);
      expect(auth?.uid, 'user456');
    });

    test('handles case-insensitive Bearer prefix', () async {
      final jwt = _createJwt({'sub': 'user123'});
      final request = _createRequest(headers: {'authorization': 'bearer $jwt'});

      final (status, auth) = await extractAuthToken(
        request,
        skipTokenVerification: true,
      );

      expect(status, TokenStatus.valid);
      expect(auth?.uid, 'user123');
    });

    test('returns invalid for malformed JWT', () async {
      final request = _createRequest(
        headers: {'authorization': 'Bearer not-a-valid-jwt'},
      );

      final (status, auth) = await extractAuthToken(
        request,
        skipTokenVerification: true,
      );

      expect(status, TokenStatus.invalid);
      expect(auth, isNull);
    });

    test('returns invalid for JWT with empty payload', () async {
      final jwt = _createJwt({});
      final request = _createRequest(headers: {'authorization': 'Bearer $jwt'});

      final (status, auth) = await extractAuthToken(
        request,
        skipTokenVerification: true,
      );

      expect(status, TokenStatus.invalid);
      expect(auth, isNull);
    });
  });

  group('extractAppCheckToken', () {
    test('returns missing when no X-Firebase-AppCheck header', () async {
      final request = _createRequest();

      final (status, appCheck) = await extractAppCheckToken(
        request,
        skipTokenVerification: true,
      );

      expect(status, TokenStatus.missing);
      expect(appCheck, isNull);
    });

    test('returns invalid when token has no sub claim', () async {
      final jwt = _createJwt({'other': 'value'});
      final request = _createRequest(headers: {'x-firebase-appcheck': jwt});

      final (status, appCheck) = await extractAppCheckToken(
        request,
        skipTokenVerification: true,
      );

      expect(status, TokenStatus.invalid);
      expect(appCheck, isNull);
    });

    test('returns valid with AppCheckData for valid token', () async {
      final jwt = _createJwt({'sub': 'app123'});
      final request = _createRequest(headers: {'x-firebase-appcheck': jwt});

      final (status, appCheck) = await extractAppCheckToken(
        request,
        skipTokenVerification: true,
      );

      expect(status, TokenStatus.valid);
      expect(appCheck, isNotNull);
      expect(appCheck!.appId, 'app123');
      expect(appCheck.token, jwt);
    });

    test('extracts app_id from explicit claim', () async {
      final jwt = _createJwt({'sub': 'sub-value', 'app_id': 'explicit-app-id'});
      final request = _createRequest(headers: {'x-firebase-appcheck': jwt});

      final (status, appCheck) = await extractAppCheckToken(
        request,
        skipTokenVerification: true,
      );

      expect(status, TokenStatus.valid);
      expect(appCheck?.appId, 'explicit-app-id');
    });
  });

  group('checkTokens', () {
    test('returns both auth and app check data when present', () async {
      final authJwt = _createJwt({'sub': 'user123'});
      final appCheckJwt = _createJwt({'sub': 'app123'});
      final request = _createRequest(
        headers: {
          'authorization': 'Bearer $authJwt',
          'x-firebase-appcheck': appCheckJwt,
        },
      );

      final result = await checkTokens(request, skipTokenVerification: true);

      expect(result.result.auth, TokenStatus.valid);
      expect(result.result.app, TokenStatus.valid);
      expect(result.authData?.uid, 'user123');
      expect(result.appCheckData?.appId, 'app123');
    });

    test('returns missing status when headers are absent', () async {
      final request = _createRequest();

      final result = await checkTokens(request, skipTokenVerification: true);

      expect(result.result.auth, TokenStatus.missing);
      expect(result.result.app, TokenStatus.missing);
      expect(result.authData, isNull);
      expect(result.appCheckData, isNull);
    });

    test('handles mixed valid and invalid tokens', () async {
      final authJwt = _createJwt({'sub': 'user123'});
      final invalidAppCheckJwt = _createJwt({'no_sub': 'value'});
      final request = _createRequest(
        headers: {
          'authorization': 'Bearer $authJwt',
          'x-firebase-appcheck': invalidAppCheckJwt,
        },
      );

      final result = await checkTokens(request, skipTokenVerification: true);

      expect(result.result.auth, TokenStatus.valid);
      expect(result.result.app, TokenStatus.invalid);
      expect(result.authData?.uid, 'user123');
      expect(result.appCheckData, isNull);
    });
  });

  group('AuthData', () {
    test('rawToken field is accessible', () {
      const auth = AuthData(uid: 'user123', rawToken: 'raw-token-value');

      expect(auth.rawToken, 'raw-token-value');
    });

    test('all fields are populated correctly', () {
      const auth = AuthData(
        uid: 'user123',
        token: {'email': 'test@example.com'},
        rawToken: 'raw-token',
      );

      expect(auth.uid, 'user123');
      expect(auth.token, {'email': 'test@example.com'});
      expect(auth.rawToken, 'raw-token');
    });
  });

  group('TokenStatus', () {
    test('has correct enum values', () {
      expect(TokenStatus.values, hasLength(3));
      expect(TokenStatus.values, contains(TokenStatus.missing));
      expect(TokenStatus.values, contains(TokenStatus.invalid));
      expect(TokenStatus.values, contains(TokenStatus.valid));
    });
  });

  group('TokenVerificationResult', () {
    test('holds auth and app status', () {
      const result = TokenVerificationResult(
        auth: TokenStatus.valid,
        app: TokenStatus.missing,
      );

      expect(result.auth, TokenStatus.valid);
      expect(result.app, TokenStatus.missing);
    });
  });
}

/// Creates a minimal JWT token for testing.
///
/// This creates a token with a dummy header and signature, but a real
/// base64-encoded payload. This is only for testing the decode functions
/// in emulator mode where verification is skipped.
String _createJwt(Map<String, dynamic> payload) {
  final headerJson = jsonEncode({'alg': 'HS256', 'typ': 'JWT'});
  final payloadJson = jsonEncode(payload);

  final header = base64Url.encode(utf8.encode(headerJson)).replaceAll('=', '');
  final body = base64Url.encode(utf8.encode(payloadJson)).replaceAll('=', '');
  const signature = 'dummysignature';

  return '$header.$body.$signature';
}

/// Creates a test request with optional headers.
Request _createRequest({Map<String, String>? headers}) {
  return Request(
    'POST',
    Uri.parse('http://localhost:8080/test'),
    headers: headers,
  );
}
