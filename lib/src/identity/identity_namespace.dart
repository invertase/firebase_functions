/// Identity Platform namespace for Cloud Functions.
library;

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

import '../firebase.dart';
import '../https/error.dart';
import 'auth_blocking_event.dart';
import 'options.dart';
import 'responses.dart';

/// Identity Platform namespace.
///
/// Provides methods to define Identity Platform blocking Cloud Functions.
///
/// Example:
/// ```dart
/// firebase.identity.beforeUserCreated(
///   (event) async {
///     print('Creating user: ${event.data?.uid}');
///     return null; // or return BeforeCreateResponse(...)
///   },
/// );
/// ```
class IdentityNamespace extends FunctionsNamespace {
  const IdentityNamespace(super.firebase);

  /// Creates a function triggered before a user is created.
  ///
  /// The handler receives an [AuthBlockingEvent] and can optionally return
  /// a [BeforeCreateResponse] to modify the user being created.
  ///
  /// Example:
  /// ```dart
  /// firebase.identity.beforeUserCreated(
  ///   options: const BlockingOptions(idToken: true),
  ///   (event) async {
  ///     // Block users with certain email domains
  ///     if (event.data?.email?.endsWith('@blocked.com') ?? false) {
  ///       throw HttpsError(
  ///         FunctionsErrorCode.permissionDenied,
  ///         'Email domain not allowed',
  ///       );
  ///     }
  ///     return null;
  ///   },
  /// );
  /// ```
  void beforeUserCreated(
    FutureOr<BeforeCreateResponse?> Function(AuthBlockingEvent event) handler, {
    // ignore: experimental_member_use
    @mustBeConst BlockingOptions? options = const BlockingOptions(),
  }) {
    _beforeOperation(
      eventType: AuthBlockingEventType.beforeCreate,
      options: options,
      handler: (event) async {
        final response = await handler(event);
        return response;
      },
    );
  }

  /// Creates a function triggered before a user signs in.
  ///
  /// The handler receives an [AuthBlockingEvent] and can optionally return
  /// a [BeforeSignInResponse] to modify the sign-in session.
  ///
  /// Example:
  /// ```dart
  /// firebase.identity.beforeUserSignedIn(
  ///   (event) async {
  ///     // Add session claims
  ///     return BeforeSignInResponse(
  ///       sessionClaims: {'lastLogin': DateTime.now().toIso8601String()},
  ///     );
  ///   },
  /// );
  /// ```
  void beforeUserSignedIn(
    FutureOr<BeforeSignInResponse?> Function(AuthBlockingEvent event) handler, {
    // ignore: experimental_member_use
    @mustBeConst BlockingOptions? options = const BlockingOptions(),
  }) {
    _beforeOperation(
      eventType: AuthBlockingEventType.beforeSignIn,
      options: options,
      handler: (event) async {
        final response = await handler(event);
        return response;
      },
    );
  }

  /// Creates a function triggered before an email is sent.
  ///
  /// The handler receives an [AuthBlockingEvent] and can optionally return
  /// a [BeforeEmailResponse] to override the reCAPTCHA action.
  ///
  /// Note: This function does not receive token options (idToken, accessToken,
  /// refreshToken).
  ///
  /// Example:
  /// ```dart
  /// firebase.identity.beforeEmailSent(
  ///   (event) async {
  ///     // Block certain email types
  ///     if (event.emailType == EmailType.passwordReset) {
  ///       return BeforeEmailResponse(
  ///         recaptchaActionOverride: RecaptchaActionOptions.block,
  ///       );
  ///     }
  ///     return null;
  ///   },
  /// );
  /// ```
  void beforeEmailSent(
    FutureOr<BeforeEmailResponse?> Function(AuthBlockingEvent event) handler, {
    // ignore: experimental_member_use
    @mustBeConst BlockingOptions? options = const BlockingOptions(),
  }) {
    _beforeOperation(
      eventType: AuthBlockingEventType.beforeSendEmail,
      options: options,
      handler: (event) async {
        final response = await handler(event);
        return response;
      },
    );
  }

  /// Creates a function triggered before an SMS is sent.
  ///
  /// The handler receives an [AuthBlockingEvent] and can optionally return
  /// a [BeforeSmsResponse] to override the reCAPTCHA action.
  ///
  /// Note: This function does not receive token options (idToken, accessToken,
  /// refreshToken).
  ///
  /// Example:
  /// ```dart
  /// firebase.identity.beforeSmsSent(
  ///   (event) async {
  ///     // Block certain SMS types
  ///     if (event.smsType == SmsType.multiFactorSignIn) {
  ///       return BeforeSmsResponse(
  ///         recaptchaActionOverride: RecaptchaActionOptions.block,
  ///       );
  ///     }
  ///     return null;
  ///   },
  /// );
  /// ```
  void beforeSmsSent(
    FutureOr<BeforeSmsResponse?> Function(AuthBlockingEvent event) handler, {
    // ignore: experimental_member_use
    @mustBeConst BlockingOptions? options = const BlockingOptions(),
  }) {
    _beforeOperation(
      eventType: AuthBlockingEventType.beforeSendSms,
      options: options,
      handler: (event) async {
        final response = await handler(event);
        return response;
      },
    );
  }

