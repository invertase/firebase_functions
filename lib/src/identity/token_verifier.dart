/// JWT token verification for Auth Blocking functions.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

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

  /// Cached Google public certificates.
  static Map<String, String>? _cachedCerts;

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

    // Parse JWT parts
    final parts = token.split('.');
    if (parts.length != 3) {
      throw UnauthenticatedError('Invalid JWT format');
    }

    final headerJson = _decodeBase64Url(parts[0]);
    final payloadJson = _decodeBase64Url(parts[1]);
    final signature = parts[2];

    Map<String, dynamic> header;
    Map<String, dynamic> payload;

    try {
      header = jsonDecode(headerJson) as Map<String, dynamic>;
      payload = jsonDecode(payloadJson) as Map<String, dynamic>;
    } on FormatException {
      throw UnauthenticatedError('Invalid JWT encoding');
    }

    // Validate header
    final alg = header['alg'] as String?;
    if (alg != 'RS256') {
      throw UnauthenticatedError(
        'Invalid JWT algorithm. Expected RS256, got $alg',
      );
    }

    final kid = header['kid'] as String?;
    if (kid == null) {
      throw UnauthenticatedError('Missing key ID (kid) in JWT header');
    }

    // Verify signature
    await _verifySignature(
      data: '${parts[0]}.${parts[1]}',
      signature: signature,
      kid: kid,
    );

    // Validate claims
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

  /// Verifies the JWT signature against Google's public certificates.
  Future<void> _verifySignature({
    required String data,
    required String signature,
    required String kid,
  }) async {
    // Fetch certificates
    final certs = await _getGoogleCertificates();

    // Find the certificate for this key ID
    final certPem = certs[kid];
    if (certPem == null) {
      throw UnauthenticatedError(
        'No certificate found for key ID: $kid. '
        'Token may be expired or from a different issuer.',
      );
    }

    // Decode signature from base64url
    final signatureBytes = base64Url.decode(base64Url.normalize(signature));

    // Verify using RSA
    final isValid = await _verifyRS256(
      data: utf8.encode(data),
      signature: signatureBytes,
      certPem: certPem,
    );

    if (!isValid) {
      throw UnauthenticatedError('Invalid JWT signature');
    }
  }

  /// Fetches Google's public certificates with caching.
  Future<Map<String, String>> _getGoogleCertificates() async {
    // Return cached certs if still valid
    if (_cachedCerts != null &&
        _certsExpireAt != null &&
        DateTime.now().isBefore(_certsExpireAt!)) {
      return _cachedCerts!;
    }

    // Fetch new certificates
    final response = await _httpClient.get(Uri.parse(_googleCertsUrl));

    if (response.statusCode != 200) {
      throw InternalError(
        'Failed to fetch Google public certificates: ${response.statusCode}',
      );
    }

    // Parse certificates
    final certs =
        (jsonDecode(response.body) as Map<String, dynamic>).cast<String, String>();

    // Cache with expiration from Cache-Control header or default
    final cacheControl = response.headers['cache-control'];
    var cacheDuration = _certsCacheDuration;

    if (cacheControl != null) {
      final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
      if (maxAgeMatch != null) {
        cacheDuration = Duration(seconds: int.parse(maxAgeMatch.group(1)!));
      }
    }

    _cachedCerts = certs;
    _certsExpireAt = DateTime.now().add(cacheDuration);

    return certs;
  }

  /// Verifies an RS256 signature using the given PEM certificate.
  Future<bool> _verifyRS256({
    required List<int> data,
    required Uint8List signature,
    required String certPem,
  }) async {
    // Extract the public key from the PEM certificate
    // The PEM contains an X.509 certificate, we need to extract the public key

    // Remove PEM headers and decode base64
    final certBase64 = certPem
        .replaceAll('-----BEGIN CERTIFICATE-----', '')
        .replaceAll('-----END CERTIFICATE-----', '')
        .replaceAll('\n', '')
        .trim();

    final certBytes = base64.decode(certBase64);

    // Use dart:io's SecureSocket/SecurityContext for RSA verification
    // Since Dart doesn't have built-in RSA verification, we'll use a
    // workaround with Process to call openssl, or use the crypto package

    // For now, we'll use the pointycastle package approach via dart_firebase_admin
    // which already has this capability as a transitive dependency

    try {
      return _verifyWithPointyCastle(
        data: Uint8List.fromList(data),
        signature: signature,
        certDer: certBytes,
      );
    } catch (e) {
      // If verification fails for any reason, the signature is invalid
      return false;
    }
  }

  /// Verifies RS256 signature using PointyCastle (via dart_firebase_admin).
  bool _verifyWithPointyCastle({
    required Uint8List data,
    required Uint8List signature,
    required Uint8List certDer,
  }) {
    // Parse the X.509 certificate to extract the RSA public key
    // The certificate is in DER format (ASN.1)

    // For simplicity and to avoid adding more dependencies, we'll parse
    // the ASN.1 structure manually to extract the public key

    final publicKey = _extractRsaPublicKeyFromCert(certDer);
    if (publicKey == null) {
      return false;
    }

    // Verify the signature using RSA-SHA256
    return _rsaVerify(
      publicKey: publicKey,
      data: data,
      signature: signature,
    );
  }

  /// Extracts RSA public key (n, e) from an X.509 certificate in DER format.
  ({BigInt n, BigInt e})? _extractRsaPublicKeyFromCert(Uint8List certDer) {
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
  ({BigInt n, BigInt e})? _parseRsaPublicKey(Uint8List spki) {
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
      final (bitStringLen, bitStringLenBytes) = _parseAsn1Length(spki, offset);
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

      return (
        n: _bytesToBigInt(nBytes),
        e: _bytesToBigInt(eBytes),
      );
    } catch (e) {
      return null;
    }
  }

  /// Parses ASN.1 length field.
  /// Returns (length, bytesConsumed).
  (int, int) _parseAsn1Length(Uint8List data, int offset) {
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
  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  /// Verifies RSA-SHA256 signature.
  bool _rsaVerify({
    required ({BigInt n, BigInt e}) publicKey,
    required Uint8List data,
    required Uint8List signature,
  }) {
    // Compute SHA-256 hash of data
    final hash = _sha256(data);

    // RSA verification: signature^e mod n
    final signatureInt = _bytesToBigInt(signature);
    final decrypted = signatureInt.modPow(publicKey.e, publicKey.n);

    // Convert decrypted value to bytes
    final decryptedBytes = _bigIntToBytes(decrypted, signature.length);

    // PKCS#1 v1.5 signature format:
    // 0x00 0x01 [padding 0xFF bytes] 0x00 [DigestInfo] [hash]
    // DigestInfo for SHA-256: 30 31 30 0d 06 09 60 86 48 01 65 03 04 02 01 05 00 04 20

    const sha256DigestInfo = [
      0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, //
      0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
    ];

    // Verify PKCS#1 v1.5 padding
    if (decryptedBytes.length < 11 + sha256DigestInfo.length + hash.length) {
      return false;
    }

    var offset = 0;

    // Check 0x00 0x01
    if (decryptedBytes[offset++] != 0x00) return false;
    if (decryptedBytes[offset++] != 0x01) return false;

    // Skip padding (0xFF bytes)
    while (offset < decryptedBytes.length && decryptedBytes[offset] == 0xFF) {
      offset++;
    }

    // Check separator 0x00
    if (offset >= decryptedBytes.length || decryptedBytes[offset++] != 0x00) {
      return false;
    }

    // Check DigestInfo
    for (var i = 0; i < sha256DigestInfo.length; i++) {
      if (offset + i >= decryptedBytes.length ||
          decryptedBytes[offset + i] != sha256DigestInfo[i]) {
        return false;
      }
    }
    offset += sha256DigestInfo.length;

    // Compare hash
    if (offset + hash.length > decryptedBytes.length) {
      return false;
    }

    for (var i = 0; i < hash.length; i++) {
      if (decryptedBytes[offset + i] != hash[i]) {
        return false;
      }
    }

    return true;
  }

  /// Converts BigInt to fixed-length bytes (big-endian).
  Uint8List _bigIntToBytes(BigInt value, int length) {
    final result = Uint8List(length);
    var v = value;
    for (var i = length - 1; i >= 0; i--) {
      result[i] = (v & BigInt.from(0xFF)).toInt();
      v = v >> 8;
    }
    return result;
  }

  /// Computes SHA-256 hash using dart:io.
  Uint8List _sha256(Uint8List data) {
    // Use dart:io's built-in SHA-256
    final digest = sha256.convert(data);
    return Uint8List.fromList(digest.bytes);
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
        (a) => a == expectedAudience || (a as String).contains(expectedAudience),
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
    _cachedCerts = null;
    _certsExpireAt = null;
  }
}
