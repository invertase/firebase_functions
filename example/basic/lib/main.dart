import 'package:firebase_functions/firebase_functions.dart';

// =============================================================================
// Parameterized Configuration Examples
// =============================================================================

// Define parameters - these are read from environment variables at runtime
// and can be configured at deploy time via .env files or CLI prompts.
final welcomeMessage = defineString(
  'WELCOME_MESSAGE',
  ParamOptions(
    defaultValue: 'Hello from Dart Functions!',
    label: 'Welcome Message',
    description: 'The greeting message returned by the helloWorld function',
  ),
);

final minInstances = defineInt(
  'MIN_INSTANCES',
  ParamOptions(
    defaultValue: 0,
    label: 'Minimum Instances',
    description: 'Minimum number of instances to keep warm',
  ),
);

final isProduction = defineBoolean(
  'IS_PRODUCTION',
  ParamOptions(
    defaultValue: false,
    description: 'Whether this is a production deployment',
  ),
);

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // ==========================================================================
    // HTTPS Callable Functions (onCall / onCallWithData)
    // ==========================================================================

    // Basic callable function - untyped data
    firebase.https.onCall(name: 'greet', (request, response) async {
      final data = request.data as Map<String, dynamic>?;
      final name = data?['name'] ?? 'World';
      return CallableResult({'message': 'Hello, $name!'});
    });

    // Callable function with typed data using fromJson
    firebase.https.onCallWithData<GreetRequest, GreetResponse>(
      name: 'greetTyped',
      fromJson: GreetRequest.fromJson,
      (request, response) async {
        return GreetResponse(message: 'Hello, ${request.data.name}!');
      },
    );

    // Callable function demonstrating error handling
    firebase.https.onCall(name: 'divide', (request, response) async {
      final data = request.data as Map<String, dynamic>?;
      final a = (data?['a'] as num?)?.toDouble();
      final b = (data?['b'] as num?)?.toDouble();

      if (a == null || b == null) {
        throw InvalidArgumentError('Both "a" and "b" are required');
      }

      if (b == 0) {
        throw FailedPreconditionError('Cannot divide by zero');
      }

      return CallableResult({'result': a / b});
    });

    // Callable function demonstrating auth data extraction
    firebase.https.onCall(name: 'getAuthInfo', (request, response) async {
      final auth = request.auth;

      if (auth == null) {
        // User is not authenticated
        return CallableResult({
          'authenticated': false,
          'message': 'No authentication provided',
        });
      }

      // User is authenticated - return auth info
      return CallableResult({
        'authenticated': true,
        'uid': auth.uid,
        'token': auth.token, // Decoded JWT claims (email, name, etc.)
        // Note: auth.rawToken contains the raw JWT string if needed
      });
    });

    // Callable function with streaming support
    firebase.https.onCall(
      name: 'countdown',
      options: const CallableOptions(
        heartBeatIntervalSeconds: HeartBeatIntervalSeconds(5),
      ),
      (request, response) async {
        final data = request.data as Map<String, dynamic>?;
        final start = (data?['start'] as num?)?.toInt() ?? 10;

        // Stream countdown if client supports it
        if (request.acceptsStreaming) {
          for (var i = start; i >= 0; i--) {
            await response.sendChunk({'count': i});
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }

        return CallableResult({'message': 'Countdown complete!'});
      },
    );

    // ==========================================================================
    // HTTPS onRequest Functions
    // ==========================================================================

    // HTTPS onRequest example - using parameterized configuration
    firebase.https.onRequest(
      name: 'helloWorld',
      // ignore: non_const_argument_for_const_parameter
      options: HttpsOptions(
        // Use parameters in options - evaluated at deploy time
        minInstances: DeployOption.param(minInstances),
      ),
      (request) async {
        // Access parameter value at runtime
        return Response.ok(welcomeMessage.value());
      },
    );

    // Conditional configuration based on boolean parameter
    firebase.https.onRequest(
      name: 'configuredEndpoint',
      // ignore: non_const_argument_for_const_parameter
      options: HttpsOptions(
        // Use thenElse for conditional configuration at deploy time
        // isProduction.thenElse(trueValue, falseValue) returns an expression
        memory: Memory.expression(isProduction.thenElse(2048, 512)),
      ),
      (request) async {
        // Access parameter value at runtime
        final env = isProduction.value() ? 'production' : 'development';
        return Response.ok('Running in $env mode');
      },
    );

    // Pub/Sub trigger example
    firebase.pubsub.onMessagePublished(topic: 'my-topic', (event) async {
      final message = event.data;
      print('Received Pub/Sub message:');
      print('  ID: ${message?.messageId}');
      print('  Published: ${message?.publishTime}');
      print('  Data: ${message?.textData}');
      print('  Attributes: ${message?.attributes}');
    });

    // Firestore trigger examples
    firebase.firestore.onDocumentCreated(document: 'users/{userId}', (
      event,
    ) async {
      final data = event.data?.data();
      print('Document created: users/${event.params['userId']}');
      print('  Name: ${data?['name']}');
      print('  Email: ${data?['email']}');
    });

    firebase.firestore.onDocumentUpdated(document: 'users/{userId}', (
      event,
    ) async {
      final before = event.data?.before?.data();
      final after = event.data?.after?.data();
      print('Document updated: users/${event.params['userId']}');
      print('  Before: $before');
      print('  After: $after');
    });

    firebase.firestore.onDocumentDeleted(document: 'users/{userId}', (
      event,
    ) async {
      final data = event.data?.data();
      print('Document deleted: users/${event.params['userId']}');
      print('  Final data: $data');
    });

    firebase.firestore.onDocumentWritten(document: 'users/{userId}', (
      event,
    ) async {
      final before = event.data?.before?.data();
      final after = event.data?.after?.data();
      print('Document written: users/${event.params['userId']}');
      if (before == null && after != null) {
        print('  Operation: CREATE');
      } else if (before != null && after != null) {
        print('  Operation: UPDATE');
      } else if (before != null && after == null) {
        print('  Operation: DELETE');
      }
    });

    // Nested collection trigger example
    firebase.firestore.onDocumentCreated(
      document: 'posts/{postId}/comments/{commentId}',
      (event) async {
        final data = event.data?.data();
        print(
          'Comment created: posts/${event.params['postId']}/comments/${event.params['commentId']}',
        );
        print('  Text: ${data?['text']}');
        print('  Author: ${data?['author']}');
      },
    );

    // ==========================================================================
    // Realtime Database trigger examples
    // ==========================================================================

    // Database onValueCreated - triggers when data is created
    firebase.database.onValueCreated(ref: 'messages/{messageId}', (
      event,
    ) async {
      final data = event.data?.val();
      print('Database value created: messages/${event.params['messageId']}');
      print('  Data: $data');
      print('  Instance: ${event.instance}');
      print('  Ref: ${event.ref}');
    });

    // Database onValueUpdated - triggers when data is updated
    firebase.database.onValueUpdated(ref: 'messages/{messageId}', (
      event,
    ) async {
      final before = event.data?.before?.val();
      final after = event.data?.after?.val();
      print('Database value updated: messages/${event.params['messageId']}');
      print('  Before: $before');
      print('  After: $after');
    });

    // Database onValueDeleted - triggers when data is deleted
    firebase.database.onValueDeleted(ref: 'messages/{messageId}', (
      event,
    ) async {
      final data = event.data?.val();
      print('Database value deleted: messages/${event.params['messageId']}');
      print('  Final data: $data');
    });

    // Database onValueWritten - triggers on any write (create, update, delete)
    firebase.database.onValueWritten(ref: 'messages/{messageId}', (
      event,
    ) async {
      final before = event.data?.before;
      final after = event.data?.after;
      print('Database value written: messages/${event.params['messageId']}');
      if (before == null || !before.exists()) {
        print('  Operation: CREATE');
        print('  New data: ${after?.val()}');
      } else if (after == null || !after.exists()) {
        print('  Operation: DELETE');
        print('  Deleted data: ${before.val()}');
      } else {
        print('  Operation: UPDATE');
        print('  Before: ${before.val()}');
        print('  After: ${after.val()}');
      }
    });

    // Nested path database trigger
    firebase.database.onValueWritten(ref: 'users/{userId}/status', (
      event,
    ) async {
      final after = event.data?.after?.val();
      print('User status changed: ${event.params['userId']}');
      print('  New status: $after');
    });

    // ==========================================================================
    // Firebase Alerts trigger examples
    // ==========================================================================

    // Crashlytics new fatal issue alert
    firebase.alerts.crashlytics.onNewFatalIssuePublished((event) async {
      final issue = event.data?.payload.issue;
      print('New fatal issue in Crashlytics:');
      print('  Issue ID: ${issue?.id}');
      print('  Title: ${issue?.title}');
      print('  App Version: ${issue?.appVersion}');
      print('  App ID: ${event.appId}');
    });

    // Billing plan update alert
    firebase.alerts.billing.onPlanUpdatePublished((event) async {
      final payload = event.data?.payload;
      print('Billing plan updated:');
      print('  New Plan: ${payload?.billingPlan}');
      print('  Updated By: ${payload?.principalEmail}');
      print('  Type: ${payload?.notificationType}');
    });

    // Performance threshold alert with app ID filter
    firebase.alerts.performance.onThresholdAlertPublished(
      options: const AlertOptions(appId: '1:123456789:ios:abcdef'),
      (event) async {
        final payload = event.data?.payload;
        print('Performance threshold exceeded:');
        print('  Event: ${payload?.eventName}');
        print('  Metric: ${payload?.metricType}');
        print(
          '  Threshold: ${payload?.thresholdValue} ${payload?.thresholdUnit}',
        );
        print('  Actual: ${payload?.violationValue} ${payload?.violationUnit}');
      },
    );

    // ==========================================================================
    // Identity Platform (Auth Blocking) trigger examples
    // ==========================================================================

    // Before user created - runs before a new user is created
    firebase.identity.beforeUserCreated(
      options: const BlockingOptions(idToken: true, accessToken: true),
      (AuthBlockingEvent event) async {
        final user = event.data;
        print('Before user created:');
        print('  UID: ${user?.uid}');
        print('  Email: ${user?.email}');
        print('  Provider: ${event.additionalUserInfo?.providerId}');

        // Example: Block users with certain email domains
        final email = user?.email;
        if (email != null && email.endsWith('@blocked.com')) {
          throw PermissionDeniedError('Email domain not allowed');
        }

        // Example: Set custom claims based on email domain
        if (email != null && email.endsWith('@admin.com')) {
          return const BeforeCreateResponse(customClaims: {'admin': true});
        }

        return null;
      },
    );

    // Before user signed in - runs before a user signs in
    firebase.identity.beforeUserSignedIn(
      options: const BlockingOptions(idToken: true),
      (AuthBlockingEvent event) async {
        final user = event.data;
        print('Before user signed in:');
        print('  UID: ${user?.uid}');
        print('  Email: ${user?.email}');
        print('  IP Address: ${event.ipAddress}');

        // Example: Add session claims for tracking
        return BeforeSignInResponse(
          sessionClaims: {
            'lastLogin': DateTime.now().toIso8601String(),
            'signInIp': event.ipAddress,
          },
        );
      },
    );

    // Before email sent - runs before password reset or sign-in emails
    // NOTE: The Auth emulator only supports beforeCreate and beforeSignIn.
    // This function is included for manifest snapshot testing but cannot be
    // tested with the emulator.
    firebase.identity.beforeEmailSent((AuthBlockingEvent event) async {
      print('Before email sent:');
      print('  Email Type: ${event.emailType?.value}');
      print('  IP Address: ${event.ipAddress}');

      // Example: Rate limit password reset emails
      // In production, you'd check against a database
      if (event.emailType == EmailType.passwordReset) {
        // Could return BeforeEmailResponse(
        //   recaptchaActionOverride: RecaptchaActionOptions.block,
        // ) to block suspicious requests
      }

      return null;
    });

    // Before SMS sent - runs before MFA or sign-in SMS messages
    // NOTE: The Auth emulator only supports beforeCreate and beforeSignIn.
    // This function is included for manifest snapshot testing but cannot be
    // tested with the emulator.
    firebase.identity.beforeSmsSent((AuthBlockingEvent event) async {
      print('Before SMS sent:');
      print('  SMS Type: ${event.smsType?.value}');
      print('  Phone: ${event.additionalUserInfo?.phoneNumber}');

      // Example: Block SMS to certain country codes
      final phone = event.additionalUserInfo?.phoneNumber;
      if (phone != null && phone.startsWith('+1900')) {
        return const BeforeSmsResponse(
          recaptchaActionOverride: RecaptchaActionOptions.block,
        );
      }

      return null;
    });

    // ==========================================================================
    // Remote Config trigger examples
    // ==========================================================================

    // Remote Config update trigger
    firebase.remoteConfig.onConfigUpdated((event) async {
      final data = event.data;
      print('Remote Config updated:');
      print('  Version: ${data?.versionNumber}');
      print('  Description: ${data?.description}');
      print('  Update Origin: ${data?.updateOrigin.value}');
      print('  Update Type: ${data?.updateType.value}');
      print('  Updated By: ${data?.updateUser.email}');
    });

    // ==========================================================================
    // Cloud Storage trigger examples
    // ==========================================================================

    // Storage onObjectFinalized - triggers when an object is created/overwritten
    firebase.storage.onObjectFinalized(bucket: 'demo-test.firebasestorage.app', (event) async {
      final data = event.data;
      print('Object finalized in bucket: ${event.bucket}');
      print('  Name: ${data?.name}');
      print('  Content Type: ${data?.contentType}');
      print('  Size: ${data?.size}');
    });

    // Storage onObjectArchived - triggers when an object is archived
    firebase.storage.onObjectArchived(bucket: 'demo-test.firebasestorage.app', (event) async {
      final data = event.data;
      print('Object archived in bucket: ${event.bucket}');
      print('  Name: ${data?.name}');
      print('  Storage Class: ${data?.storageClass}');
    });

    // Storage onObjectDeleted - triggers when an object is deleted
    firebase.storage.onObjectDeleted(bucket: 'demo-test.firebasestorage.app', (event) async {
      final data = event.data;
      print('Object deleted in bucket: ${event.bucket}');
      print('  Name: ${data?.name}');
    });

    // Storage onObjectMetadataUpdated - triggers when object metadata changes
    firebase.storage.onObjectMetadataUpdated(bucket: 'demo-test.firebasestorage.app', (
      event,
    ) async {
      final data = event.data;
      print('Object metadata updated in bucket: ${event.bucket}');
      print('  Name: ${data?.name}');
      print('  Metadata: ${data?.metadata}');
    });

    // ==========================================================================
    // Scheduler trigger examples
    // ==========================================================================

    // Basic scheduled function - runs every day at midnight
    firebase.scheduler.onSchedule(schedule: '0 0 * * *', (event) async {
      print('Scheduled function triggered:');
      print('  Job Name: ${event.jobName}');
      print('  Schedule Time: ${event.scheduleTime}');
      // Perform daily cleanup, send reports, etc.
    });

    // Scheduled function with timezone and retry config
    firebase.scheduler.onSchedule(
      schedule: '0 9 * * 1-5',
      options: const ScheduleOptions(
        timeZone: TimeZone('America/New_York'),
        retryConfig: RetryConfig(
          retryCount: RetryCount(3),
          maxRetrySeconds: MaxRetrySeconds(60),
          minBackoffSeconds: MinBackoffSeconds(5),
          maxBackoffSeconds: MaxBackoffSeconds(30),
        ),
        memory: Memory(MemoryOption.mb256),
      ),
      (event) async {
        print('Weekday morning report:');
        print('  Executed at: ${event.scheduleDateTime}');
        // Generate and send morning reports
      },
    );

    print('Functions registered successfully!');
  });
}

// =============================================================================
// Data classes for typed callable functions
// =============================================================================

/// Request data for the greetTyped callable function.
class GreetRequest {
  GreetRequest({required this.name});

  factory GreetRequest.fromJson(Map<String, dynamic> json) {
    return GreetRequest(name: json['name'] as String? ?? 'World');
  }

  final String name;

  Map<String, dynamic> toJson() => {'name': name};
}

/// Response data for the greetTyped callable function.
class GreetResponse {
  GreetResponse({required this.message});

  final String message;

  Map<String, dynamic> toJson() => {'message': message};
}
