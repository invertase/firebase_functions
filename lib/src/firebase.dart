import 'dart:async';
import 'dart:io';

import 'package:dart_firebase_admin/dart_firebase_admin.dart';
import 'package:googleapis_firestore/googleapis_firestore.dart' as gfs;
import 'package:shelf/shelf.dart';

import 'alerts/alerts_namespace.dart';
import 'common/cloud_run_id.dart';
import 'database/database_namespace.dart';
import 'eventarc/eventarc_namespace.dart';
import 'firestore/firestore_namespace.dart';
import 'https/https_namespace.dart';
import 'identity/identity_namespace.dart';
import 'pubsub/pubsub_namespace.dart';
import 'remote_config/remote_config_namespace.dart';
import 'scheduler/scheduler_namespace.dart';
import 'storage/storage_namespace.dart';
import 'tasks/tasks_namespace.dart';
import 'test_lab/test_lab_namespace.dart';

/// Main Firebase Functions instance.
///
/// Provides access to all function namespaces (https, pubsub, firestore, etc.).
class Firebase {
  Firebase() {
    _initializeAdminSDK();
  }

  FirebaseApp? _adminApp;
  gfs.Firestore? _firestoreInstance;

  /// Initialize the Firebase Admin SDK
  void _initializeAdminSDK() {
    // Get project ID from environment
    final projectId =
        Platform.environment['GCLOUD_PROJECT'] ??
        Platform.environment['GCP_PROJECT'] ??
        'demo-test'; // Fallback for emulator

    // Check if running in emulator
    final firestoreEmulatorHost =
        Platform.environment['FIRESTORE_EMULATOR_HOST'];
    final isEmulator = firestoreEmulatorHost != null;

    if (isEmulator) {
      // TODO: Implement direct REST API calls to emulator
      // For now, we'll skip document fetching in emulator mode
      return;
    }

    // Production mode only
    try {
      // Initialize Admin SDK
      _adminApp = FirebaseApp.initializeApp(
        options: AppOptions(
          credential: Credential.fromApplicationDefaultCredentials(),
          projectId: projectId,
        ),
      );

      // Create Firestore instance
      _firestoreInstance = _adminApp!.firestore();
    } catch (e) {
      print('Warning: Failed to initialize Firebase Admin SDK: $e');
    }
  }

  /// Get the Firestore instance
  gfs.Firestore? get firestoreAdmin => _firestoreInstance;

  /// Get the Firebase Admin App instance
  FirebaseApp? get adminApp => _adminApp;

  /// HTTPS triggers namespace.
  HttpsNamespace get https => HttpsNamespace(this);

  /// Pub/Sub triggers namespace.
  PubSubNamespace get pubsub => PubSubNamespace(this);

  /// Firestore triggers namespace.
  FirestoreNamespace get firestore => FirestoreNamespace(this);

  /// Eventarc triggers namespace.
  EventarcNamespace get eventarc => EventarcNamespace(this);

  /// Realtime Database triggers namespace.
  DatabaseNamespace get database => DatabaseNamespace(this);

  /// Firebase Alerts namespace.
  AlertsNamespace get alerts => AlertsNamespace(this);

  /// Identity Platform namespace.
  IdentityNamespace get identity => IdentityNamespace(this);

  /// Remote Config namespace.
  RemoteConfigNamespace get remoteConfig => RemoteConfigNamespace(this);

  /// Scheduler namespace.
  SchedulerNamespace get scheduler => SchedulerNamespace(this);

  /// Cloud Storage triggers namespace.
  StorageNamespace get storage => StorageNamespace(this);

  /// Task queue triggers namespace.
  TasksNamespace get tasks => TasksNamespace(this);

  /// Test Lab triggers namespace.
  TestLabNamespace get testLab => TestLabNamespace(this);
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
  /// [refPattern] is the Database ref path pattern (e.g., 'messages/{messageId}').
  void registerFunction(
    String name,
    FirebaseFunctionHandler handler, {
    bool external = false,
    String? documentPattern,
    String? refPattern,
  }) {
    // Check for duplicate function names
    if (functions.any((f) => f.name == name)) {
      throw StateError('Function "$name" is already registered');
    }

    // Transform the name to a valid Cloud Run service ID
    // (lowercase, digits, and hyphens only, <50 chars)
    final transformedName = toCloudRunId(name);

    functions.add(
      FirebaseFunctionDeclaration(
        name: transformedName,
        handler: handler,
        external: external,
        documentPattern: documentPattern,
        refPattern: refPattern,
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
    this.refPattern,
  }) : path = name;

  /// Function name (used for routing and identification).
  final String name;

  /// URL path for this function (derived from name).
  final String path;

  /// For Firestore triggers: the document path pattern (e.g., 'users/{userId}').
  /// Used for pattern matching against actual document paths.
  final String? documentPattern;

  /// For Database triggers: the ref path pattern (e.g., 'messages/{messageId}').
  /// Used for pattern matching against actual ref paths.
  final String? refPattern;

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
