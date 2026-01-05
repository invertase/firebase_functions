# Firebase Functions for Dart

[![Tests](https://github.com/invertase/firebase-functions-dart/actions/workflows/test.yml/badge.svg)](https://github.com/invertase/firebase-functions-dart/actions/workflows/test.yml)
[![PR Checks](https://github.com/invertase/firebase-functions-dart/actions/workflows/pr-checks.yml/badge.svg)](https://github.com/invertase/firebase-functions-dart/actions/workflows/pr-checks.yml)

Write Firebase Cloud Functions in Dart with full type safety and performance.

## Status: Alpha (v0.1.0)

This package is in active development. Phase 1 includes:
- ✅ HTTPS triggers (onRequest, onCall, onCallWithData)
- ✅ Pub/Sub triggers (onMessagePublished)
- ✅ CloudEvent foundation
- ✅ Build-time code generation

## Features

- **Type-safe**: Leverage Dart's strong type system
- **Fast**: Compiled Dart code with efficient Shelf HTTP server
- **Familiar API**: Similar to Firebase Functions Node.js SDK
- **Testing**: Built with testing in mind
- **Hot Reload**: Fast development with build_runner watch

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  firebase_functions:
    path: ../firebase-functions-dart
```

## Quick Start

### HTTPS Function

```dart
import 'package:firebase_functions/firebase_functions.dart';
import 'package:shelf/shelf.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    firebase.https.onRequest(
      name: 'hello',
      (request) async {
        return Response.ok('Hello from Dart!');
      },
    );
  });
}
```

### Callable Function

```dart
firebase.https.onCall(
  name: 'greet',
  (request, response) async {
    final name = request.data['name'] as String;
    return CallableResult({'message': 'Hello $name!'});
  },
);
```

### Pub/Sub Trigger

```dart
firebase.pubsub.onMessagePublished(
  topic: 'my-topic',
  (event) async {
    final message = event.data;
    print('Received: ${message.textData}');
    print('Attributes: ${message.attributes}');
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
