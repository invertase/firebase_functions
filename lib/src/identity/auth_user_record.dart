/// Auth user record types for Identity Platform blocking functions.
library;

/// User info that is part of the `AuthUserRecord`.
class AuthUserInfo {
  const AuthUserInfo({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoURL,
    required this.providerId,
    this.phoneNumber,
  });

  factory AuthUserInfo.fromJson(Map<String, dynamic> json) => AuthUserInfo(
        uid: json['uid'] as String? ?? json['raw_id'] as String? ?? '',
        displayName: json['displayName'] as String? ??
            json['display_name'] as String? ??
            '',
        email: json['email'] as String? ?? '',
        photoURL:
            json['photoURL'] as String? ?? json['photo_url'] as String? ?? '',
        providerId: json['providerId'] as String? ??
            json['provider_id'] as String? ??
            '',
        phoneNumber:
            json['phoneNumber'] as String? ?? json['phone_number'] as String?,
      );

  /// The user identifier for the linked provider.
  final String uid;

  /// The display name for the linked provider.
  final String displayName;

  /// The email for the linked provider.
  final String email;

  /// The photo URL for the linked provider.
  final String photoURL;

  /// The linked provider ID (for example, "google.com" for the Google provider).
  final String providerId;

  /// The phone number for the linked provider.
  final String? phoneNumber;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'photoURL': photoURL,
        'providerId': providerId,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      };
}

/// Additional metadata about the user.
class AuthUserMetadata {
  const AuthUserMetadata({
    required this.creationTime,
    this.lastSignInTime,
  });

  factory AuthUserMetadata.fromJson(Map<String, dynamic> json) {
    final creationTimeRaw = json['creationTime'] ?? json['creation_time'];
    final lastSignInTimeRaw =
        json['lastSignInTime'] ?? json['last_sign_in_time'];

    return AuthUserMetadata(
      creationTime: _parseDateTime(creationTimeRaw),
      lastSignInTime:
          lastSignInTimeRaw != null ? _parseDateTime(lastSignInTimeRaw) : null,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      // Try parsing as integer first (milliseconds since epoch)
      final asInt = int.tryParse(value);
      if (asInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      // Otherwise parse as ISO string
      return DateTime.parse(value);
    }
    throw ArgumentError('Invalid date format: $value');
  }

  /// The date the user was created.
  final DateTime creationTime;

  /// The date the user last signed in.
  final DateTime? lastSignInTime;

  Map<String, dynamic> toJson() => {
        'creationTime': creationTime.toIso8601String(),
        if (lastSignInTime != null)
          'lastSignInTime': lastSignInTime!.toIso8601String(),
      };
}

/// Interface representing the common properties of a user-enrolled second factor.
class AuthMultiFactorInfo {
  const AuthMultiFactorInfo({
    required this.uid,
    this.displayName,
    required this.factorId,
    this.enrollmentTime,
    this.phoneNumber,
  });

  factory AuthMultiFactorInfo.fromJson(Map<String, dynamic> json) =>
      AuthMultiFactorInfo(
        uid: json['uid'] as String,
        displayName:
            json['displayName'] as String? ?? json['display_name'] as String?,
        factorId: json['factorId'] as String? ??
            json['factor_id'] as String? ??
            'phone',
        enrollmentTime: json['enrollmentTime'] != null
            ? DateTime.parse(json['enrollmentTime'] as String)
            : json['enrollment_time'] != null
                ? DateTime.parse(json['enrollment_time'] as String)
                : null,
        phoneNumber:
            json['phoneNumber'] as String? ?? json['phone_number'] as String?,
      );

  /// The ID of the enrolled second factor. This ID is unique to the user.
  final String uid;

  /// The optional display name of the enrolled second factor.
  final String? displayName;

  /// The type identifier of the second factor. For SMS second factors, this is `phone`.
  final String factorId;

  /// The optional date the second factor was enrolled.
  final DateTime? enrollmentTime;

  /// The phone number associated with a phone second factor.
  final String? phoneNumber;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        if (displayName != null) 'displayName': displayName,
        'factorId': factorId,
        if (enrollmentTime != null)
          'enrollmentTime': enrollmentTime!.toIso8601String(),
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      };
}

/// The multi-factor related properties for the current user, if available.
class AuthMultiFactorSettings {
  const AuthMultiFactorSettings({
    required this.enrolledFactors,
  });

  factory AuthMultiFactorSettings.fromJson(Map<String, dynamic> json) {
    final factorsList = json['enrolledFactors'] as List<dynamic>? ??
        json['enrolled_factors'] as List<dynamic>? ??
        [];
    return AuthMultiFactorSettings(
      enrolledFactors: factorsList
          .cast<Map<String, dynamic>>()
          .map(AuthMultiFactorInfo.fromJson)
          .toList(),
    );
  }

