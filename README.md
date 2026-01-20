# Firebase Functions for Dart

[![Tests](https://github.com/invertase/firebase-functions-dart/actions/workflows/test.yml/badge.svg)](https://github.com/invertase/firebase-functions-dart/actions/workflows/test.yml)
[![PR Checks](https://github.com/invertase/firebase-functions-dart/actions/workflows/pr-checks.yml/badge.svg)](https://github.com/invertase/firebase-functions-dart/actions/workflows/pr-checks.yml)

Write Firebase Cloud Functions in Dart with full type safety and performance.

## Status: Alpha (v0.1.0)

This package provides a complete Dart implementation of Firebase Cloud Functions with support for:

| Trigger Type | Status | Functions |
|-------------|--------|-----------|
| **HTTPS** | ✅ Complete | `onRequest`, `onCall`, `onCallWithData` |
| **Pub/Sub** | ✅ Complete | `onMessagePublished` |
| **Firestore** | ✅ Complete | `onDocumentCreated`, `onDocumentUpdated`, `onDocumentDeleted`, `onDocumentWritten` |
| **Realtime Database** | ✅ Complete | `onValueCreated`, `onValueUpdated`, `onValueDeleted`, `onValueWritten` |
| **Firebase Alerts** | ✅ Complete | Crashlytics, Billing, Performance alerts |
| **Identity Platform** | ✅ Complete | `beforeUserCreated`, `beforeUserSignedIn` (+ `beforeEmailSent`, `beforeSmsSent`*) |

## Features

- **Type-safe**: Leverage Dart's strong type system with typed callable functions and CloudEvents
- **Fast**: Compiled Dart code with efficient Shelf HTTP server
- **Familiar API**: Similar to Firebase Functions Node.js SDK v2
- **Streaming**: Server-Sent Events (SSE) support for callable functions
- **Parameterized**: Deploy-time configuration with `defineString`, `defineInt`, `defineBoolean`
- **Conditional Config**: CEL expressions for environment-based options
- **Error Handling**: Built-in typed error classes matching the Node.js SDK
- **Hot Reload**: Fast development with build_runner watch

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  firebase_functions:
    path: ../firebase-functions-dart
```

## Quick Start

```dart
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    // Register your functions here
  });
}
```

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
```

## Realtime Database Triggers

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

// Value updated
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

// All write operations
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

## Firebase Alerts

```dart
// Crashlytics fatal issues
firebase.alerts.crashlytics.onNewFatalIssuePublished(
  (event) async {
    final issue = event.data?.payload.issue;
    print('Issue: ${issue?.title}');
    print('App: ${event.appId}');
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
  handler,
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

## Development

### Running the Emulator

```bash
firebase emulators:start --only functions
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

See [Testing Guide](test/snapshots/README.md) for more details.

## Documentation

- [Getting Started](docs/getting-started.md)
- [HTTPS Triggers](docs/https-triggers.md)
- [Pub/Sub Triggers](docs/pubsub-triggers.md)
- [Architecture](docs/architecture.md)

## Requirements

- Dart SDK >=3.0.0
- Firebase CLI with Dart runtime support

## License

Apache 2.0