  /// Generic handler for all before operations.
  ///
  /// This is the internal implementation that all beforeX methods use.
  void beforeOperation(
    FutureOr<BeforeResponse?> Function(AuthBlockingEvent event) handler, {
    required AuthBlockingEventType eventType,
    // ignore: experimental_member_use
    @mustBeConst BlockingOptions? options = const BlockingOptions(),
  }) {
    _beforeOperation(
      eventType: eventType,
      options: options,
      handler: handler,
    );
  }

  /// Returns a combined InternalOptions class with merged blocking options.
  InternalOptions getOpts(BlockingOptions? options) {
    return getInternalOptions(options);
  }

  /// Internal implementation for before operations.
  void _beforeOperation({
    required AuthBlockingEventType eventType,
    required BlockingOptions? options,
    required FutureOr<BeforeResponse?> Function(AuthBlockingEvent event)
        handler,
  }) {
    final functionName = eventType.value;

    firebase.registerFunction(
      functionName,
      (request) async {
        try {
          // Validate request
          if (!_isValidRequest(request)) {
            throw InvalidArgumentError('Bad Request');
          }

          // Parse request body
          final bodyString = await request.readAsString();
          final body = jsonDecode(bodyString) as Map<String, dynamic>;

          // Extract JWT from request body
          final data = body['data'] as Map<String, dynamic>?;
          final jwt = data?['jwt'] as String?;

          if (jwt == null) {
            throw InvalidArgumentError('Missing JWT in request body');
          }

          // Decode JWT payload (in production, this would be verified)
          final decodedPayload = _decodeJwtPayload(jwt);

          // Parse the event
          final event = AuthBlockingEvent.fromDecodedPayload(decodedPayload);

          // Validate response claims
          final response = await handler(event);
          _validateAuthResponse(eventType, response);

          // Generate response payload
          final result = generateResponsePayload(response);

          return Response.ok(
            jsonEncode(result.toJson()),
            headers: {'Content-Type': 'application/json'},
          );
        } on HttpsError catch (e) {
          return Response(
            e.httpStatusCode,
            body: jsonEncode({
              'error': e.toErrorResponse(),
            }),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          final error = InternalError('An unexpected error occurred.');
          return Response(
            error.httpStatusCode,
            body: jsonEncode({
              'error': error.toErrorResponse(),
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      },
    );
  }

  /// Validates the request format.
  bool _isValidRequest(Request request) {
    if (request.method != 'POST') {
      return false;
    }

    final contentType = request.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('application/json')) {
      return false;
    }

    return true;
  }

  /// Decodes the JWT payload without verification.
  ///
  /// In production, the JWT should be verified using the Firebase Admin SDK.
  /// This is a simplified implementation for the emulator.
  Map<String, dynamic> _decodeJwtPayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) {
      throw InvalidArgumentError('Invalid JWT format');
    }

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  /// Validates the auth response for invalid claims.
  void _validateAuthResponse(
    AuthBlockingEventType eventType,
    BeforeResponse? authResponse,
  ) {
    if (authResponse == null) return;

    // List of reserved claims that cannot be set
    const disallowedClaims = [
      'acr',
      'amr',
      'at_hash',
      'aud',
      'auth_time',
      'azp',
      'cnf',
      'c_hash',
      'exp',
      'iat',
      'iss',
      'jti',
      'nbf',
      'nonce',
      'firebase',
    ];

    const claimsMaxPayloadSize = 1000;

    if (authResponse is BeforeCreateResponse) {
      final customClaims = authResponse.customClaims;
      if (customClaims != null) {
        final invalidClaims = disallowedClaims
            .where((claim) => customClaims.containsKey(claim))
            .toList();
        if (invalidClaims.isNotEmpty) {
          throw InvalidArgumentError(
            'The customClaims claims "${invalidClaims.join(",")}" are reserved '
            'and cannot be specified.',
          );
        }
        if (jsonEncode(customClaims).length > claimsMaxPayloadSize) {
          throw InvalidArgumentError(
            'The customClaims payload should not exceed $claimsMaxPayloadSize '
            'characters.',
          );
        }
      }
    }

    if (authResponse is BeforeSignInResponse) {
      final sessionClaims = authResponse.sessionClaims;
      if (sessionClaims != null) {
        final invalidClaims = disallowedClaims
            .where((claim) => sessionClaims.containsKey(claim))
            .toList();
        if (invalidClaims.isNotEmpty) {
          throw InvalidArgumentError(
            'The sessionClaims claims "${invalidClaims.join(",")}" are reserved '
            'and cannot be specified.',
          );
        }
        if (jsonEncode(sessionClaims).length > claimsMaxPayloadSize) {
          throw InvalidArgumentError(
            'The sessionClaims payload should not exceed $claimsMaxPayloadSize '
            'characters.',
          );
        }

        // Check combined size
        final customClaims = authResponse.customClaims ?? {};
        final combinedClaims = {...customClaims, ...sessionClaims};
        if (jsonEncode(combinedClaims).length > claimsMaxPayloadSize) {
          throw InvalidArgumentError(
            'The customClaims and sessionClaims payloads should not exceed '
            '$claimsMaxPayloadSize characters combined.',
          );
        }
      }
    }
  }
}
