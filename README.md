# Cloud Functions for Firebase Dart SDK

[![Tests](https://github.com/firebase/firebase-functions-dart/actions/workflows/test.yml/badge.svg)](https://github.com/firebase/firebase-functions-dart/actions/workflows/test.yml)
[![pub package](https://img.shields.io/pub/v/firebase_functions.svg)](https://pub.dev/packages/firebase_functions)

The [`firebase_functions`](https://pub.dev/packages/firebase_functions) package provides an SDK for defining Cloud Functions for Firebase in Dart.

Cloud Functions provides a hosted, private, and scalable environment where you can run server code. The Firebase SDK for Cloud Functions integrates the Firebase platform by letting you write code that responds to events and invokes functionality exposed by other Firebase features.

## Status

Only HTTPS triggers are currently supported in production. Other trigger types are experimental and have varying levels of support.

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

For detailed trigger examples and configuration options, see the [trigger and configuration reference](docs/trigger-reference.md).

## Learn more

Learn more about the Firebase SDK for Cloud Functions in the [Firebase documentation](https://firebase.google.com/docs/functions/) or [check out our samples](example/).

Here are some resources to get help:

- [Start with the quickstart](https://firebase.google.com/docs/functions/start-dart)
- [Go through the guides](https://firebase.google.com/docs/functions/)
- [Read the full API reference](https://pub.dev/documentation/firebase_functions/latest/)
- [Browse some examples](example/)

If the official documentation doesn't help, try asking through our [official support channels](https://firebase.google.com/support/).

_Please avoid double posting across multiple channels!_

## Usage

```dart
// functions/bin/server.dart
import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  runFunctions((firebase) {
    firebase.https.onRequest(
      name: 'hello',
      (request) async {
        return Response.ok('Hello from Dart!');
      },
    );
  });
}
```

## Contributing

To contribute a change, [check out the contributing guide](CONTRIBUTING.md).

## License

© Google, 2026. Licensed under [Apache License](LICENSE).
