# Trigger and configuration reference

This page contains extended examples and configuration details for `firebase_functions`.

## Status

| Trigger Type | Status | Functions |
|-------------|--------|-----------|
| **HTTPS** | ✅ Production | `onRequest`, `onCall`, `onCallWithData` [(see note)](#note) |
| **Firestore** | ⚠️ Emulator only | `onDocumentCreated`, `onDocumentUpdated`, `onDocumentDeleted`, `onDocumentWritten`, `onDocumentCreatedWithAuthContext`, `onDocumentUpdatedWithAuthContext`, `onDocumentDeletedWithAuthContext`, `onDocumentWrittenWithAuthContext` |
| **Realtime Database** | ⚠️ Emulator only | `onValueCreated`, `onValueUpdated`, `onValueDeleted`, `onValueWritten` |
| **Storage** | ⚠️ Emulator only | `onObjectFinalized`, `onObjectArchived`, `onObjectDeleted`, `onObjectMetadataUpdated` |
| **Pub/Sub** | 🚧 Experimental | `onMessagePublished` |
| **Scheduler** | 🚧 Experimental | `onSchedule` |
| **Firebase Alerts** | 🚧 Experimental | `onAlertPublished` and sub-namespace triggers |
| **Eventarc** | 🚧 Experimental | `onCustomEventPublished` |
| **Identity Platform** | 🚧 Experimental | `beforeUserCreated`, `beforeUserSignedIn` (+ `beforeEmailSent`, `beforeSmsSent`) |
| **Remote Config** | 🚧 Experimental | `onConfigUpdated` |
| **Test Lab** | 🚧 Experimental | `onTestMatrixCompleted` |
| **Task Queues** | 🚧 Experimental | `onTaskDispatched` |

> **Legend**: ✅ Production — works in production and emulator. ⚠️ Emulator only — works with the Firebase emulator but not yet in production. 🚧 Experimental — implemented but not currently supported by the emulator or production; APIs may change.

<a name="note"></a>
> [!NOTE]
> When invoking functions defined with `onCall` and `onCallWithData` from a
> client SDK, you must use the function's HTTPS URL. The standard name-based
> lookup is not supported for functions written in Dart. For example, in the
> Flutter `cloud_functions` package, use `httpsCallableFromUrl`.

## Features

- **Type-safe**: Leverage Dart's strong type system with typed callable functions and CloudEvents
- **Fast**: Compiled Dart code with efficient Shelf HTTP server
- **Familiar API**: Similar to Firebase Functions Node.js SDK v2
- **Streaming**: Server-Sent Events (SSE) support for callable functions
- **Parameterized**: Deploy-time configuration with `defineString`, `defineInt`, `defineBoolean`
- **Conditional Config**: CEL expressions for environment-based options
- **Error Handling**: Built-in typed error classes matching the Node.js SDK
- **Hot Reload**: Fast development with build_runner watch

## HTTPS Functions

### onRequest - Raw HTTP Handler

```dart
firebase.https.onRequest(
  name: 'hello',
  (request) async {
    return Response.ok('Hello from Dart!');
  },
);
```

### onCall - Untyped Callable

```dart
firebase.https.onCall(
  name: 'greet',
  (request, response) async {
    final data = request.data as Map<String, dynamic>?;
    final name = data?['name'] ?? 'World';
    return CallableResult({'message': 'Hello, $name!'});
  },
);
```

### onCallWithData - Type-safe Callable

```dart
firebase.https.onCallWithData<GreetRequest, GreetResponse>(
  name: 'greetTyped',
  fromJson: GreetRequest.fromJson,
  (request, response) async {
    return GreetResponse(message: 'Hello, ${request.data.name}!');
  },
);
```

### Streaming Support

```dart
firebase.https.onCall(
  name: 'countdown',
  options: const CallableOptions(
    heartBeatIntervalSeconds: HeartBeatIntervalSeconds(5),
  ),
  (request, response) async {
    if (request.acceptsStreaming) {
      for (var i = 10; i >= 0; i--) {
        await response.sendChunk({'count': i});
        await Future.delayed(Duration(milliseconds: 100));
      }
    }
    return CallableResult({'message': 'Countdown complete!'});
  },
);
```

### Error Handling

```dart
firebase.https.onCall(
  name: 'divide',
  (request, response) async {
    final data = request.data as Map<String, dynamic>?;
    final a = data?['a'] as num?;
    final b = data?['b'] as num?;

    if (a == null || b == null) {
      throw InvalidArgumentError('Both "a" and "b" are required');
    }
    if (b == 0) {
      throw FailedPreconditionError('Cannot divide by zero');
    }

    return CallableResult({'result': a / b});
  },
);
```

Available error types: `InvalidArgumentError`, `FailedPreconditionError`, `NotFoundError`, `AlreadyExistsError`, `PermissionDeniedError`, `ResourceExhaustedError`, `UnauthenticatedError`, `UnavailableError`, `InternalError`, `DeadlineExceededError`, `CancelledError`.

## Pub/Sub Triggers

```dart
firebase.pubsub.onMessagePublished(
  topic: 'my-topic',
  (event) async {
    final message = event.data;
    print('ID: ${message?.messageId}');
    print('Data: ${message?.textData}');
    print('Attributes: ${message?.attributes}');
  },
);
```

## Firestore Triggers

```dart
// Document created
firebase.firestore.onDocumentCreated(
  document: 'users/{userId}',
  (event) async {
    final data = event.data?.data();
    print('Created: users/${event.params['userId']}');
    print('Name: ${data?['name']}');
  },
);

// Document updated
firebase.firestore.onDocumentUpdated(
  document: 'users/{userId}',
  (event) async {
    final before = event.data?.before?.data();
    final after = event.data?.after?.data();
    print('Before: $before');
    print('After: $after');
  },
);

// Document deleted
firebase.firestore.onDocumentDeleted(
  document: 'users/{userId}',
  (event) async {
    final data = event.data?.data();
    print('Deleted data: $data');
  },
);

// All write operations
firebase.firestore.onDocumentWritten(
  document: 'users/{userId}',
  (event) async {
    final before = event.data?.before?.data();
    final after = event.data?.after?.data();
    // Determine operation type
    if (before == null && after != null) print('CREATE');
    if (before != null && after != null) print('UPDATE');
    if (before != null && after == null) print('DELETE');
  },
);

// Nested collections
firebase.firestore.onDocumentCreated(
  document: 'posts/{postId}/comments/{commentId}',
  (event) async {
    print('Post: ${event.params['postId']}');
    print('Comment: ${event.params['commentId']}');
  },
);

// With auth context (identifies the principal that triggered the write)
firebase.firestore.onDocumentCreatedWithAuthContext(
  document: 'orders/{orderId}',
  (event) async {
    print('Auth type: ${event.authType}');
    print('Auth ID: ${event.authId}');
    final data = event.data?.data();
    print('Order: ${data?['product']}');
  },
);

firebase.firestore.onDocumentUpdatedWithAuthContext(
  document: 'orders/{orderId}',
  (event) async {
    print('Updated by: ${event.authType} (${event.authId})');
    final before = event.data?.before?.data();
    final after = event.data?.after?.data();
    print('Before: $before');
    print('After: $after');
  },
);

firebase.firestore.onDocumentDeletedWithAuthContext(
  document: 'orders/{orderId}',
  (event) async {
    print('Deleted by: ${event.authType} (${event.authId})');
    final data = event.data?.data();
    print('Deleted data: $data');
  },
);

firebase.firestore.onDocumentWrittenWithAuthContext(
  document: 'orders/{orderId}',
  (event) async {
    print('Written by: ${event.authType} (${event.authId})');
    final before = event.data?.before;
    final after = event.data?.after;
    if (before == null || !before.exists) print('CREATE');
    else if (after == null || !after.exists) print('DELETE');
    else print('UPDATE');
  },
);
```

## Realtime Database Triggers

Respond to changes in Firebase Realtime Database. The `ref` parameter supports path wildcards (e.g., `{messageId}`) which are extracted into `event.params`.

| Function | Triggers when | Event data |
|----------|---------------|------------|
| `onValueCreated` | Data is created | `DataSnapshot?` |
| `onValueUpdated` | Data is updated | `Change<DataSnapshot>?` (before/after) |
| `onValueDeleted` | Data is deleted | `DataSnapshot?` (deleted data) |
| `onValueWritten` | Any write (create/update/delete) | `Change<DataSnapshot>?` (before/after) |

### DataSnapshot API

The `DataSnapshot` class provides methods to inspect the data:

- `val()` — Returns the snapshot contents (Map, List, String, num, bool, or null)
- `exists()` — Returns `true` if the snapshot contains data
- `child(path)` — Gets a child snapshot at the given path
- `hasChild(path)` / `hasChildren()` — Check for child data
- `numChildren()` — Number of child properties
- `key` — Last segment of the reference path

```dart
// Value created
firebase.database.onValueCreated(
  ref: 'messages/{messageId}',
  (event) async {
    final data = event.data?.val();
    print('Created: ${event.params['messageId']}');
    print('Data: $data');
    print('Instance: ${event.instance}');
  },
);

// Value updated — access before/after states
firebase.database.onValueUpdated(
  ref: 'messages/{messageId}',
  (event) async {
    final before = event.data?.before?.val();
    final after = event.data?.after?.val();
    print('Before: $before');
    print('After: $after');
  },
);

// Value deleted
firebase.database.onValueDeleted(
  ref: 'messages/{messageId}',
  (event) async {
    final data = event.data?.val();
    print('Deleted: $data');
  },
);

// All write operations — determine operation type from before/after
firebase.database.onValueWritten(
  ref: 'users/{userId}/status',
  (event) async {
    final before = event.data?.before;
    final after = event.data?.after;
    if (before == null || !before.exists()) print('CREATE');
    else if (after == null || !after.exists()) print('DELETE');
    else print('UPDATE');
  },
);
```

### Database Instance Targeting

Use `ReferenceOptions` to target a specific database instance:

```dart
firebase.database.onValueCreated(
  ref: 'messages/{messageId}',
  options: const ReferenceOptions(instance: 'my-project-default-rtdb'),
  (event) async {
    print('Instance: ${event.instance}');
  },
);
```

## Storage Triggers

Respond to changes in Cloud Storage objects. The `bucket` parameter specifies which storage bucket to watch.

| Function | Triggers when |
|----------|---------------|
| `onObjectFinalized` | Object is created or overwritten |
| `onObjectDeleted` | Object is permanently deleted |
| `onObjectArchived` | Object is archived (versioned buckets) |
| `onObjectMetadataUpdated` | Object metadata is updated |

### StorageObjectData Properties

The event data provides full object metadata:

- `name` — Object path within the bucket
- `bucket` — Bucket name
- `contentType` — MIME type
- `size` — Content length in bytes
- `storageClass` — Storage class (STANDARD, NEARLINE, COLDLINE, etc.)
- `metadata` — User-provided key-value metadata
- `timeCreated` / `updated` / `timeDeleted` — Timestamps
- `md5Hash` / `crc32c` — Checksums
- `generation` / `metageneration` — Versioning info

```dart
// Object finalized (created or overwritten)
firebase.storage.onObjectFinalized(
  bucket: 'my-bucket',
  (event) async {
    final data = event.data;
    print('Object finalized: ${data?.name}');
    print('Content type: ${data?.contentType}');
    print('Size: ${data?.size}');
  },
);

// Object archived (versioned buckets only)
firebase.storage.onObjectArchived(
  bucket: 'my-bucket',
  (event) async {
    final data = event.data;
    print('Object archived: ${data?.name}');
    print('Storage class: ${data?.storageClass}');
  },
);

// Object deleted
firebase.storage.onObjectDeleted(
  bucket: 'my-bucket',
  (event) async {
    final data = event.data;
    print('Object deleted: ${data?.name}');
  },
);

// Object metadata updated
firebase.storage.onObjectMetadataUpdated(
  bucket: 'my-bucket',
  (event) async {
    final data = event.data;
    print('Metadata updated: ${data?.name}');
    print('Metadata: ${data?.metadata}');
  },
);
```

## Scheduler Triggers

Run functions on a recurring schedule using Cloud Scheduler. The `schedule` parameter accepts standard Unix crontab expressions.

### Cron Syntax

```
┌───────────── minute (0-59)
│ ┌───────────── hour (0-23)
│ │ ┌───────────── day of month (1-31)
│ │ │ ┌───────────── month (1-12)
│ │ │ │ ┌───────────── day of week (0-6, Sunday=0)
│ │ │ │ │
* * * * *
```

Common examples: `0 0 * * *` (daily midnight), `*/5 * * * *` (every 5 min), `0 9 * * 1-5` (weekdays 9 AM).

### ScheduledEvent Properties

- `jobName` — Cloud Scheduler job name (null if manually invoked)
- `scheduleTime` — Scheduled execution time (RFC 3339 string)
- `scheduleDateTime` — Parsed `DateTime` convenience getter

```dart
// Basic schedule — runs every day at midnight (UTC)
firebase.scheduler.onSchedule(
  schedule: '0 0 * * *',
  (event) async {
    print('Job: ${event.jobName}');
    print('Schedule time: ${event.scheduleTime}');
  },
);
```

### Timezone and Retry Configuration

Use `ScheduleOptions` to set a timezone and configure retry behavior for failed invocations:

```dart
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
    print('Executed at: ${event.scheduleDateTime}');
  },
);
```

| RetryConfig field | Description |
|---|---|
| `retryCount` | Number of retry attempts |
| `maxRetrySeconds` | Maximum total time for retries |
| `minBackoffSeconds` | Minimum wait before retry (0-3600) |
| `maxBackoffSeconds` | Maximum wait before retry (0-3600) |
| `maxDoublings` | Times to double backoff before going linear |

## Firebase Alerts

```dart
// App Distribution new tester iOS device
firebase.alerts.appDistribution.onNewTesterIosDevicePublished(
  (event) async {
    final payload = event.data?.payload;
    print('New tester iOS device:');
    print('  Tester: ${payload?.testerName} (${payload?.testerEmail})');
    print('  Device: ${payload?.testerDeviceModelName}');
    print('  Identifier: ${payload?.testerDeviceIdentifier}');
  },
);

// Crashlytics fatal issues
firebase.alerts.crashlytics.onNewFatalIssuePublished(
  (event) async {
    final issue = event.data?.payload.issue;
    print('Issue: ${issue?.title}');
    print('App: ${event.appId}');
  },
);

// Crashlytics ANR (Application Not Responding) issues
firebase.alerts.crashlytics.onNewAnrIssuePublished(
  (event) async {
    final issue = event.data?.payload.issue;
    print('ANR issue: ${issue?.title}');
    print('App: ${event.appId}');
  },
);

// Crashlytics regression alerts
firebase.alerts.crashlytics.onRegressionAlertPublished(
  (event) async {
    final payload = event.data?.payload;
    print('Regression: ${payload?.type}');
    print('Issue: ${payload?.issue.title}');
    print('Resolved: ${payload?.resolveTime}');
  },
);

// Crashlytics non-fatal issues
firebase.alerts.crashlytics.onNewNonfatalIssuePublished(
  (event) async {
    final issue = event.data?.payload.issue;
    print('Non-fatal issue: ${issue?.title}');
    print('App: ${event.appId}');
  },
);

// Crashlytics stability digest
firebase.alerts.crashlytics.onStabilityDigestPublished(
  (event) async {
    final payload = event.data?.payload;
    print('Stability digest: ${payload?.digestDate}');
    print('Trending issues: ${payload?.trendingIssues.length ?? 0}');
  },
);

// Crashlytics velocity alerts
firebase.alerts.crashlytics.onVelocityAlertPublished(
  (event) async {
    final payload = event.data?.payload;
    print('Velocity alert: ${payload?.issue.title}');
    print('Crash count: ${payload?.crashCount}');
    print('Percentage: ${payload?.crashPercentage}%');
    print('First version: ${payload?.firstVersion}');
  },
);

// Billing plan updates
firebase.alerts.billing.onPlanUpdatePublished(
  (event) async {
    final payload = event.data?.payload;
    print('New Plan: ${payload?.billingPlan}');
    print('Updated By: ${payload?.principalEmail}');
  },
);

// Billing automated plan updates
firebase.alerts.billing.onPlanAutomatedUpdatePublished(
  (event) async {
    final payload = event.data?.payload;
    print('Automated plan update:');
    print('  Plan: ${payload?.billingPlan}');
    print('  Type: ${payload?.notificationType}');
  },
);

// Performance threshold alerts
firebase.alerts.performance.onThresholdAlertPublished(
  options: const AlertOptions(appId: '1:123456789:ios:abcdef'),
  (event) async {
    final payload = event.data?.payload;
    print('Metric: ${payload?.metricType}');
    print('Threshold: ${payload?.thresholdValue}');
    print('Actual: ${payload?.violationValue}');
  },
);

// App Distribution in-app feedback
firebase.alerts.appDistribution.onInAppFeedbackPublished(
  (event) async {
    final payload = event.data?.payload;
    print('In-app feedback:');
    print('  Tester: ${payload?.testerEmail}');
    print('  App version: ${payload?.appVersion}');
    print('  Text: ${payload?.text}');
    print('  Console: ${payload?.feedbackConsoleUri}');
  },
);
```

## Eventarc

```dart
// Custom event (default Firebase channel)
firebase.eventarc.onCustomEventPublished(
  eventType: 'com.example.myevent',
  (event) async {
    print('Event: ${event.type}');
    print('Source: ${event.source}');
    print('Data: ${event.data}');
  },
);

// With channel and filters
firebase.eventarc.onCustomEventPublished(
  eventType: 'com.example.filtered',
  options: const EventarcTriggerOptions(
    channel: 'my-channel',
    filters: {'category': 'important'},
  ),
  (event) async {
    print('Event: ${event.type}');
    print('Data: ${event.data}');
  },
);
```

## Identity Platform (Auth Blocking)

```dart
// Before user created
firebase.identity.beforeUserCreated(
  options: const BlockingOptions(idToken: true, accessToken: true),
  (AuthBlockingEvent event) async {
    final user = event.data;

    // Block certain email domains
    if (user?.email?.endsWith('@blocked.com') ?? false) {
      throw PermissionDeniedError('Email domain not allowed');
    }

    // Set custom claims
    if (user?.email?.endsWith('@admin.com') ?? false) {
      return const BeforeCreateResponse(
        customClaims: {'admin': true},
      );
    }

    return null;
  },
);

// Before user signed in
firebase.identity.beforeUserSignedIn(
  options: const BlockingOptions(idToken: true),
  (AuthBlockingEvent event) async {
    return BeforeSignInResponse(
      sessionClaims: {
        'lastLogin': DateTime.now().toIso8601String(),
        'signInIp': event.ipAddress,
      },
    );
  },
);
```

> **Note**: `beforeEmailSent` and `beforeSmsSent` are also available but cannot be tested with the Firebase Auth emulator (emulator only supports `beforeUserCreated` and `beforeUserSignedIn`). They work in production deployments.

## Remote Config

Trigger a function when Firebase Remote Config is updated.

```dart
firebase.remoteConfig.onConfigUpdated((event) async {
  final data = event.data;
  print('Remote Config updated:');
  print('  Version: ${data?.versionNumber}');
  print('  Description: ${data?.description}');
  print('  Update Origin: ${data?.updateOrigin.value}');
  print('  Update Type: ${data?.updateType.value}');
  print('  Updated By: ${data?.updateUser.email}');
});
```

## Test Lab

Trigger a function when a Firebase Test Lab test matrix completes.

```dart
firebase.testLab.onTestMatrixCompleted((event) async {
  final data = event.data;
  print('Test matrix completed:');
  print('  Matrix ID: ${data?.testMatrixId}');
  print('  State: ${data?.state.value}');
  print('  Outcome: ${data?.outcomeSummary.value}');
  print('  Client: ${data?.clientInfo.client}');
  print('  Results URI: ${data?.resultStorage.resultsUri}');
});
```

## Task Queues

Handle Cloud Tasks dispatched to a function.

```dart
firebase.tasks.onTaskDispatched(
  name: 'processOrder',
  (request) async {
    final data = request.data as Map<String, dynamic>;
    print('Processing order: ${data['orderId']}');
    print('Task ID: ${request.id}');
    print('Queue: ${request.queueName}');
    print('Retry count: ${request.retryCount}');
  },
);
```

Use `TaskQueueOptions` to configure retry behavior and dispatch rate limits:

```dart
firebase.tasks.onTaskDispatched(
  name: 'sendEmail',
  options: const TaskQueueOptions(
    retryConfig: TaskQueueRetryConfig(
      maxAttempts: MaxAttempts(5),
      maxRetrySeconds: TaskMaxRetrySeconds(300),
      minBackoffSeconds: TaskMinBackoffSeconds(10),
      maxBackoffSeconds: TaskMaxBackoffSeconds(60),
      maxDoublings: TaskMaxDoublings(3),
    ),
    rateLimits: TaskQueueRateLimits(
      maxConcurrentDispatches: MaxConcurrentDispatches(100),
      maxDispatchesPerSecond: MaxDispatchesPerSecond(50),
    ),
  ),
  (request) async {
    final data = request.data as Map<String, dynamic>;
    print('Sending email to: ${data['to']}');
    print('Subject: ${data['subject']}');
  },
);
```

## Parameters & Configuration

### Defining Parameters

```dart
final welcomeMessage = defineString(
  'WELCOME_MESSAGE',
  ParamOptions(
    defaultValue: 'Hello from Dart!',
    label: 'Welcome Message',
    description: 'The greeting message returned by the function',
  ),
);

final minInstances = defineInt(
  'MIN_INSTANCES',
  ParamOptions(defaultValue: 0),
);

final isProduction = defineBoolean(
  'IS_PRODUCTION',
  ParamOptions(defaultValue: false),
);
```

### Using Parameters at Runtime

```dart
firebase.https.onRequest(
  name: 'hello',
  (request) async {
    return Response.ok(welcomeMessage.value());
  },
);
```

### Using Parameters in Options (Deploy-time)

```dart
firebase.https.onRequest(
  name: 'configured',
  options: HttpsOptions(
    minInstances: DeployOption.param(minInstances),
  ),
  (request) async => Response.ok('Configured'),
);
```

### Conditional Configuration

```dart
firebase.https.onRequest(
  name: 'api',
  options: HttpsOptions(
    // 2GB in production, 512MB in development
    memory: Memory.expression(isProduction.thenElse(2048, 512)),
  ),
  (request) async {
    final env = isProduction.value() ? 'production' : 'development';
    return Response.ok('Running in $env mode');
  },
);
```

## Project Configuration

Your `firebase.json` must specify the Dart runtime:

```json
{
  "functions": [
    {
      "source": ".",
      "codebase": "default",
      "runtime": "dart3"
    }
  ],
  "emulators": {
    "functions": { "port": 5001 },
    "firestore": { "port": 8080 },
    "database": { "port": 9000 },
    "auth": { "port": 9099 },
    "pubsub": { "port": 8085 },
    "ui": { "enabled": true, "port": 4000 }
  }
}
```

## Deployment

For full deployment instructions, see the [Get started with Cloud Functions for Firebase (Dart)](https://firebase.google.com/docs/functions/start-dart) guide.

> [!NOTE]
> Only HTTPS triggers (`onRequest`, `onCall`, `onCallWithData`) are supported in production. See the [status table](#status) for other trigger types.

## Development

### Running the Emulator

```bash
firebase emulators:start
```

### Building

```bash
dart run build_runner build
```

### Testing

Run all tests:
```bash
dart test
```

Run specific test suites:
```bash
# Unit tests only
dart test --exclude-tags=snapshot,integration

# Builder tests
dart run build_runner build --delete-conflicting-outputs
dart test test/builder/

# Snapshot tests (compare with Node.js SDK)
dart test test/snapshots/
```

See [Testing Guide](../test/snapshots/README.md) for more details.
