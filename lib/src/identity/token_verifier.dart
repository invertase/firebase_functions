/// JWT token verification for Auth Blocking functions.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

import '../https/error.dart';

/// URL to fetch Google's public certificates for JWT verification.
const _googleCertsUrl =
    'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

/// Cache duration for Google certificates (1 hour).
const _certsCacheDuration = Duration(hours: 1);

/// Verifier for Auth Blocking JWT tokens.
///
/// This class handles JWT signature verification and claims validation
/// for Identity Platform blocking functions.
///
/// In production, tokens are verified against Google's public certificates.
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

  /// Cached JsonWebKeyStore with Google's public certificates.
  static JsonWebKeyStore? _cachedKeyStore;

  /// When the cached certificates expire.
  static DateTime? _certsExpireAt;

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

    // Get the key store with Google's certificates
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

  /// Fetches Google's public certificates and creates a JsonWebKeyStore.
  Future<JsonWebKeyStore> _getGoogleKeyStore() async {
    // Return cached key store if still valid
    if (_cachedKeyStore != null &&
        _certsExpireAt != null &&
        DateTime.now().isBefore(_certsExpireAt!)) {
      return _cachedKeyStore!;
    }

    // Fetch new certificates
    final response = await _httpClient.get(Uri.parse(_googleCertsUrl));

    if (response.statusCode != 200) {
      throw InternalError(
        'Failed to fetch Google public certificates: ${response.statusCode}',
      );
    }

    // Parse certificates
    final certsJson = jsonDecode(response.body) as Map<String, dynamic>;
    final certs = certsJson.cast<String, String>();

    // Create a JsonWebKeyStore and add each certificate as a JWK
    final keyStore = JsonWebKeyStore();

    for (final entry in certs.entries) {
      final kid = entry.key;
      final pemCert = entry.value;

      try {
        // Convert PEM certificate to JWK
        final jwk = _pemToJwk(pemCert, kid);
        if (jwk != null) {
          keyStore.addKey(jwk);
        }
      } catch (e) {
        // Skip certificates that fail to parse
        continue;
      }
    }

    // Cache with expiration from Cache-Control header or default
    final cacheControl = response.headers['cache-control'];
    var cacheDuration = _certsCacheDuration;

    if (cacheControl != null) {
      final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
      if (maxAgeMatch != null) {
        cacheDuration = Duration(seconds: int.parse(maxAgeMatch.group(1)!));
      }
    }

    _cachedKeyStore = keyStore;
    _certsExpireAt = DateTime.now().add(cacheDuration);

    return keyStore;
  }

  /// Converts a PEM X.509 certificate to a JsonWebKey.
  JsonWebKey? _pemToJwk(String pemCert, String kid) {
    // Remove PEM headers and decode base64
    final certBase64 = pemCert
        .replaceAll('-----BEGIN CERTIFICATE-----', '')
        .replaceAll('-----END CERTIFICATE-----', '')
        .replaceAll('\n', '')
        .trim();

    final certBytes = base64.decode(certBase64);

    // Parse the X.509 certificate to extract the RSA public key
    final publicKey = _extractRsaPublicKeyFromCert(certBytes);
    if (publicKey == null) {
      return null;
    }

    // Create JWK from the RSA public key components
    return JsonWebKey.fromJson({
      'kty': 'RSA',
      'kid': kid,
      'use': 'sig',
      'alg': 'RS256',
      'n': _bigIntToBase64Url(publicKey.n),
      'e': _bigIntToBase64Url(publicKey.e),
    });
  }

  /// Extracts RSA public key (n, e) from an X.509 certificate in DER format.
  ({BigInt n, BigInt e})? _extractRsaPublicKeyFromCert(List<int> certDer) {
    try {
      // X.509 certificate structure (simplified):
      // SEQUENCE {
      //   SEQUENCE { ... certificate info including public key ... }
      //   SEQUENCE { algorithm }
      //   BIT STRING { signature }
      // }

      var offset = 0;

      // Parse outer SEQUENCE
      if (certDer[offset] != 0x30) return null;
      offset++;
      final (_, outerLen) = _parseAsn1Length(certDer, offset);
      offset += outerLen;

      // Parse TBS Certificate SEQUENCE
      if (certDer[offset] != 0x30) return null;
      offset++;
      final (tbsLen, tbsLenBytes) = _parseAsn1Length(certDer, offset);
      offset += tbsLenBytes;

      // We need to find the SubjectPublicKeyInfo within TBS
      // Skip: version, serialNumber, signature, issuer, validity, subject
      // Then we get to subjectPublicKeyInfo

      final tbsEnd = offset + tbsLen;

      // Skip fields until we find the public key
      // This is a simplified parser - in production, use a proper ASN.1 library
      while (offset < tbsEnd) {
        final tag = certDer[offset];
        offset++;
        final (len, lenBytes) = _parseAsn1Length(certDer, offset);
        offset += lenBytes;

        // SubjectPublicKeyInfo is a SEQUENCE containing the algorithm and key
        // We look for a SEQUENCE that contains another SEQUENCE (OID for RSA)
        // followed by a BIT STRING
        if (tag == 0x30) {
          // Check if this looks like SubjectPublicKeyInfo
          final innerOffset = offset;
          if (innerOffset < certDer.length && certDer[innerOffset] == 0x30) {
            // This might be the algorithm identifier
            // Skip it and look for BIT STRING
            var tempOffset = innerOffset + 1;
            final (algLen, algLenBytes) = _parseAsn1Length(certDer, tempOffset);
            tempOffset += algLenBytes + algLen;

            if (tempOffset < certDer.length && certDer[tempOffset] == 0x03) {
              // Found BIT STRING - this is likely the public key
              return _parseRsaPublicKey(certDer.sublist(offset, offset + len));
            }
          }
        }

        offset += len;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parses RSA public key from SubjectPublicKeyInfo structure.
  ({BigInt n, BigInt e})? _parseRsaPublicKey(List<int> spki) {
    try {
      var offset = 0;

      // SEQUENCE (algorithm)
      if (spki[offset] != 0x30) return null;
      offset++;
      final (algLen, algLenBytes) = _parseAsn1Length(spki, offset);
      offset += algLenBytes + algLen;

      // BIT STRING (public key)
      if (spki[offset] != 0x03) return null;
      offset++;
      final (_, bitStringLenBytes) = _parseAsn1Length(spki, offset);
      offset += bitStringLenBytes;

      // Skip unused bits byte
      offset++;

      // The BIT STRING contains a SEQUENCE with INTEGER n and INTEGER e
      if (spki[offset] != 0x30) return null;
      offset++;
      final (_, seqLenBytes) = _parseAsn1Length(spki, offset);
      offset += seqLenBytes;

      // INTEGER n (modulus)
      if (spki[offset] != 0x02) return null;
      offset++;
      final (nLen, nLenBytes) = _parseAsn1Length(spki, offset);
      offset += nLenBytes;
      final nBytes = spki.sublist(offset, offset + nLen);
      offset += nLen;

      // INTEGER e (exponent)
      if (spki[offset] != 0x02) return null;
      offset++;
      final (eLen, eLenBytes) = _parseAsn1Length(spki, offset);
      offset += eLenBytes;
      final eBytes = spki.sublist(offset, offset + eLen);

      return (n: _bytesToBigInt(nBytes), e: _bytesToBigInt(eBytes));
    } catch (e) {
      return null;
    }
  }

  /// Parses ASN.1 length field.
  /// Returns (length, bytesConsumed).
  (int, int) _parseAsn1Length(List<int> data, int offset) {
    final firstByte = data[offset];

    if (firstByte < 0x80) {
      // Short form: length is the byte itself
      return (firstByte, 1);
    }

    // Long form: first byte indicates number of length bytes
    final numBytes = firstByte & 0x7F;
    var length = 0;
    for (var i = 0; i < numBytes; i++) {
      length = (length << 8) | data[offset + 1 + i];
    }
    return (length, 1 + numBytes);
  }

  /// Converts bytes to BigInt (big-endian, potentially with leading zero for sign).
  BigInt _bytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  /// Converts BigInt to base64url string (for JWK format).
  String _bigIntToBase64Url(BigInt value) {
    // Convert BigInt to bytes (big-endian, no leading zeros except for sign)
    final hexString = value.toRadixString(16);
    final paddedHex = hexString.length.isOdd ? '0$hexString' : hexString;
    final bytes = <int>[];

    for (var i = 0; i < paddedHex.length; i += 2) {
      bytes.add(int.parse(paddedHex.substring(i, i + 2), radix: 16));
    }

    // Remove leading zero byte if present (from positive number encoding)
    final trimmedBytes = bytes.isNotEmpty && bytes[0] == 0
        ? bytes.sublist(1)
        : bytes;

    return base64Url.encode(trimmedBytes).replaceAll('=', '');
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

  /// Clears the certificate cache (useful for testing).
  static void clearCertificateCache() {
    _cachedKeyStore = null;
    _certsExpireAt = null;
  }
}
