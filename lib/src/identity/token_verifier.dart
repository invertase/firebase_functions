/// JWT token verification for Auth Blocking functions.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

import '../https/error.dart';

/// URL to fetch Google's public keys in JWK format for JWT verification.
/// This endpoint returns keys directly as JWKs, no certificate parsing needed.
const _googleJwksUrl = 'https://www.googleapis.com/oauth2/v3/certs';

/// Cache duration for Google keys (1 hour default).
const _keysCacheDuration = Duration(hours: 1);

/// Verifier for Auth Blocking JWT tokens.
///
/// This class handles JWT signature verification and claims validation
/// for Identity Platform blocking functions.
///
/// In production, tokens are verified against Google's public keys.
/// In emulator/debug mode, verification can be skipped.
class AuthBlockingTokenVerifier {
  AuthBlockingTokenVerifier({
    required this.projectId,
    this.isEmulator = false,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String projectId;
  final bool isEmulator;
  final http.Client _httpClient;

  /// Cached JsonWebKeyStore with Google's public keys.
  static JsonWebKeyStore? _cachedKeyStore;

  /// When the cached keys expire.
  static DateTime? _keysExpireAt;

  /// Expected issuer for Auth Blocking tokens.
  String get _expectedIssuer => 'https://securetoken.google.com/$projectId';

  /// Default audience for GCF v1.
  String get _defaultAudience => '$projectId.cloudfunctions.net/';

  /// Verifies an Auth Blocking JWT token and returns the decoded payload.
  ///
  /// If [audience] is provided, it's used for audience validation.
  /// For Cloud Run (GCF v2), pass `"run.app"` as the audience.
  ///
  /// Throws [UnauthenticatedError] if verification fails.
  Future<Map<String, dynamic>> verifyToken(
    String token, {
    String? audience,
  }) async {
    // In emulator mode, just decode without verification
    if (isEmulator) {
      return _unsafeDecode(token);
    }

    // Get the key store with Google's keys
    final keyStore = await _getGoogleKeyStore();

    // Verify the token using jose
    JsonWebToken jwt;
    try {
      jwt = await JsonWebToken.decodeAndVerify(token, keyStore);
    } on JoseException catch (e) {
      throw UnauthenticatedError('Invalid JWT: ${e.message}');
    } catch (e) {
      throw UnauthenticatedError('Invalid JWT: $e');
    }

    // Extract the payload as a map
    final payload = jwt.claims.toJson();

    // Validate Firebase-specific claims
    _validateClaims(payload, audience);

    return payload;
  }

  /// Decodes a JWT without verification (for emulator mode only).
  Map<String, dynamic> _unsafeDecode(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw InvalidArgumentError('Invalid JWT format');
    }

    final payloadJson = _decodeBase64Url(parts[1]);
    return jsonDecode(payloadJson) as Map<String, dynamic>;
  }

  /// Decodes a base64url string to a UTF-8 string.
  String _decodeBase64Url(String input) {
    final normalized = base64Url.normalize(input);
    return utf8.decode(base64Url.decode(normalized));
  }

  /// Fetches Google's public keys and creates a JsonWebKeyStore.
  ///
  /// Uses the JWK endpoint which returns keys directly in JSON Web Key format,
  /// so no manual certificate parsing is needed.
  Future<JsonWebKeyStore> _getGoogleKeyStore() async {
    // Return cached key store if still valid
    if (_cachedKeyStore != null &&
        _keysExpireAt != null &&
        DateTime.now().isBefore(_keysExpireAt!)) {
      return _cachedKeyStore!;
    }

    // Fetch keys from Google's JWK endpoint
    final response = await _httpClient.get(Uri.parse(_googleJwksUrl));

    if (response.statusCode != 200) {
      throw InternalError(
        'Failed to fetch Google public keys: ${response.statusCode}',
      );
    }

    // Parse the JWK Set response
    final jwksJson = jsonDecode(response.body) as Map<String, dynamic>;
    final keyStore = JsonWebKeyStore();

    // The response contains a "keys" array with JWK objects
    final keys = jwksJson['keys'] as List<dynamic>?;
    if (keys != null) {
      for (final keyJson in keys) {
        try {
          final jwk = JsonWebKey.fromJson(keyJson as Map<String, dynamic>);
          keyStore.addKey(jwk);
        } catch (e) {
          // Skip keys that fail to parse
          continue;
        }
      }
    }

    // Cache with expiration from Cache-Control header or default
    final cacheControl = response.headers['cache-control'];
    var cacheDuration = _keysCacheDuration;

    if (cacheControl != null) {
      final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
      if (maxAgeMatch != null) {
        cacheDuration = Duration(seconds: int.parse(maxAgeMatch.group(1)!));
      }
    }

    _cachedKeyStore = keyStore;
    _keysExpireAt = DateTime.now().add(cacheDuration);

    return keyStore;
  }

  /// Validates JWT claims.
  void _validateClaims(Map<String, dynamic> payload, String? audience) {
    // Validate issuer
    final iss = payload['iss'] as String?;
    if (iss != _expectedIssuer) {
      throw UnauthenticatedError(
        'Invalid token issuer. Expected $_expectedIssuer, got $iss',
      );
    }

    // Validate audience
    final aud = payload['aud'];
    final expectedAudience = audience ?? _defaultAudience;

    bool audienceValid;
    if (aud is String) {
      audienceValid = aud == expectedAudience || aud.contains(expectedAudience);
    } else if (aud is List) {
      audienceValid = aud.any(
        (a) =>
            a == expectedAudience || (a as String).contains(expectedAudience),
      );
    } else {
      audienceValid = false;
    }

    if (!audienceValid) {
      throw UnauthenticatedError(
        'Invalid token audience. Expected $expectedAudience, got $aud',
      );
    }

    // Validate expiration
    final exp = payload['exp'] as int?;
    if (exp == null) {
      throw UnauthenticatedError('Token missing expiration claim');
    }

    final expiration = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    if (DateTime.now().isAfter(expiration)) {
      throw UnauthenticatedError('Token has expired');
    }

    // Validate issued-at (not in the future)
    final iat = payload['iat'] as int?;
    if (iat != null) {
      final issuedAt = DateTime.fromMillisecondsSinceEpoch(iat * 1000);
      // Allow 5 minutes of clock skew
      if (issuedAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        throw UnauthenticatedError('Token issued in the future');
      }
    }

    // Validate subject (except for beforeSendEmail/beforeSendSms)
    final eventType = payload['event_type'] as String?;
    if (eventType != 'beforeSendEmail' && eventType != 'beforeSendSms') {
      final sub = payload['sub'] as String?;
      if (sub == null || sub.isEmpty) {
        throw UnauthenticatedError('Token missing subject claim');
      }
      if (sub.length > 128) {
        throw UnauthenticatedError('Token subject exceeds 128 characters');
      }
    }
  }

  /// Clears the key cache (useful for testing).
  static void clearCertificateCache() {
    _cachedKeyStore = null;
    _keysExpireAt = null;
  }
}
