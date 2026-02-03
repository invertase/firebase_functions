/// Authentication and App Check token extraction for callable functions.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:shelf/shelf.dart';

import 'callable.dart';

/// Status of token validation.
enum TokenStatus {
  /// Token is missing from request.
  missing,

  /// Token is present but invalid.
  invalid,

  /// Token is present and valid.
  valid,
}

/// Result of checking auth and app check tokens.
class TokenVerificationResult {
  const TokenVerificationResult({required this.auth, required this.app});

  final TokenStatus auth;
  final TokenStatus app;
}

/// URL to fetch Google's public keys in JWK format for JWT verification.
/// This endpoint returns keys directly as JWKs, no certificate parsing needed.
const _googleJwksUrl = 'https://www.googleapis.com/oauth2/v3/certs';

/// Cache duration for Google keys (1 hour default).
const _keysCacheDuration = Duration(hours: 1);

/// Cached JsonWebKeyStore with Google's public keys.
JsonWebKeyStore? _cachedKeyStore;

/// When the cached keys expire.
DateTime? _keysExpireAt;

/// Regular expression for validating JWT format.
final _jwtRegex = RegExp(
  r'^[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+$',
);

/// HTTP client for fetching keys (can be replaced for testing).
http.Client? _httpClient;

/// Sets a custom HTTP client (for testing).
void setHttpClientForTesting(http.Client? client) {
  _httpClient = client;
}

/// Clears the key cache (useful for testing).
void clearCertificateCache() {
  _cachedKeyStore = null;
  _keysExpireAt = null;
}

/// Extracts and validates auth token from request.
///
/// In emulator mode (when [skipTokenVerification] is true), tokens are decoded
/// but not verified. In production, tokens are verified using Google's public
/// certificates.
///
/// Returns a tuple of (TokenStatus, AuthData?).
Future<(TokenStatus, AuthData?)> extractAuthToken(
  Request request, {
  required bool skipTokenVerification,
}) async {
  final authorization = request.headers['authorization'];
  if (authorization == null || authorization.isEmpty) {
    return (TokenStatus.missing, null);
  }

  // Parse "Bearer <token>" format
  final match = RegExp(
    r'^Bearer\s+(.*)$',
    caseSensitive: false,
  ).firstMatch(authorization);
  if (match == null) {
    return (TokenStatus.invalid, null);
  }

  final idToken = match.group(1)!;

  try {
    Map<String, dynamic> decodedToken;

    if (skipTokenVerification) {
      // In emulator mode, just decode without verification
      decodedToken = _unsafeDecodeIdToken(idToken);
    } else {
      // In production, verify the token signature
      decodedToken = await _verifyIdToken(idToken);
    }

    final uid =
        decodedToken['uid'] as String? ??
        decodedToken['sub'] as String? ??
        decodedToken['user_id'] as String?;

    if (uid == null || uid.isEmpty) {
      return (TokenStatus.invalid, null);
    }

    return (
      TokenStatus.valid,
      AuthData(uid: uid, token: decodedToken, rawToken: idToken),
    );
  } catch (e) {
    return (TokenStatus.invalid, null);
  }
}

/// Extracts and validates App Check token from request.
///
/// In emulator mode (when [skipTokenVerification] is true), tokens are decoded
/// but not verified. In production, tokens should be verified using the
/// Firebase Admin SDK.
///
/// Returns a tuple of (TokenStatus, AppCheckData?).
Future<(TokenStatus, AppCheckData?)> extractAppCheckToken(
  Request request, {
  required bool skipTokenVerification,
}) async {
  final appCheckToken = request.headers['x-firebase-appcheck'];
  if (appCheckToken == null || appCheckToken.isEmpty) {
    return (TokenStatus.missing, null);
  }

  try {
    Map<String, dynamic> decodedToken;

    if (skipTokenVerification) {
      // In emulator mode, just decode without verification
      decodedToken = _unsafeDecodeAppCheckToken(appCheckToken);
    } else {
      // In production, App Check tokens should be verified using Firebase Admin SDK.
      // For now, we decode without verification and note this limitation.
      // TODO: Integrate with Firebase Admin SDK for App Check verification.
      decodedToken = _unsafeDecodeAppCheckToken(appCheckToken);
    }

    final appId =
        decodedToken['app_id'] as String? ?? decodedToken['sub'] as String?;

    if (appId == null || appId.isEmpty) {
      return (TokenStatus.invalid, null);
    }

    return (
      TokenStatus.valid,
      AppCheckData(appId: appId, token: appCheckToken),
    );
  } catch (e) {
    return (TokenStatus.invalid, null);
  }
}

/// Checks both auth and app check tokens on a request.
///
/// Returns a record containing the verification result and extracted data.
Future<
  ({
    TokenVerificationResult result,
    AuthData? authData,
    AppCheckData? appCheckData,
  })
>
checkTokens(Request request, {required bool skipTokenVerification}) async {
  final (authStatus, authData) = await extractAuthToken(
    request,
    skipTokenVerification: skipTokenVerification,
  );

  final (appStatus, appCheckData) = await extractAppCheckToken(
    request,
    skipTokenVerification: skipTokenVerification,
  );

  return (
    result: TokenVerificationResult(auth: authStatus, app: appStatus),
    authData: authData,
    appCheckData: appCheckData,
  );
}

/// Verifies an ID token using Google's public certificates.
///
/// This validates the JWT signature against Google's public keys.
Future<Map<String, dynamic>> _verifyIdToken(String token) async {
  final keyStore = await _getGoogleKeyStore();

  JsonWebToken jwt;
  try {
    jwt = await JsonWebToken.decodeAndVerify(token, keyStore);
  } on JoseException catch (e) {
    throw Exception('Invalid JWT: ${e.message}');
  }

  final payload = jwt.claims.toJson();

  // Set uid from sub claim if not already present
  if (!payload.containsKey('uid') && payload.containsKey('sub')) {
    payload['uid'] = payload['sub'];
  }

  return payload;
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
  final client = _httpClient ?? http.Client();
  final response = await client.get(Uri.parse(_googleJwksUrl));

  if (response.statusCode != 200) {
    throw Exception(
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

// --- Private unsafe decode functions (for emulator mode only) ---

/// Decodes a JWT token without verification.
///
/// **WARNING**: Only use in emulator mode.
Map<String, dynamic> _unsafeDecodeToken(String token) {
  if (!_jwtRegex.hasMatch(token)) {
    return {};
  }

  final parts = token.split('.');
  if (parts.length != 3) {
    return {};
  }

  try {
    final payloadBase64 = parts[1];
    final normalized = base64Url.normalize(payloadBase64);
    final payloadJson = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(payloadJson);

    if (payload is Map<String, dynamic>) {
      return payload;
    }
    return {};
  } catch (e) {
    return {};
  }
}

/// Decodes an ID token without verification.
///
/// **WARNING**: Only use in emulator mode.
Map<String, dynamic> _unsafeDecodeIdToken(String token) {
  final decoded = _unsafeDecodeToken(token);
  // Set uid from sub claim if not already present
  if (!decoded.containsKey('uid') && decoded.containsKey('sub')) {
    decoded['uid'] = decoded['sub'];
  }
  return decoded;
}

/// Decodes an App Check token without verification.
///
/// **WARNING**: Only use in emulator mode.
Map<String, dynamic> _unsafeDecodeAppCheckToken(String token) {
  final decoded = _unsafeDecodeToken(token);
  // Set app_id from sub claim if not already present
  if (!decoded.containsKey('app_id') && decoded.containsKey('sub')) {
    decoded['app_id'] = decoded['sub'];
  }
  return decoded;
}
