import 'dart:async';
import 'dart:io';

import 'package:dart_firebase_admin/dart_firebase_admin.dart';
import 'package:dart_firebase_admin/firestore.dart';
import 'package:shelf/shelf.dart';

import 'firestore/firestore_namespace.dart';
import 'https/https_namespace.dart';
import 'pubsub/pubsub_namespace.dart';

/// Main Firebase Functions instance.
///
/// Provides access to all function namespaces (https, pubsub, firestore, etc.).
class Firebase {
  Firebase() {
    _initializeAdminSDK();
  }

  FirebaseAdminApp? _adminApp;
  Firestore? _firestoreInstance;

  /// Initialize the Firebase Admin SDK
  void _initializeAdminSDK() {
    // Get project ID from environment
    final projectId = Platform.environment['GCLOUD_PROJECT'] ??
        Platform.environment['GCP_PROJECT'] ??
        'demo-test'; // Fallback for emulator

    // Check if running in emulator
    final firestoreEmulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    final isEmulator = firestoreEmulatorHost != null;

    try {
      if (isEmulator) {
        // Emulator mode - no credentials needed
        print('Initializing Firebase Admin SDK for emulator (project: $projectId)');
        print('Firestore emulator: $firestoreEmulatorHost');

        // For emulator, we don't need actual credentials
        _adminApp = FirebaseAdminApp.initializeApp(
          projectId,
          Credential.fromApplicationDefaultCredentials(),
        );
      } else {
        // Production mode - use Application Default Credentials
        print('Initializing Firebase Admin SDK (project: $projectId)');
        _adminApp = FirebaseAdminApp.initializeApp(
          projectId,
          Credential.fromApplicationDefaultCredentials(),
        );
      }

      _firestoreInstance = Firestore(_adminApp!);
      print('Firebase Admin SDK initialized successfully');
    } catch (e) {
      print('Warning: Failed to initialize Firebase Admin SDK: $e');
      print('Firestore triggers will not be able to fetch document data');
    }
  }

  /// Get the Firestore instance
  Firestore? get firestoreAdmin => _firestoreInstance;

  /// HTTPS triggers namespace.
  HttpsNamespace get https => HttpsNamespace(this);

  /// Pub/Sub triggers namespace.
  PubSubNamespace get pubsub => PubSubNamespace(this);

  /// Firestore triggers namespace.
  FirestoreNamespace get firestore => FirestoreNamespace(this);
}

/// Extension for internal function registration.
///
/// This is hidden from the public API but used internally by namespaces.
extension FirebaseX on Firebase {
  static final Map<Firebase, List<FirebaseFunctionDeclaration>> _functionsMap =
      {};

  /// Gets all registered functions for this Firebase instance.
  List<FirebaseFunctionDeclaration> get functions =>
      _functionsMap.putIfAbsent(this, () => []);

  /// Registers a function with the Firebase instance.
  ///
  /// [name] is the function name (used for routing).
  /// [handler] is the function handler that processes requests.
  /// [external] indicates if the function accepts non-POST requests.
  /// [documentPattern] is the Firestore document path pattern (e.g., 'users/{userId}').
  void registerFunction(
    String name,
    FirebaseFunctionHandler handler, {
    bool external = false,
    String? documentPattern,
  }) {
    // Check for duplicate function names
    if (functions.any((f) => f.name == name)) {
      throw StateError('Function "$name" is already registered');
    }

    // Transform the name to be URL-safe
    final transformedName = name.replaceAll(' ', '_');

    functions.add(
      FirebaseFunctionDeclaration(
        name: transformedName,
        handler: handler,
        external: external,
        documentPattern: documentPattern,
      ),
    );
  }
}

/// Type for function handlers.
///
/// All function handlers must return a Shelf Response, either directly
/// or wrapped in a Future.
typedef FirebaseFunctionHandler = FutureOr<Response> Function(Request request);

/// Declaration of a registered Firebase Function.
final class FirebaseFunctionDeclaration {
  FirebaseFunctionDeclaration({
    required this.name,
    required this.handler,
    required this.external,
    this.documentPattern,
  }) : path = name;

  /// Function name (used for routing and identification).
  final String name;

  /// URL path for this function (derived from name).
  final String path;

  /// For Firestore triggers: the document path pattern (e.g., 'users/{userId}').
  /// Used for pattern matching against actual document paths.
  final String? documentPattern;

  /// Whether this function accepts external (non-POST) requests.
  ///
  /// HTTPS functions are external (true).
  /// Event-driven functions are internal (false, POST only).
  final bool external;

  /// The function handler.
  final FirebaseFunctionHandler handler;
}

/// Base class for function namespaces.
abstract class FunctionsNamespace {
  const FunctionsNamespace(this.firebase);
  final Firebase firebase;
}
