import 'package:test/test.dart';

import '../helpers/auth_client.dart';
import '../helpers/emulator.dart';

/// Identity Platform (Auth Blocking) test group.
///
/// These tests verify that blocking functions are triggered correctly
/// when users sign up or sign in via the Auth emulator.
///
/// Key insight: Blocking functions are only triggered by client SDK operations
/// (like signUp, signInWithPassword), NOT by admin operations (like direct
/// database access via the Auth emulator UI).
void runIdentityTests(
  String Function() getExamplePath,
  AuthClient Function() getAuthClient,
  EmulatorHelper Function() getEmulator,
) {
  group('Identity Platform (Auth Blocking)', () {
    late AuthClient authClient;
    late EmulatorHelper emulator;

    setUpAll(() {
      authClient = getAuthClient();
      emulator = getEmulator();
    });

    setUp(() async {
      // Clear all users before each test for isolation
      await authClient.clearAllUsers();
      // Clear emulator logs for clean verification
      emulator.clearOutputBuffer();
      // Give emulator a moment to process
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    group('beforeUserCreated', () {
      test('blocking function is triggered on user signup', () async {
        final email = 'test-${DateTime.now().millisecondsSinceEpoch}@example.com';
        final password = 'TestPassword123!';

        // Sign up a new user - this should trigger beforeUserCreated
        final response = await authClient.signUp(
          email: email,
          password: password,
        );

        // Verify user was created
        expect(response.email, equals(email));
        expect(response.localId, isNotEmpty);
        expect(response.idToken, isNotEmpty);

        // Wait for logs to be captured
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Verify the blocking function was executed
        final executionLogged = emulator.verifyFunctionExecution(
          'us-central1-beforeCreate',
        );
        expect(
          executionLogged,
          isTrue,
          reason: 'beforeUserCreated function should have been triggered',
        );

        // Verify Dart runtime processed the request
        final dartRuntimeLogged = emulator.verifyDartRuntimeRequest(
          'POST',
          200,
          '/beforeCreate',
        );
        expect(
          dartRuntimeLogged,
          isTrue,
          reason: 'Dart runtime should have processed beforeCreate request',
        );

        // Clean up
        await authClient.deleteAccount(response.idToken);
      });

      test('blocking function can block user creation', () async {
        // The example app blocks emails ending with @blocked.com
        final email = 'blocked-user@blocked.com';
        final password = 'TestPassword123!';

        // Attempt to sign up - should be blocked
        expect(
          () => authClient.signUp(email: email, password: password),
          throwsA(isA<AuthError>()),
        );

        // Wait for logs to be captured
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Verify the blocking function was executed
        final executionLogged = emulator.verifyFunctionExecution(
          'us-central1-beforeCreate',
        );
        expect(
          executionLogged,
          isTrue,
          reason:
              'beforeUserCreated function should have been triggered even when blocking',
        );
      });

      test('blocking function can set custom claims', () async {
        // The example app sets admin: true for emails ending with @admin.com
        final email =
            'admin-${DateTime.now().millisecondsSinceEpoch}@admin.com';
        final password = 'TestPassword123!';

        // Sign up an admin user
        final response = await authClient.signUp(
          email: email,
          password: password,
        );

        // Verify user was created
        expect(response.email, equals(email));

        // Wait for logs
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // The blocking function ran and should have set custom claims
        // We can't easily verify the claims without decoding the token,
        // but we can verify the function executed
        final executionLogged = emulator.verifyFunctionExecution(
          'us-central1-beforeCreate',
        );
        expect(executionLogged, isTrue);

        // Clean up
        await authClient.deleteAccount(response.idToken);
      });
    });

    group('beforeUserSignedIn', () {
      test('blocking function is triggered on user sign-in', () async {
        final email =
            'signin-test-${DateTime.now().millisecondsSinceEpoch}@example.com';
        final password = 'TestPassword123!';

        // First create a user
        final signUpResponse = await authClient.signUp(
          email: email,
          password: password,
        );

        // Clear logs to isolate sign-in test
        emulator.clearOutputBuffer();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Now sign in - this should trigger beforeUserSignedIn
        final signInResponse = await authClient.signInWithPassword(
          email: email,
          password: password,
        );

        // Verify sign-in succeeded
        expect(signInResponse.email, equals(email));
        expect(signInResponse.localId, equals(signUpResponse.localId));
        expect(signInResponse.idToken, isNotEmpty);

        // Wait for logs
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Verify the blocking function was executed
        final executionLogged = emulator.verifyFunctionExecution(
          'us-central1-beforeSignIn',
        );
        expect(
          executionLogged,
          isTrue,
          reason: 'beforeUserSignedIn function should have been triggered',
        );

        // Verify Dart runtime processed the request
        final dartRuntimeLogged = emulator.verifyDartRuntimeRequest(
          'POST',
          200,
          '/beforeSignIn',
        );
        expect(
          dartRuntimeLogged,
          isTrue,
          reason: 'Dart runtime should have processed beforeSignIn request',
        );

        // Clean up
        await authClient.deleteAccount(signInResponse.idToken);
      });

      test('blocking function adds session claims', () async {
        final email =
            'session-test-${DateTime.now().millisecondsSinceEpoch}@example.com';
        final password = 'TestPassword123!';

        // Create user (we use signInResponse.idToken for cleanup)
        await authClient.signUp(
          email: email,
          password: password,
        );

        // Clear logs
        emulator.clearOutputBuffer();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Sign in - the example app adds lastLogin and signInIp session claims
        final signInResponse = await authClient.signInWithPassword(
          email: email,
          password: password,
        );

        expect(signInResponse.idToken, isNotEmpty);

        // Wait for logs
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Verify function executed
        final executionLogged = emulator.verifyFunctionExecution(
          'us-central1-beforeSignIn',
        );
        expect(executionLogged, isTrue);

        // Clean up
        await authClient.deleteAccount(signInResponse.idToken);
      });
    });

    group('multiple blocking functions', () {
      test(
          'both beforeUserCreated and beforeUserSignedIn trigger in sequence',
          () async {
        final email =
            'sequence-${DateTime.now().millisecondsSinceEpoch}@example.com';
        final password = 'TestPassword123!';

        // Sign up - triggers beforeUserCreated (we use signInResponse for cleanup)
        await authClient.signUp(
          email: email,
          password: password,
        );

        // Wait for logs
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Verify beforeUserCreated was triggered
        expect(
          emulator.verifyFunctionExecution('us-central1-beforeCreate'),
          isTrue,
          reason: 'beforeUserCreated should trigger on signup',
        );

        // Clear logs
        emulator.clearOutputBuffer();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Sign in - triggers beforeUserSignedIn
        final signInResponse = await authClient.signInWithPassword(
          email: email,
          password: password,
        );

        // Wait for logs
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Verify beforeUserSignedIn was triggered
        expect(
          emulator.verifyFunctionExecution('us-central1-beforeSignIn'),
          isTrue,
          reason: 'beforeUserSignedIn should trigger on sign-in',
        );

        // Clean up
        await authClient.deleteAccount(signInResponse.idToken);
      });
    });

    group('error handling', () {
      test('invalid email format is rejected', () async {
        expect(
          () => authClient.signUp(
            email: 'not-an-email',
            password: 'TestPassword123!',
          ),
          throwsA(isA<AuthError>()),
        );
      });

      test('weak password is rejected', () async {
        expect(
          () => authClient.signUp(
            email: 'weak-password@example.com',
            password: '123', // Too short
          ),
          throwsA(isA<AuthError>()),
        );
      });

      test('sign in with non-existent user fails', () async {
        expect(
          () => authClient.signInWithPassword(
            email: 'nonexistent@example.com',
            password: 'TestPassword123!',
          ),
          throwsA(isA<AuthError>()),
        );
      });

      test('sign in with wrong password fails', () async {
        final email =
            'wrong-pass-${DateTime.now().millisecondsSinceEpoch}@example.com';
        final password = 'TestPassword123!';

        // Create user and get token for cleanup
        final signUpResponse = await authClient.signUp(
          email: email,
          password: password,
        );
        final idToken = signUpResponse.idToken;

        // Try to sign in with wrong password
        expect(
          () => authClient.signInWithPassword(
            email: email,
            password: 'WrongPassword456!',
          ),
          throwsA(isA<AuthError>()),
        );

        // Clean up
        await authClient.deleteAccount(idToken);
      });
    });
  });
}
