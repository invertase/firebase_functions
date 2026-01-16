/// Response types for Identity Platform blocking functions.
library;

/// The reCAPTCHA action options.
enum RecaptchaActionOptions {
  /// Allow the operation to proceed.
  allow('ALLOW'),

  /// Block the operation.
  block('BLOCK');

  const RecaptchaActionOptions(this.value);

  /// The string value of the action.
  final String value;
}

/// Base class for auth methods "beforeX".
///
/// This is a sealed class that serves as the base for all before response types.
sealed class BeforeResponse {
  const BeforeResponse();

  /// Converts the response to a JSON map for the identity platform.
  Map<String, dynamic> toJson();
}

/// The handler response type for `beforeEmailSent` blocking events.
class BeforeEmailResponse extends BeforeResponse {
  const BeforeEmailResponse({
    this.recaptchaActionOverride,
  });

  /// Override the reCAPTCHA action.
  final RecaptchaActionOptions? recaptchaActionOverride;

  @override
  Map<String, dynamic> toJson() => {
        if (recaptchaActionOverride != null)
          'recaptchaActionOverride': recaptchaActionOverride!.value,
      };
}

/// The handler response type for `beforeSmsSent` blocking events.
class BeforeSmsResponse extends BeforeResponse {
  const BeforeSmsResponse({
    this.recaptchaActionOverride,
  });

  /// Override the reCAPTCHA action.
  final RecaptchaActionOptions? recaptchaActionOverride;

  @override
  Map<String, dynamic> toJson() => {
        if (recaptchaActionOverride != null)
          'recaptchaActionOverride': recaptchaActionOverride!.value,
      };
}

/// The handler response type for `beforeUserCreated` blocking events.
class BeforeCreateResponse extends BeforeResponse {
  const BeforeCreateResponse({
    this.displayName,
    this.disabled,
    this.emailVerified,
    this.photoURL,
    this.customClaims,
    this.recaptchaActionOverride,
  });

  /// The display name to set on the user.
  final String? displayName;

  /// Whether to disable the user.
  final bool? disabled;

  /// Whether the user's email is verified.
  final bool? emailVerified;

  /// The photo URL to set on the user.
  final String? photoURL;

  /// Custom claims to set on the user.
  final Map<String, dynamic>? customClaims;

  /// Override the reCAPTCHA action.
  final RecaptchaActionOptions? recaptchaActionOverride;

  @override
  Map<String, dynamic> toJson() => {
        if (displayName != null) 'displayName': displayName,
        if (disabled != null) 'disabled': disabled,
        if (emailVerified != null) 'emailVerified': emailVerified,
        if (photoURL != null) 'photoURL': photoURL,
        if (customClaims != null) 'customClaims': customClaims,
        if (recaptchaActionOverride != null)
          'recaptchaActionOverride': recaptchaActionOverride!.value,
      };
}

/// The handler response type for `beforeUserSignedIn` blocking events.
class BeforeSignInResponse extends BeforeCreateResponse {
  const BeforeSignInResponse({
    super.displayName,
    super.disabled,
    super.emailVerified,
    super.photoURL,
    super.customClaims,
    super.recaptchaActionOverride,
    this.sessionClaims,
  });

  /// Session claims to add to the ID token.
  final Map<String, dynamic>? sessionClaims;

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        if (sessionClaims != null) 'sessionClaims': sessionClaims,
      };
}

/// Internal class used when generating the response payload.
class ResponsePayload {
  const ResponsePayload({
    this.userRecord,
    this.recaptchaActionOverride,
  });

  /// The user record response.
  final UserRecordResponsePayload? userRecord;

  /// Override the reCAPTCHA action.
  final RecaptchaActionOptions? recaptchaActionOverride;

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};

    if (userRecord != null) {
      result['userRecord'] = userRecord!.toJson();
    }

    if (recaptchaActionOverride != null) {
      result['recaptchaActionOverride'] = recaptchaActionOverride!.value;
    }

    return result;
  }
}

