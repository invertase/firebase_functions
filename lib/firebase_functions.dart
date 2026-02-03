/// Firebase Functions for Dart
///
/// Write Firebase Cloud Functions in Dart with full type safety.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:firebase_functions/firebase_functions.dart';
///
/// void main(List<String> args) {
///   fireUp(args, (firebase) {
///     firebase.https.onRequest(
///       name: 'hello',
///       (request) async => Response.ok('Hello, World!'),
///     );
///   });
/// }
/// ```
///
/// ## Parameterized Configuration
///
/// Use parameters for deploy-time and runtime configuration:
///
/// ```dart
/// final welcomeMessage = defineString('WELCOME_MESSAGE',
///     ParamOptions(defaultValue: 'Hello!'));
///
/// firebase.https.onRequest(
///   name: 'greet',
///   (request) async => Response.ok(welcomeMessage.value()),
/// );
/// ```
///
/// ## Secrets
///
/// Store sensitive values in Cloud Secret Manager:
///
/// ```dart
/// final apiKey = defineSecret('API_KEY');
///
/// firebase.https.onRequest(
///   name: 'secure',
///   options: HttpsOptions(secrets: [apiKey]),
///   (request) async {
///     // apiKey.value() is only available at runtime
///     return Response.ok('Configured');
///   },
/// );
/// ```
///
/// See also:
/// - [params.dart] for the full params API
/// - [onInit] for safe initialization with secrets
library;

// Re-export Firestore types for convenience
export 'package:googleapis_firestore/googleapis_firestore.dart'
    show DocumentData, DocumentSnapshot, QueryDocumentSnapshot;
// Re-export Shelf types for convenience
export 'package:shelf/shelf.dart' show Request, Response;

// Re-export built-in params from params.dart for convenience
export 'params.dart' show databaseURL, gcloudProject, projectID, storageBucket;
// Alerts triggers
export 'src/alerts/alerts.dart';
// Common types
export 'src/common/cloud_event.dart';
export 'src/common/expression.dart';
export 'src/common/on_init.dart' show onInit;
export 'src/common/options.dart';
export 'src/common/params.dart';
// Database triggers
export 'src/database/database.dart';
// Core firebase instance
export 'src/firebase.dart' show Firebase;
// Firestore triggers
export 'src/firestore/firestore.dart';
// HTTPS triggers
export 'src/https/https.dart';
// Identity triggers
export 'src/identity/identity.dart';
// Pub/Sub triggers
export 'src/pubsub/pubsub.dart';
// Scheduler triggers
export 'src/scheduler/scheduler.dart';
// Core runtime
export 'src/server.dart' show fireUp;