  /// List of second factors enrolled with the current user.
  final List<AuthMultiFactorInfo> enrolledFactors;

  Map<String, dynamic> toJson() => {
        'enrolledFactors': enrolledFactors.map((e) => e.toJson()).toList(),
      };
}

/// The `UserRecord` passed to auth blocking functions from the identity platform.
class AuthUserRecord {
  const AuthUserRecord({
    required this.uid,
    this.email,
    this.emailVerified = false,
    this.displayName,
    this.photoURL,
    this.phoneNumber,
    this.disabled = false,
    required this.metadata,
    this.providerData = const [],
    this.passwordHash,
    this.passwordSalt,
    this.customClaims,
    this.tenantId,
    this.tokensValidAfterTime,
    this.multiFactor,
  });

  factory AuthUserRecord.fromJson(Map<String, dynamic> json) {
    final providerDataList = json['providerData'] as List<dynamic>? ??
        json['provider_data'] as List<dynamic>? ??
        [];

    return AuthUserRecord(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      emailVerified: json['emailVerified'] as bool? ??
          json['email_verified'] as bool? ??
          false,
      displayName:
          json['displayName'] as String? ?? json['display_name'] as String?,
      photoURL: json['photoURL'] as String? ?? json['photo_url'] as String?,
      phoneNumber:
          json['phoneNumber'] as String? ?? json['phone_number'] as String?,
      disabled: json['disabled'] as bool? ?? false,
      metadata: json['metadata'] != null
          ? AuthUserMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : AuthUserMetadata(creationTime: DateTime.now()),
      providerData: providerDataList
          .cast<Map<String, dynamic>>()
          .map(AuthUserInfo.fromJson)
          .toList(),
      passwordHash:
          json['passwordHash'] as String? ?? json['password_hash'] as String?,
      passwordSalt:
          json['passwordSalt'] as String? ?? json['password_salt'] as String?,
      customClaims: json['customClaims'] as Map<String, dynamic>? ??
          json['custom_claims'] as Map<String, dynamic>?,
      tenantId: json['tenantId'] as String? ?? json['tenant_id'] as String?,
      tokensValidAfterTime: json['tokensValidAfterTime'] != null
          ? DateTime.parse(json['tokensValidAfterTime'] as String)
          : json['tokens_valid_after_time'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  (json['tokens_valid_after_time'] as int) * 1000,
                )
              : null,
      multiFactor: json['multiFactor'] != null
          ? AuthMultiFactorSettings.fromJson(
              json['multiFactor'] as Map<String, dynamic>,
            )
          : json['multi_factor'] != null
              ? AuthMultiFactorSettings.fromJson(
                  json['multi_factor'] as Map<String, dynamic>,
                )
              : null,
    );
  }

  /// The user's `uid`.
  final String uid;

  /// The user's primary email, if set.
  final String? email;

  /// Whether or not the user's primary email is verified.
  final bool emailVerified;

  /// The user's display name.
  final String? displayName;

  /// The user's photo URL.
  final String? photoURL;

  /// The user's primary phone number, if set.
  final String? phoneNumber;

  /// Whether or not the user is disabled: `true` for disabled; `false` for enabled.
  final bool disabled;

  /// Additional metadata about the user.
  final AuthUserMetadata metadata;

  /// An array of providers (for example, Google, Facebook) linked to the user.
  final List<AuthUserInfo> providerData;

  /// The user's hashed password (base64-encoded).
  final String? passwordHash;

  /// The user's password salt (base64-encoded).
  final String? passwordSalt;

  /// The user's custom claims object if available, typically used to define
  /// user roles and propagated to an authenticated user's ID token.
  final Map<String, dynamic>? customClaims;

  /// The ID of the tenant the user belongs to, if available.
  final String? tenantId;

  /// The date the user's tokens are valid after.
  final DateTime? tokensValidAfterTime;

  /// The multi-factor related properties for the current user, if available.
  final AuthMultiFactorSettings? multiFactor;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        if (email != null) 'email': email,
        'emailVerified': emailVerified,
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        'disabled': disabled,
        'metadata': metadata.toJson(),
        'providerData': providerData.map((e) => e.toJson()).toList(),
        if (passwordHash != null) 'passwordHash': passwordHash,
        if (passwordSalt != null) 'passwordSalt': passwordSalt,
        if (customClaims != null) 'customClaims': customClaims,
        if (tenantId != null) 'tenantId': tenantId,
        if (tokensValidAfterTime != null)
          'tokensValidAfterTime': tokensValidAfterTime!.toIso8601String(),
        if (multiFactor != null) 'multiFactor': multiFactor!.toJson(),
      };
}