/// The user record portion of the response payload.
class UserRecordResponsePayload {
  const UserRecordResponsePayload({
    this.displayName,
    this.disabled,
    this.emailVerified,
    this.photoURL,
    this.customClaims,
    this.sessionClaims,
    required this.updateMask,
  });

  final String? displayName;
  final bool? disabled;
  final bool? emailVerified;
  final String? photoURL;
  final Map<String, dynamic>? customClaims;
  final Map<String, dynamic>? sessionClaims;
  final String updateMask;

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};

    if (displayName != null) result['displayName'] = displayName;
    if (disabled != null) result['disabled'] = disabled;
    if (emailVerified != null) result['emailVerified'] = emailVerified;
    if (photoURL != null) result['photoURL'] = photoURL;
    if (customClaims != null) result['customClaims'] = customClaims;
    if (sessionClaims != null) result['sessionClaims'] = sessionClaims;
    result['updateMask'] = updateMask;

    return result;
  }
}

/// Helper to generate a response from the blocking function to the Firebase Auth backend.
ResponsePayload generateResponsePayload(BeforeResponse? authResponse) {
  if (authResponse == null) {
    return const ResponsePayload();
  }

  RecaptchaActionOptions? recaptchaActionOverride;
  Map<String, dynamic> formattedResponse;

  if (authResponse is BeforeEmailResponse) {
    recaptchaActionOverride = authResponse.recaptchaActionOverride;
    formattedResponse = {};
  } else if (authResponse is BeforeSmsResponse) {
    recaptchaActionOverride = authResponse.recaptchaActionOverride;
    formattedResponse = {};
  } else if (authResponse is BeforeSignInResponse) {
    recaptchaActionOverride = authResponse.recaptchaActionOverride;
    formattedResponse = {
      if (authResponse.displayName != null)
        'displayName': authResponse.displayName,
      if (authResponse.disabled != null) 'disabled': authResponse.disabled,
      if (authResponse.emailVerified != null)
        'emailVerified': authResponse.emailVerified,
      if (authResponse.photoURL != null) 'photoURL': authResponse.photoURL,
      if (authResponse.customClaims != null)
        'customClaims': authResponse.customClaims,
      if (authResponse.sessionClaims != null)
        'sessionClaims': authResponse.sessionClaims,
    };
  } else if (authResponse is BeforeCreateResponse) {
    recaptchaActionOverride = authResponse.recaptchaActionOverride;
    formattedResponse = {
      if (authResponse.displayName != null)
        'displayName': authResponse.displayName,
      if (authResponse.disabled != null) 'disabled': authResponse.disabled,
      if (authResponse.emailVerified != null)
        'emailVerified': authResponse.emailVerified,
      if (authResponse.photoURL != null) 'photoURL': authResponse.photoURL,
      if (authResponse.customClaims != null)
        'customClaims': authResponse.customClaims,
    };
  } else {
    formattedResponse = {};
  }

  final updateMask = _getUpdateMask(formattedResponse);

  UserRecordResponsePayload? userRecord;
  if (updateMask.isNotEmpty) {
    userRecord = UserRecordResponsePayload(
      displayName: formattedResponse['displayName'] as String?,
      disabled: formattedResponse['disabled'] as bool?,
      emailVerified: formattedResponse['emailVerified'] as bool?,
      photoURL: formattedResponse['photoURL'] as String?,
      customClaims: formattedResponse['customClaims'] as Map<String, dynamic>?,
      sessionClaims:
          formattedResponse['sessionClaims'] as Map<String, dynamic>?,
      updateMask: updateMask,
    );
  }

  return ResponsePayload(
    userRecord: userRecord,
    recaptchaActionOverride: recaptchaActionOverride,
  );
}

/// Helper function to generate the update mask for the identity platform changed values.
String _getUpdateMask(Map<String, dynamic> authResponse) {
  final updateMask = <String>[];
  for (final key in authResponse.keys) {
    if (authResponse[key] != null) {
      updateMask.add(key);
    }
  }
  return updateMask.join(',');
}
