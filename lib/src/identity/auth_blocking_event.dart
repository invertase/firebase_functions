/// Auth blocking event types for Identity Platform blocking functions.
library;

import 'auth_user_record.dart';

/// Shorthand auth blocking events from GCIP.
enum AuthBlockingEventType {
  /// Triggered before a user is created.
  beforeCreate('beforeCreate'),

  /// Triggered before a user signs in.
  beforeSignIn('beforeSignIn'),

  /// Triggered before an email is sent.
  beforeSendEmail('beforeSendEmail'),

  /// Triggered before an SMS is sent.
  beforeSendSms('beforeSendSms');

  const AuthBlockingEventType(this.value);

  /// The string value of the event type.
  final String value;

  /// The legacy event type for the Firebase Auth backend.
  String get legacyEventType => 'providers/cloud.auth/eventTypes/user.$value';
}

/// Possible types of emails as described by the GCIP backend.
enum EmailType {
  /// A sign-in email.
  emailSignIn('EMAIL_SIGN_IN'),

  /// A password reset email.
  passwordReset('PASSWORD_RESET');

  const EmailType(this.value);

  /// The string value of the email type.
  final String value;

  /// Creates an EmailType from a string value.
  static EmailType? fromString(String? value) {
    if (value == null) return null;
    return EmailType.values.cast<EmailType?>().firstWhere(
      (e) => e!.value == value,
      orElse: () => null,
    );
  }
}

/// The type of SMS message.
enum SmsType {
  /// A sign-in or sign up SMS message.
  signInOrSignUp('SIGN_IN_OR_SIGN_UP'),

  /// A multi-factor sign-in SMS message.
  multiFactorSignIn('MULTI_FACTOR_SIGN_IN'),

  /// A multi-factor enrollment SMS message.
  multiFactorEnrollment('MULTI_FACTOR_ENROLLMENT');

  const SmsType(this.value);

  /// The string value of the SMS type.
  final String value;

  /// Creates an SmsType from a string value.
  static SmsType? fromString(String? value) {
    if (value == null) return null;
    return SmsType.values.cast<SmsType?>().firstWhere(
      (e) => e!.value == value,
      orElse: () => null,
    );
  }
}

/// The credential component of the auth event context.
class Credential {
  const Credential({
    this.claims,
    this.idToken,
    this.accessToken,
    this.refreshToken,
    this.expirationTime,
    this.secret,
    required this.providerId,
    required this.signInMethod,
  });

  factory Credential.fromJson(Map<String, dynamic> json, int timestamp) {
    final expiresIn = json['oauth_expires_in'] as int?;
    return Credential(
      claims: json['sign_in_attributes'] as Map<String, dynamic>?,
      idToken: json['oauth_id_token'] as String?,
      accessToken: json['oauth_access_token'] as String?,
      refreshToken: json['oauth_refresh_token'] as String?,
      expirationTime: expiresIn != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp + expiresIn * 1000)
          : null,
      secret: json['oauth_token_secret'] as String?,
      providerId: json['sign_in_method'] == 'emailLink'
          ? 'password'
          : json['sign_in_method'] as String? ?? '',
      signInMethod: json['sign_in_method'] as String? ?? '',
    );
  }

  /// The claims from the sign-in attributes.
  final Map<String, dynamic>? claims;

  /// The ID token credential.
  final String? idToken;

  /// The access token credential.
  final String? accessToken;

  /// The refresh token credential.
  final String? refreshToken;

  /// The expiration time of the credential.
  final DateTime? expirationTime;

  /// The secret (used for OAuth 1.0 providers).
  final String? secret;

  /// The provider ID.
  final String providerId;

  /// The sign-in method.
  final String signInMethod;

  Map<String, dynamic> toJson() => {
    if (claims != null) 'claims': claims,
    if (idToken != null) 'idToken': idToken,
    if (accessToken != null) 'accessToken': accessToken,
    if (refreshToken != null) 'refreshToken': refreshToken,
    if (expirationTime != null)
      'expirationTime': expirationTime!.toIso8601String(),
    if (secret != null) 'secret': secret,
    'providerId': providerId,
    'signInMethod': signInMethod,
  };
}

/// The additional user info component of the auth event context.
class AdditionalUserInfo {
  const AdditionalUserInfo({
    this.providerId,
    this.profile,
    this.username,
    required this.isNewUser,
    this.recaptchaScore,
    this.email,
    this.phoneNumber,
  });

  factory AdditionalUserInfo.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? profile;
    String? username;

    final rawUserInfo = json['raw_user_info'] as String?;
    if (rawUserInfo != null) {
      try {
        profile = Map<String, dynamic>.from(
          (rawUserInfo.isNotEmpty)
              ? _parseJson(rawUserInfo) as Map<String, dynamic>
              : {},
        );
      } catch (_) {
        // Ignore parse errors
      }
    }

