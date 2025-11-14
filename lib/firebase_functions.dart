/// Firebase Functions for Dart
///
/// Write Firebase Cloud Functions in Dart with full type safety.
library firebase_functions;

// Core runtime
export 'src/server.dart' show fireUp;
export 'src/firebase.dart' show Firebase;

// HTTPS triggers
export 'src/https/https.dart';

// Pub/Sub triggers
export 'src/pubsub/pubsub.dart';

// Common types
export 'src/common/cloud_event.dart';
export 'src/common/expression.dart';
export 'src/common/options.dart';
export 'src/common/params.dart';

// Re-export Shelf types for convenience
export 'package:shelf/shelf.dart' show Request, Response;
