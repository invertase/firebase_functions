import 'package:firebase_functions/firebase_functions.dart';
import 'package:test/test.dart';

void main() {
  group('AuthUserInfo', () {
    test('fromJson parses correctly', () {
      final json = {
        'uid': 'user-123',
        'displayName': 'Test User',
        'email': 'test@example.com',
        'photoURL': 'https://example.com/photo.jpg',
        'providerId': 'google.com',
        'phoneNumber': '+1234567890',
      };

      final userInfo = AuthUserInfo.fromJson(json);

      expect(userInfo.uid, 'user-123');
      expect(userInfo.displayName, 'Test User');
      expect(userInfo.email, 'test@example.com');
      expect(userInfo.photoURL, 'https://example.com/photo.jpg');
      expect(userInfo.providerId, 'google.com');
      expect(userInfo.phoneNumber, '+1234567890');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'uid': 'user-123',
        'providerId': 'password',
      };

      final userInfo = AuthUserInfo.fromJson(json);

      expect(userInfo.uid, 'user-123');
      expect(userInfo.displayName, '');
      expect(userInfo.email, '');
      expect(userInfo.photoURL, '');
      expect(userInfo.providerId, 'password');
      expect(userInfo.phoneNumber, isNull);
    });

    test('toJson round-trips correctly', () {
      const userInfo = AuthUserInfo(
        uid: 'user-456',
        displayName: 'Another User',
        email: 'another@example.com',
        photoURL: 'https://example.com/photo2.jpg',
        providerId: 'facebook.com',
        phoneNumber: '+0987654321',
      );

      final json = userInfo.toJson();
      final parsed = AuthUserInfo.fromJson(json);

      expect(parsed.uid, userInfo.uid);
      expect(parsed.displayName, userInfo.displayName);
      expect(parsed.email, userInfo.email);
      expect(parsed.photoURL, userInfo.photoURL);
      expect(parsed.providerId, userInfo.providerId);
      expect(parsed.phoneNumber, userInfo.phoneNumber);
    });
  });

  group('AuthUserMetadata', () {
    test('fromJson parses DateTime correctly', () {
      final json = {
        'creationTime': '2024-01-15T12:00:00.000Z',
        'lastSignInTime': '2024-01-16T14:30:00.000Z',
      };

      final metadata = AuthUserMetadata.fromJson(json);

      expect(metadata.creationTime, DateTime.utc(2024, 1, 15, 12));
      expect(metadata.lastSignInTime, DateTime.utc(2024, 1, 16, 14, 30));
    });

    test('fromJson handles missing lastSignInTime', () {
      final json = {
        'creationTime': '2024-01-15T12:00:00.000Z',
      };

      final metadata = AuthUserMetadata.fromJson(json);

      expect(metadata.creationTime, DateTime.utc(2024, 1, 15, 12));
      expect(metadata.lastSignInTime, isNull);
    });

    test('fromJson handles snake_case keys', () {
      final json = {
        'creation_time': 1705320000000, // Timestamp in ms
        'last_sign_in_time': 1705406400000,
      };

      final metadata = AuthUserMetadata.fromJson(json);

      expect(metadata.creationTime, isNotNull);
      expect(metadata.lastSignInTime, isNotNull);
    });

    test('toJson serializes correctly', () {
      final metadata = AuthUserMetadata(
        creationTime: DateTime.utc(2024, 1, 15, 12),
        lastSignInTime: DateTime.utc(2024, 1, 16, 14, 30),
      );

      final json = metadata.toJson();

      expect(json['creationTime'], '2024-01-15T12:00:00.000Z');
      expect(json['lastSignInTime'], '2024-01-16T14:30:00.000Z');
    });
  });

  group('AuthMultiFactorInfo', () {
    test('fromJson parses correctly', () {
      final json = {
        'uid': 'mfa-123',
        'displayName': 'My Phone',
        'factorId': 'phone',
        'enrollmentTime': '2024-01-10T10:00:00.000Z',
        'phoneNumber': '+1234567890',
      };

      final mfaInfo = AuthMultiFactorInfo.fromJson(json);

      expect(mfaInfo.uid, 'mfa-123');
      expect(mfaInfo.displayName, 'My Phone');
      expect(mfaInfo.factorId, 'phone');
      expect(mfaInfo.enrollmentTime, DateTime.utc(2024, 1, 10, 10));
      expect(mfaInfo.phoneNumber, '+1234567890');
    });

    test('fromJson handles snake_case keys', () {
      final json = {
        'uid': 'mfa-456',
        'display_name': 'Work Phone',
        'factor_id': 'phone',
        'enrollment_time': '2024-01-11T11:00:00.000Z',
        'phone_number': '+9876543210',
      };

      final mfaInfo = AuthMultiFactorInfo.fromJson(json);

      expect(mfaInfo.uid, 'mfa-456');
      expect(mfaInfo.displayName, 'Work Phone');
      expect(mfaInfo.factorId, 'phone');
      expect(mfaInfo.phoneNumber, '+9876543210');
    });

    test('fromJson defaults factorId to phone when not provided', () {
      final json = {
        'uid': 'mfa-789',
      };

      final mfaInfo = AuthMultiFactorInfo.fromJson(json);

      expect(mfaInfo.factorId, 'phone');
    });
  });

  group('AuthMultiFactorSettings', () {
    test('fromJson parses enrolled factors', () {
      final json = {
        'enrolledFactors': [
          {
            'uid': 'mfa-1',
            'displayName': 'Phone 1',
            'factorId': 'phone',
            'phoneNumber': '+1111111111',
          },
          {
            'uid': 'mfa-2',
            'displayName': 'Phone 2',
            'factorId': 'phone',
            'phoneNumber': '+2222222222',
          },
        ],
      };

      final settings = AuthMultiFactorSettings.fromJson(json);

      expect(settings.enrolledFactors.length, 2);
      expect(settings.enrolledFactors[0].uid, 'mfa-1');
      expect(settings.enrolledFactors[1].uid, 'mfa-2');
    });

    test('fromJson handles snake_case key', () {
      final json = {
        'enrolled_factors': [
          {
            'uid': 'mfa-3',
            'factor_id': 'phone',
          },
        ],
      };

      final settings = AuthMultiFactorSettings.fromJson(json);

      expect(settings.enrolledFactors.length, 1);
      expect(settings.enrolledFactors[0].uid, 'mfa-3');
    });

    test('fromJson handles empty factors list', () {
      final json = <String, dynamic>{};

      final settings = AuthMultiFactorSettings.fromJson(json);

      expect(settings.enrolledFactors, isEmpty);
    });
  });

  group('AuthUserRecord', () {
    test('fromJson parses complete user record', () {
      final json = {
        'uid': 'user-complete',
        'email': 'complete@example.com',
        'emailVerified': true,
        'displayName': 'Complete User',
        'photoURL': 'https://example.com/complete.jpg',
        'phoneNumber': '+1234567890',
        'disabled': false,
        'metadata': {
          'creationTime': '2024-01-01T00:00:00.000Z',
          'lastSignInTime': '2024-01-15T12:00:00.000Z',
        },
        'providerData': [
          {
            'uid': 'google-123',
            'providerId': 'google.com',
            'displayName': 'Complete User',
            'email': 'complete@gmail.com',
            'photoURL': 'https://google.com/photo.jpg',
          },
        ],
        'customClaims': {
          'admin': true,
          'role': 'superuser',
        },
        'tenantId': 'tenant-123',
      };

      final record = AuthUserRecord.fromJson(json);

      expect(record.uid, 'user-complete');
      expect(record.email, 'complete@example.com');
      expect(record.emailVerified, isTrue);
      expect(record.displayName, 'Complete User');
      expect(record.phoneNumber, '+1234567890');
      expect(record.disabled, isFalse);
      expect(record.providerData.length, 1);
      expect(record.providerData[0].providerId, 'google.com');
      expect(record.customClaims!['admin'], isTrue);
      expect(record.tenantId, 'tenant-123');
    });

    test('fromJson handles snake_case keys', () {
      final json = {
        'uid': 'user-snake',
        'email_verified': true,
        'display_name': 'Snake User',
        'photo_url': 'https://example.com/snake.jpg',
        'phone_number': '+9876543210',
        'password_hash': 'hash123',
        'password_salt': 'salt456',
        'custom_claims': {'level': 5},
        'tenant_id': 'tenant-snake',
        'tokens_valid_after_time': 1705320000,
        'metadata': {
          'creation_time': 1705320000000,
        },
        'provider_data': [],
        'multi_factor': {
          'enrolled_factors': [],
        },
      };

      final record = AuthUserRecord.fromJson(json);

      expect(record.uid, 'user-snake');
      expect(record.emailVerified, isTrue);
      expect(record.displayName, 'Snake User');
      expect(record.phoneNumber, '+9876543210');
      expect(record.passwordHash, 'hash123');
      expect(record.passwordSalt, 'salt456');
      expect(record.customClaims!['level'], 5);
      expect(record.tenantId, 'tenant-snake');
    });

    test('fromJson handles minimal user record', () {
      final json = {
        'uid': 'user-minimal',
      };

      final record = AuthUserRecord.fromJson(json);

      expect(record.uid, 'user-minimal');
      expect(record.email, isNull);
      expect(record.emailVerified, isFalse);
      expect(record.disabled, isFalse);
      expect(record.providerData, isEmpty);
    });

    test('toJson serializes correctly', () {
      final record = AuthUserRecord(
        uid: 'user-serial',
        email: 'serial@example.com',
        emailVerified: true,
        displayName: 'Serial User',
        metadata: AuthUserMetadata(
          creationTime: DateTime.utc(2024, 1, 15),
        ),
        customClaims: {'test': true},
      );

      final json = record.toJson();

      expect(json['uid'], 'user-serial');
      expect(json['email'], 'serial@example.com');
      expect(json['emailVerified'], isTrue);
      expect(json['displayName'], 'Serial User');
      expect(json['customClaims'], {'test': true});
    });
  });

  group('AuthBlockingEventType', () {
    test('has correct values', () {
      expect(AuthBlockingEventType.beforeCreate.value, 'beforeCreate');
      expect(AuthBlockingEventType.beforeSignIn.value, 'beforeSignIn');
      expect(AuthBlockingEventType.beforeSendEmail.value, 'beforeSendEmail');
      expect(AuthBlockingEventType.beforeSendSms.value, 'beforeSendSms');
    });

    test('has correct legacy event types', () {
      expect(
        AuthBlockingEventType.beforeCreate.legacyEventType,
        'providers/cloud.auth/eventTypes/user.beforeCreate',
      );
      expect(
        AuthBlockingEventType.beforeSignIn.legacyEventType,
        'providers/cloud.auth/eventTypes/user.beforeSignIn',
      );
      expect(
        AuthBlockingEventType.beforeSendEmail.legacyEventType,
        'providers/cloud.auth/eventTypes/user.beforeSendEmail',
      );
      expect(
        AuthBlockingEventType.beforeSendSms.legacyEventType,
        'providers/cloud.auth/eventTypes/user.beforeSendSms',
      );
    });
  });

  group('EmailType', () {
    test('has correct values', () {
      expect(EmailType.emailSignIn.value, 'EMAIL_SIGN_IN');
      expect(EmailType.passwordReset.value, 'PASSWORD_RESET');
    });

    test('fromString returns correct enum', () {
      expect(EmailType.fromString('EMAIL_SIGN_IN'), EmailType.emailSignIn);
      expect(EmailType.fromString('PASSWORD_RESET'), EmailType.passwordReset);
      expect(EmailType.fromString(null), isNull);
      expect(EmailType.fromString('INVALID'), isNull);
    });
  });

  group('SmsType', () {
    test('has correct values', () {
      expect(SmsType.signInOrSignUp.value, 'SIGN_IN_OR_SIGN_UP');
      expect(SmsType.multiFactorSignIn.value, 'MULTI_FACTOR_SIGN_IN');
      expect(SmsType.multiFactorEnrollment.value, 'MULTI_FACTOR_ENROLLMENT');
    });

    test('fromString returns correct enum', () {
      expect(SmsType.fromString('SIGN_IN_OR_SIGN_UP'), SmsType.signInOrSignUp);
      expect(
        SmsType.fromString('MULTI_FACTOR_SIGN_IN'),
        SmsType.multiFactorSignIn,
      );
      expect(
        SmsType.fromString('MULTI_FACTOR_ENROLLMENT'),
        SmsType.multiFactorEnrollment,
      );
      expect(SmsType.fromString(null), isNull);
      expect(SmsType.fromString('INVALID'), isNull);
    });
  });

  group('Credential', () {
    test('fromJson parses OAuth credentials', () {
      final json = {
        'sign_in_attributes': {'key': 'value'},
        'oauth_id_token': 'id-token-123',
        'oauth_access_token': 'access-token-456',
        'oauth_refresh_token': 'refresh-token-789',
        'oauth_expires_in': 3600,
        'oauth_token_secret': 'secret-abc',
        'sign_in_method': 'google.com',
      };
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final credential = Credential.fromJson(json, timestamp);

      expect(credential.claims, {'key': 'value'});
      expect(credential.idToken, 'id-token-123');
      expect(credential.accessToken, 'access-token-456');
      expect(credential.refreshToken, 'refresh-token-789');
      expect(credential.expirationTime, isNotNull);
      expect(credential.secret, 'secret-abc');
      expect(credential.providerId, 'google.com');
      expect(credential.signInMethod, 'google.com');
    });

    test('fromJson handles emailLink provider', () {
      final json = {
        'sign_in_method': 'emailLink',
      };
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final credential = Credential.fromJson(json, timestamp);

      expect(credential.providerId, 'password');
      expect(credential.signInMethod, 'emailLink');
    });
  });

  group('AdditionalUserInfo', () {
    test('fromJson sets isNewUser based on event type', () {
      final createJson = {
        'event_type': 'beforeCreate',
        'sign_in_method': 'password',
      };

      final signInJson = {
        'event_type': 'beforeSignIn',
        'sign_in_method': 'password',
      };

      final createInfo = AdditionalUserInfo.fromJson(createJson);
      final signInInfo = AdditionalUserInfo.fromJson(signInJson);

      expect(createInfo.isNewUser, isTrue);
      expect(signInInfo.isNewUser, isFalse);
    });

    test('fromJson handles emailLink provider', () {
      final json = {
        'event_type': 'beforeSignIn',
        'sign_in_method': 'emailLink',
      };

      final info = AdditionalUserInfo.fromJson(json);

      expect(info.providerId, 'password');
    });

    test('fromJson parses recaptcha score', () {
      final json = {
        'event_type': 'beforeCreate',
        'recaptcha_score': 0.9,
      };

      final info = AdditionalUserInfo.fromJson(json);

      expect(info.recaptchaScore, 0.9);
    });
  });

  group('AuthEventContext', () {
    test('toJson serializes all fields', () {
      final context = AuthEventContext(
        locale: 'en-US',
        ipAddress: '192.168.1.1',
        userAgent: 'Mozilla/5.0',
        emailType: EmailType.passwordReset,
        smsType: SmsType.signInOrSignUp,
      );

      final json = context.toJson();

      expect(json['locale'], 'en-US');
      expect(json['ipAddress'], '192.168.1.1');
      expect(json['userAgent'], 'Mozilla/5.0');
      expect(json['emailType'], 'PASSWORD_RESET');
      expect(json['smsType'], 'SIGN_IN_OR_SIGN_UP');
    });
  });

  group('AuthBlockingEvent', () {
    test('fromDecodedPayload parses beforeCreate event', () {
      final decoded = {
        'event_type': 'beforeCreate',
        'ip_address': '10.0.0.1',
        'user_agent': 'Test Agent',
        'locale': 'en',
        'user_record': {
          'uid': 'new-user',
          'email': 'new@example.com',
          'metadata': {
            'creation_time': DateTime.now().millisecondsSinceEpoch,
          },
        },
      };

      final event = AuthBlockingEvent.fromDecodedPayload(decoded);

      expect(event.ipAddress, '10.0.0.1');
      expect(event.userAgent, 'Test Agent');
      expect(event.locale, 'en');
      expect(event.data, isNotNull);
      expect(event.data!.uid, 'new-user');
      expect(event.data!.email, 'new@example.com');
      expect(event.additionalUserInfo!.isNewUser, isTrue);
    });

    test('fromDecodedPayload parses beforeSignIn event', () {
      final decoded = {
        'event_type': 'beforeSignIn',
        'ip_address': '10.0.0.2',
        'user_agent': 'Another Agent',
        'sign_in_method': 'google.com',
        'user_record': {
          'uid': 'existing-user',
          'metadata': {
            'creation_time': DateTime.now().millisecondsSinceEpoch,
          },
        },
        'oauth_access_token': 'token-xyz',
      };

      final event = AuthBlockingEvent.fromDecodedPayload(decoded);

      expect(event.data!.uid, 'existing-user');
      expect(event.additionalUserInfo!.isNewUser, isFalse);
      expect(event.credential, isNotNull);
      expect(event.credential!.accessToken, 'token-xyz');
    });

    test('fromDecodedPayload parses beforeSendEmail event (no user record)',
        () {
      final decoded = {
        'event_type': 'beforeSendEmail',
        'ip_address': '10.0.0.3',
        'user_agent': 'Email Agent',
        'email': 'reset@example.com',
        'email_type': 'PASSWORD_RESET',
      };

      final event = AuthBlockingEvent.fromDecodedPayload(decoded);

      expect(event.data, isNull);
      expect(event.emailType, EmailType.passwordReset);
      expect(event.additionalUserInfo!.email, 'reset@example.com');
    });

    test('fromDecodedPayload parses beforeSendSms event (no user record)', () {
      final decoded = {
        'event_type': 'beforeSendSms',
        'ip_address': '10.0.0.4',
        'user_agent': 'SMS Agent',
        'phone_number': '+1234567890',
        'sms_type': 'MULTI_FACTOR_SIGN_IN',
      };

      final event = AuthBlockingEvent.fromDecodedPayload(decoded);

      expect(event.data, isNull);
      expect(event.smsType, SmsType.multiFactorSignIn);
      expect(event.additionalUserInfo!.phoneNumber, '+1234567890');
    });
  });

  group('RecaptchaActionOptions', () {
    test('has correct values', () {
      expect(RecaptchaActionOptions.allow.value, 'ALLOW');
      expect(RecaptchaActionOptions.block.value, 'BLOCK');
    });
  });

  group('BeforeEmailResponse', () {
    test('toJson serializes recaptchaActionOverride', () {
      const response = BeforeEmailResponse(
        recaptchaActionOverride: RecaptchaActionOptions.block,
      );

      final json = response.toJson();

      expect(json['recaptchaActionOverride'], 'BLOCK');
    });

    test('toJson omits null fields', () {
      const response = BeforeEmailResponse();

      final json = response.toJson();

      expect(json.containsKey('recaptchaActionOverride'), isFalse);
    });
  });

  group('BeforeSmsResponse', () {
    test('toJson serializes correctly', () {
      const response = BeforeSmsResponse(
        recaptchaActionOverride: RecaptchaActionOptions.allow,
      );

      final json = response.toJson();

      expect(json['recaptchaActionOverride'], 'ALLOW');
    });
  });

  group('BeforeCreateResponse', () {
    test('toJson serializes all fields', () {
      const response = BeforeCreateResponse(
        displayName: 'New Name',
        disabled: false,
        emailVerified: true,
        photoURL: 'https://example.com/new-photo.jpg',
        customClaims: {'role': 'admin'},
        recaptchaActionOverride: RecaptchaActionOptions.allow,
      );

      final json = response.toJson();

      expect(json['displayName'], 'New Name');
      expect(json['disabled'], isFalse);
      expect(json['emailVerified'], isTrue);
      expect(json['photoURL'], 'https://example.com/new-photo.jpg');
      expect(json['customClaims'], {'role': 'admin'});
      expect(json['recaptchaActionOverride'], 'ALLOW');
    });

    test('toJson omits null fields', () {
      const response = BeforeCreateResponse(
        displayName: 'Only Name',
      );

      final json = response.toJson();

      expect(json['displayName'], 'Only Name');
      expect(json.containsKey('disabled'), isFalse);
      expect(json.containsKey('emailVerified'), isFalse);
    });
  });

  group('BeforeSignInResponse', () {
    test('toJson includes sessionClaims', () {
      const response = BeforeSignInResponse(
        displayName: 'Sign In User',
        customClaims: {'persistent': true},
        sessionClaims: {'session': 'temp'},
      );

      final json = response.toJson();

      expect(json['displayName'], 'Sign In User');
      expect(json['customClaims'], {'persistent': true});
      expect(json['sessionClaims'], {'session': 'temp'});
    });
  });

  group('generateResponsePayload', () {
    test('generates empty payload for null response', () {
      final payload = generateResponsePayload(null);

      expect(payload.userRecord, isNull);
      expect(payload.recaptchaActionOverride, isNull);
    });

    test('generates payload for BeforeCreateResponse', () {
      const response = BeforeCreateResponse(
        displayName: 'Created User',
        emailVerified: true,
        recaptchaActionOverride: RecaptchaActionOptions.allow,
      );

      final payload = generateResponsePayload(response);

      expect(payload.userRecord, isNotNull);
      expect(payload.userRecord!.displayName, 'Created User');
      expect(payload.userRecord!.emailVerified, isTrue);
      expect(payload.userRecord!.updateMask, contains('displayName'));
      expect(payload.userRecord!.updateMask, contains('emailVerified'));
      expect(payload.recaptchaActionOverride, RecaptchaActionOptions.allow);
    });

    test('generates payload for BeforeSignInResponse with sessionClaims', () {
      const response = BeforeSignInResponse(
        sessionClaims: {'lastLogin': '2024-01-15'},
      );

      final payload = generateResponsePayload(response);

      expect(payload.userRecord, isNotNull);
      expect(payload.userRecord!.sessionClaims, {'lastLogin': '2024-01-15'});
      expect(payload.userRecord!.updateMask, 'sessionClaims');
    });

    test('generates payload for BeforeEmailResponse', () {
      const response = BeforeEmailResponse(
        recaptchaActionOverride: RecaptchaActionOptions.block,
      );

      final payload = generateResponsePayload(response);

      expect(payload.userRecord, isNull);
      expect(payload.recaptchaActionOverride, RecaptchaActionOptions.block);
    });

    test('generates payload for BeforeSmsResponse', () {
      const response = BeforeSmsResponse(
        recaptchaActionOverride: RecaptchaActionOptions.allow,
      );

      final payload = generateResponsePayload(response);

      expect(payload.userRecord, isNull);
      expect(payload.recaptchaActionOverride, RecaptchaActionOptions.allow);
    });
  });

  group('BlockingOptions', () {
    test('can be created with token options', () {
      const options = BlockingOptions(
        idToken: true,
        accessToken: true,
        refreshToken: true,
      );

      expect(options.idToken, isTrue);
      expect(options.accessToken, isTrue);
      expect(options.refreshToken, isTrue);
    });

    test('can be created with GlobalOptions', () {
      const options = BlockingOptions(
        idToken: true,
        region: DeployOption(SupportedRegion.usCentral1),
        memory: Memory(MemoryOption.mb512),
        timeoutSeconds: DeployOption(60),
      );

      expect(options.idToken, isTrue);
      expect(options.region, isNotNull);
      expect(options.memory, isNotNull);
      expect(options.timeoutSeconds, isNotNull);
    });
  });

  group('getInternalOptions', () {
    test('extracts options correctly', () {
      const blockingOptions = BlockingOptions(
        idToken: true,
        accessToken: false,
        refreshToken: true,
        memory: Memory(MemoryOption.mb256),
      );

      final internal = getInternalOptions(blockingOptions);

      expect(internal.idToken, isTrue);
      expect(internal.accessToken, isFalse);
      expect(internal.refreshToken, isTrue);
      expect(internal.opts.memory, isNotNull);
    });

    test('defaults tokens to false when not specified', () {
      const blockingOptions = BlockingOptions();

      final internal = getInternalOptions(blockingOptions);

      expect(internal.idToken, isFalse);
      expect(internal.accessToken, isFalse);
      expect(internal.refreshToken, isFalse);
    });

    test('handles null options', () {
      final internal = getInternalOptions(null);

      expect(internal.idToken, isFalse);
      expect(internal.accessToken, isFalse);
      expect(internal.refreshToken, isFalse);
    });
  });
}