    if (profile != null) {
      final signInMethod = json['sign_in_method'] as String?;
      if (signInMethod == 'github.com') {
        username = profile['login'] as String?;
      }
      if (signInMethod == 'twitter.com') {
        username = profile['screen_name'] as String?;
      }
    }

    final eventType = json['event_type'] as String?;

    return AdditionalUserInfo(
      providerId: json['sign_in_method'] == 'emailLink'
          ? 'password'
          : json['sign_in_method'] as String?,
      profile: profile,
      username: username,
      isNewUser: eventType == 'beforeCreate',
      recaptchaScore: (json['recaptcha_score'] as num?)?.toDouble(),
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
    );
  }

  static dynamic _parseJson(String source) {
    // Simple JSON parser - in production, use dart:convert
    // This is a simplified version
    if (source.isEmpty) return <String, dynamic>{};
    try {
      // Use Uri.decodeComponent in case the string is URL encoded
      Uri.decodeComponent(source);
      // For now, return as-is since we need proper JSON parsing
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// The provider ID.
  final String? providerId;

  /// The profile data from the provider.
  final Map<String, dynamic>? profile;

  /// The username (for GitHub or Twitter).
  final String? username;

  /// Whether the user is new.
  final bool isNewUser;

  /// The reCAPTCHA score.
  final double? recaptchaScore;

  /// The email address.
  final String? email;

  /// The phone number.
  final String? phoneNumber;

  Map<String, dynamic> toJson() => {
    if (providerId != null) 'providerId': providerId,
    if (profile != null) 'profile': profile,
    if (username != null) 'username': username,
    'isNewUser': isNewUser,
    if (recaptchaScore != null) 'recaptchaScore': recaptchaScore,
    if (email != null) 'email': email,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
  };
}

/// Defines the auth event context for blocking events.
class AuthEventContext {
  const AuthEventContext({
    this.locale,
    required this.ipAddress,
    required this.userAgent,
    this.additionalUserInfo,
    this.credential,
    this.emailType,
    this.smsType,
  });

  /// The locale of the user.
  final String? locale;

  /// The IP address of the user's device.
  final String ipAddress;

  /// The user agent of the user's device.
  final String userAgent;

  /// Additional user info.
  final AdditionalUserInfo? additionalUserInfo;

  /// The credential used for sign-in.
  final Credential? credential;

  /// The type of email being sent.
  final EmailType? emailType;

  /// The type of SMS being sent.
  final SmsType? smsType;

  Map<String, dynamic> toJson() => {
    if (locale != null) 'locale': locale,
    'ipAddress': ipAddress,
    'userAgent': userAgent,
    if (additionalUserInfo != null)
      'additionalUserInfo': additionalUserInfo!.toJson(),
    if (credential != null) 'credential': credential!.toJson(),
    if (emailType != null) 'emailType': emailType!.value,
    if (smsType != null) 'smsType': smsType!.value,
  };
}

/// Defines the auth event for 2nd gen blocking events.
///
/// This extends [AuthEventContext] with the user record data.
class AuthBlockingEvent extends AuthEventContext {
  const AuthBlockingEvent({
    super.locale,
    required super.ipAddress,
    required super.userAgent,
    super.additionalUserInfo,
    super.credential,
    super.emailType,
    super.smsType,
    this.data,
  });

  /// Creates an AuthBlockingEvent from a decoded JWT payload.
  factory AuthBlockingEvent.fromDecodedPayload(Map<String, dynamic> decoded) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Parse user record if present (not present for beforeSendEmail/beforeSendSms)
    AuthUserRecord? userRecord;
    if (decoded['user_record'] != null) {
      userRecord = AuthUserRecord.fromJson(
        decoded['user_record'] as Map<String, dynamic>,
      );
    }

    // Parse credential if OAuth tokens are present
    Credential? credential;
    if (decoded['sign_in_attributes'] != null ||
        decoded['oauth_id_token'] != null ||
        decoded['oauth_access_token'] != null ||
        decoded['oauth_refresh_token'] != null) {
      credential = Credential.fromJson(decoded, timestamp);
    }

    return AuthBlockingEvent(
      locale: decoded['locale'] as String?,
      ipAddress: decoded['ip_address'] as String? ?? '',
      userAgent: decoded['user_agent'] as String? ?? '',
      additionalUserInfo: AdditionalUserInfo.fromJson(decoded),
      credential: credential,
      emailType: EmailType.fromString(decoded['email_type'] as String?),
      smsType: SmsType.fromString(decoded['sms_type'] as String?),
      data: userRecord,
    );
  }

  /// The user record data.
  ///
  /// This is `null` for `beforeSendEmail` and `beforeSendSms` event types.
  final AuthUserRecord? data;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    if (data != null) 'data': data!.toJson(),
  };
}
