/// Firebase Functions for Dart
///
/// Write Firebase Cloud Functions in Dart with full type safety.
library firebase_functions;

// Re-export dart_firebase_admin types for convenience
export 'package:dart_firebase_admin/firestore.dart'
    show DocumentData, DocumentSnapshot, QueryDocumentSnapshot;
// Re-export Shelf types for convenience
export 'package:shelf/shelf.dart' show Request, Response;

// Common types
export 'src/common/cloud_event.dart';
export 'src/common/expression.dart';
export 'src/common/options.dart';
export 'src/common/params.dart';
// Core firebase instance
export 'src/firebase.dart' show Firebase;
// Firestore triggers
export 'src/firestore/firestore.dart';
// HTTPS triggers
export 'src/https/https.dart';
// Pub/Sub triggers
export 'src/pubsub/pubsub.dart';
// Core runtime
export 'src/server.dart' show fireUp;
