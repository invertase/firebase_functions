import 'dart:async';
import 'package:shelf/shelf.dart';

import 'https/https_namespace.dart';
import 'pubsub/pubsub_namespace.dart';

/// Main Firebase Functions instance.
///
/// Provides access to all function namespaces (https, pubsub, etc.).
class Firebase {
  /// HTTPS triggers namespace.
  HttpsNamespace get https => HttpsNamespace(this);

  /// Pub/Sub triggers namespace.
  PubSubNamespace get pubsub => PubSubNamespace(this);
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
  void registerFunction(
    String name,
    FirebaseFunctionHandler handler, {
    bool external = false,
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
  }) : path = name;
  /// Function name (used for routing and identification).
  final String name;

  /// URL path for this function (derived from name).
  final String path;

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
