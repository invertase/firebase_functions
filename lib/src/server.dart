import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:stack_trace/stack_trace.dart' show Trace;

import 'common/cloud_run_id.dart';
import 'common/on_init.dart';
import 'firebase.dart';
import 'logger/logger.dart';

/// Callback type for the user's function registration code.
typedef FunctionsRunner = FutureOr<void> Function(Firebase firebase);

/// Firebase emulator environment detection and configuration.
class EmulatorEnvironment {
  EmulatorEnvironment(this.environment);
  final Map<String, String> environment;

  /// Whether running in the Firebase emulator.
  bool get isEmulator => environment['FUNCTIONS_EMULATOR'] == 'true';

  /// Timezone setting.
  String get tz => environment['TZ'] ?? 'UTC';

  /// Whether debug mode is enabled.
  bool get debugMode => environment['FIREBASE_DEBUG_MODE'] == 'true';

  /// Whether to skip token verification (emulator only).
  bool get skipTokenVerification {
    if (!environment.containsKey('FIREBASE_DEBUG_FEATURES')) {
      return false;
    }
    try {
      final features = jsonDecode(environment['FIREBASE_DEBUG_FEATURES']!);
      return features['skipTokenVerification'] as bool? ?? false;
    } on FormatException {
      return false;
    }
  }

  /// Whether CORS is enabled (emulator only).
  bool get enableCors {
    if (!environment.containsKey('FIREBASE_DEBUG_FEATURES')) {
      return false;
    }
    try {
      final features = jsonDecode(environment['FIREBASE_DEBUG_FEATURES']!);
      return features['enableCors'] as bool? ?? false;
    } on FormatException {
      return false;
    }
  }
}

/// Starts the Firebase Functions runtime.
///
/// This is the main entry point for a Firebase Functions application.
///
/// Example:
/// ```dart
/// void main(List<String> args) {
///   fireUp(args, (firebase) {
///     firebase.https.onRequest(
///       name: 'hello',
///       (request) async => Response.ok('Hello!'),
///     );
///   });
/// }
/// ```
Future<void> fireUp(List<String> args, FunctionsRunner runner) async {
  final firebase = Firebase();
  final emulatorEnv = EmulatorEnvironment(Platform.environment);

  // Run user's function registration code
  await runner(firebase);

  // Build request handler with middleware pipeline
  final handler = const Pipeline()
      .addMiddleware(_corsMiddleware(emulatorEnv))
      .addHandler((request) => _routeRequest(request, firebase, emulatorEnv));

  // Start HTTP server
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
}

/// CORS middleware for emulator mode.
Middleware _corsMiddleware(EmulatorEnvironment env) =>
    (innerHandler) => (request) {
      // Handle preflight OPTIONS requests
      if (env.enableCors && request.method.toUpperCase() == 'OPTIONS') {
        return Response.ok(
          '',
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': '*',
            'Access-Control-Allow-Headers': '*',
          },
        );
      }

      return Future.sync(() => innerHandler(request)).then((response) {
        // Add CORS headers to all responses if enabled
        if (env.enableCors) {
          return response.change(
            headers: {
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': '*',
              'Access-Control-Allow-Headers': '*',
            },
          );
        }
        return response;
      });
    };

/// Routes incoming requests to the appropriate function handler.
FutureOr<Response> _routeRequest(
  Request request,
  Firebase firebase,
  EmulatorEnvironment env,
) {
  final functions = firebase.functions;
  final requestPath = request.url.path;

  // Handle special Node.js-compatible endpoints
  if (requestPath == '__/health') {
    // Health check endpoint (used by Firebase emulator)
    return Response.ok('OK');
  }

  if (requestPath == '__/quitquitquit') {
    // Graceful shutdown endpoint (used by Cloud Run)
    return _handleQuitQuitQuit(request);
  }

  if (requestPath == '__/functions.yaml' &&
      env.environment['FUNCTIONS_CONTROL_API'] == 'true') {
    // Manifest endpoint for function discovery
    return _handleFunctionsManifest(request, firebase);
  }

  // FUNCTION_TARGET mode (production): Serve only the specified function
  // This matches Node.js behavior where each Cloud Run service runs one function
  final functionTarget = env.environment['FUNCTION_TARGET'];
  if (functionTarget != null && functionTarget.isNotEmpty) {
    return _routeToTargetFunction(request, firebase, env, functionTarget);
  }

  // Shared process mode (development): Route by path
  return _routeByPath(request, functions, requestPath);
}

/// Routes request to the function specified by FUNCTION_TARGET.
///
/// This matches Node.js production behavior where FUNCTION_TARGET is set
/// by Cloud Run to specify which function this process instance serves.
FutureOr<Response> _routeToTargetFunction(
  Request request,
  Firebase firebase,
  EmulatorEnvironment env,
  String functionTarget,
) {
  final functions = firebase.functions;

  // Find the function with matching name
  final targetFunction = functions
      .cast<FirebaseFunctionDeclaration?>()
      .firstWhere((f) => f?.name == functionTarget, orElse: () => null);

  if (targetFunction == null) {
    return Response.notFound(
      'Function "$functionTarget" not found. '
      'Available functions: ${functions.map((f) => f.name).join(", ")}',
    );
  }

  // Note: FUNCTION_SIGNATURE_TYPE validation is skipped for Dart Cloud Run
  // deployments. All Dart functions (onRequest, onCall, event triggers) are
  // served via HTTP in a single process, so the signature type distinction
  // from the Node.js model does not apply here.

  // Validate HTTP method for event functions
  if (!targetFunction.external && request.method.toUpperCase() != 'POST') {
    return Response(
      405,
      body: 'Event function "$functionTarget" only accepts POST requests',
      headers: {'Allow': 'POST'},
    );
  }

  // Execute the target function (all requests go to this function)
  // Wrap with onInit to ensure initialization callback runs before first execution
  final wrappedHandler = withInit(targetFunction.handler);
  return wrappedHandler(request);
}

/// Routes request by path matching (development/shared process mode).
FutureOr<Response> _routeByPath(
  Request request,
  List<FirebaseFunctionDeclaration> functions,
  String requestPath,
) async {
  // Use a local variable for the potentially reconstructed request
  var currentRequest = request;

  // For POST requests, check if this is a CloudEvent first (binary or structured mode)
  // CloudEvents have all the routing info in headers, so check those before path parsing
  if (request.method.toUpperCase() == 'POST') {
    final (reconstructedRequest, matchedFunction) =
        await _tryMatchCloudEventFunction(request, functions);
    if (matchedFunction != null) {
      // Use the recreated request with the body since we consumed the original
      // Wrap with onInit to ensure initialization callback runs before first execution
      final wrappedHandler = withInit(matchedFunction.handler);
      return wrappedHandler(reconstructedRequest);
    }
    // Use the reconstructed request for further processing
    currentRequest = reconstructedRequest;
  }

  // Not a CloudEvent, try path-based routing for HTTPS functions
  // Extract the function name from the path (/{functionName})
  // The firebase-tools emulator sets X-Firebase-Function header for Dart runtimes
  var functionName = _extractFunctionName(requestPath);

  // Fallback: Check for X-Firebase-Function header set by firebase-tools
  if (functionName.isEmpty) {
    functionName = currentRequest.headers['x-firebase-function'] ?? '';
  }

  // Try to find a matching function by name
  for (final function in functions) {
    // Internal functions (events) only accept POST requests
    if (!function.external && currentRequest.method.toUpperCase() != 'POST') {
      continue;
    }

    // Match by function name
    if (functionName == function.name) {
      // Wrap with onInit to ensure initialization callback runs before first execution
      final wrappedHandler = withInit(function.handler);
      return wrappedHandler(currentRequest);
    }
  }

  // No matching function found
  return Response.notFound(
    'Function not found: $functionName\n'
    'Available functions: ${functions.map((f) => f.name).join(", ")}',
  );
}

/// Tries to match a function by parsing CloudEvent headers or body.
///
/// Supports both:
/// - Binary content mode: CloudEvent metadata in ce-* headers, protobuf body
/// - Structured content mode: CloudEvent as JSON body
///
/// Returns a record of (Request, FirebaseFunctionDeclaration?) where the Request
/// is recreated with the body if we consumed the original stream.
/// The FirebaseFunctionDeclaration is null if this is not a CloudEvent request.
Future<(Request, FirebaseFunctionDeclaration?)> _tryMatchCloudEventFunction(
  Request request,
  List<FirebaseFunctionDeclaration> functions,
) async {
  try {
    String? bodyString; // Only set for structured mode
    final isBinaryMode =
        request.headers.containsKey('ce-type') &&
        request.headers.containsKey('ce-source');

    String source;
    String type;

    // Check for binary content mode (CloudEvent metadata in headers)
    if (isBinaryMode) {
      final ceType = request.headers['ce-type'];
      final ceSource = request.headers['ce-source'];

      if (ceType == null || ceSource == null) {
        return (request, null);
      }

      type = ceType;
      source = ceSource;
    } else {
      // Check content-type to see if this might be structured mode
      final contentType = request.headers['content-type'];
      final isJson = contentType?.contains('application/json') ?? false;
      final isCloudEvent =
          contentType?.contains('application/cloudevents') ?? false;
      if (!isJson && !isCloudEvent) {
        return (request, null);
      }

      // Structured content mode - try to parse JSON body
      bodyString = await request.readAsString();

      final body = jsonDecode(bodyString) as Map<String, dynamic>;

      // Check if this is a valid CloudEvent - if not, return reconstructed request
      if (!body.containsKey('source') || !body.containsKey('type')) {
        // Return the reconstructed request since we consumed the body
        return (request.change(body: bodyString), null);
      }

      source = body['source'] as String;
      type = body['type'] as String;
    }

    // Now we have source and type from either headers or body
    // Handle Pub/Sub CloudEvents
    // Source format: //pubsub.googleapis.com/projects/{project}/topics/{topic}
    if (type == 'google.cloud.pubsub.topic.v1.messagePublished' &&
        source.contains('/topics/')) {
      final topicName = source.split('/topics/').last;

      // Sanitize topic name to match function naming convention
      // Topic "my-topic" becomes function "on-message-published-mytopic"
      final sanitizedTopic = topicName.replaceAll('-', '').toLowerCase();
      final expectedFunctionName = toCloudRunId(
        'onMessagePublished_$sanitizedTopic',
      );

      // Try to find a matching function
      for (final function in functions) {
        if (function.name == expectedFunctionName && !function.external) {
          // For structured mode, recreate request with body; for binary mode, use original
          final newRequest = bodyString != null
              ? request.change(body: bodyString)
              : request;
          return (newRequest, function);
        }
      }
    }

    // Handle Firestore CloudEvents
    // Source format: //firestore.googleapis.com/projects/{project}/databases/{database}/documents/{document}
    // Or use ce-document header in binary mode
    // Event types:
    // - google.cloud.firestore.document.v1.created
    // - google.cloud.firestore.document.v1.updated
    // - google.cloud.firestore.document.v1.deleted
    // - google.cloud.firestore.document.v1.written
    if (type.startsWith('google.cloud.firestore.document.v1.')) {
      // Extract document path from ce-document header (binary mode) or source (structured mode)
      String? documentPath;
      if (isBinaryMode && request.headers.containsKey('ce-document')) {
        documentPath = request.headers['ce-document'];
      } else if (source.contains('/documents/')) {
        documentPath = source.split('/documents/').last;
      }

      if (documentPath != null) {
        // Map CloudEvent type to method name
        final methodName = _mapCloudEventTypeToFirestoreMethod(type);
        if (methodName != null) {
          final methodPrefix = toCloudRunId(methodName);
          // Try to find a matching function by pattern matching
          for (final function in functions) {
            if (!function.external && function.name.startsWith(methodPrefix)) {
              // Check if this function has a document pattern to match against
              if (function.documentPattern != null) {
                if (_matchesDocumentPattern(
                  documentPath,
                  function.documentPattern!,
                )) {
                  // For structured mode, recreate request with body; for binary mode, use original
                  final newRequest = bodyString != null
                      ? request.change(body: bodyString)
                      : request;
                  return (newRequest, function);
                }
              }
            }
          }
        }
      }
    }

    // Handle Realtime Database CloudEvents
    // Event types:
    // - google.firebase.database.ref.v1.created
    // - google.firebase.database.ref.v1.updated
    // - google.firebase.database.ref.v1.deleted
    // - google.firebase.database.ref.v1.written
    // Binary mode headers: ce-ref (path), ce-instance (database instance)
    if (type.startsWith('google.firebase.database.ref.v1.')) {
      // Extract ref path from ce-ref header (binary mode)
      String? refPath;
      if (isBinaryMode && request.headers.containsKey('ce-ref')) {
        refPath = request.headers['ce-ref'];
      }

      if (refPath != null) {
        // Map CloudEvent type to method name
        final methodName = _mapCloudEventTypeToDatabaseMethod(type);
        if (methodName != null) {
          final methodPrefix = toCloudRunId(methodName);
          // Try to find a matching function by pattern matching
          for (final function in functions) {
            if (!function.external && function.name.startsWith(methodPrefix)) {
              // Check if this function has a ref pattern to match against
              if (function.refPattern != null) {
                if (_matchesRefPattern(refPath, function.refPattern!)) {
                  // For structured mode, recreate request with body; for binary mode, use original
                  final newRequest = bodyString != null
                      ? request.change(body: bodyString)
                      : request;
                  return (newRequest, function);
                }
              }
            }
          }
        }
      }
    }

    // Handle Storage CloudEvents
    // Source format: //storage.googleapis.com/projects/_/buckets/{bucket}
    // Event types:
    // - google.cloud.storage.object.v1.archived
    // - google.cloud.storage.object.v1.finalized
    // - google.cloud.storage.object.v1.deleted
    // - google.cloud.storage.object.v1.metadataUpdated
    if (type.startsWith('google.cloud.storage.object.v1.')) {
      // Extract bucket name from source URL
      // Source format: //storage.googleapis.com/projects/_/buckets/{bucket}/objects/{path}
      // or just: //storage.googleapis.com/projects/_/buckets/{bucket}
      String? bucketName;
      if (source.contains('/buckets/')) {
        final afterBuckets = source.split('/buckets/').last;
        // Bucket name is the first path segment (before any /objects/... suffix)
        bucketName = afterBuckets.split('/').first;
      }

      if (bucketName != null) {
        // Map CloudEvent type to method name
        final methodName = _mapCloudEventTypeToStorageMethod(type);
        if (methodName != null) {
          // Sanitize bucket name to match function naming convention
          final sanitizedBucket = bucketName.replaceAll(
            RegExp('[^a-zA-Z0-9]'),
            '',
          );
          final expectedFunctionName = toCloudRunId(
            '${methodName}_$sanitizedBucket',
          );

          // Try to find a matching function
          for (final function in functions) {
            if (function.name == expectedFunctionName && !function.external) {
              final newRequest = bodyString != null
                  ? request.change(body: bodyString)
                  : request;
              return (newRequest, function);
            }
          }
        }
      }
    }

    // TODO: Add support for other CloudEvent types (Auth, etc.)

    // No CloudEvent function matched - return reconstructed request if we read the body
    final finalRequest = bodyString != null
        ? request.change(body: bodyString)
        : request;
    return (finalRequest, null);
  } catch (e, stackTrace) {
    // CloudEvent parsing failed - not a CloudEvent request
    logger.warn(
      'CloudEvent parsing failed: $e\n${Trace.from(stackTrace).terse}',
    );
    return (request, null);
  }
}

/// Extracts the function name from a request path.
///
/// Handles different path formats:
/// - Event triggers: /functions/projects/{project}/triggers/{triggerId} -> {entryPoint}
/// - HTTPS functions: /{functionName} -> {functionName}
/// - HTTPS with project/region: /{project}/{region}/{functionName} -> {functionName}
///
/// For event triggers, the triggerId may include region prefix like "us-central1-functionName"
/// We need to extract just the function name part.
String _extractFunctionName(String requestPath) {
  // Remove leading and trailing slashes
  var path = requestPath;
  if (path.startsWith('/')) {
    path = path.substring(1);
  }
  if (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  // Event trigger path: functions/projects/{project}/triggers/{triggerId}
  if (path.startsWith('functions/projects/')) {
    final parts = path.split('/');
    if (parts.length >= 5 && parts[3] == 'triggers') {
      // Extract trigger ID from: functions/projects/{project}/triggers/{triggerId}
      var triggerId = parts[4];

      // Firebase-tools prefixes trigger IDs with region (e.g., "us-central1-functionName")
      // and may add suffixes (e.g., "us-central1-functionName-0")
      // We need to strip these to get the actual function entry point name.

      // Remove region prefix (e.g., "us-central1-", "europe-west1-")
      triggerId = triggerId.replaceFirst(RegExp(r'^[a-z]+-[a-z]+\d+-'), '');

      // Remove numeric suffix (e.g., "-0", "-1")
      triggerId = triggerId.replaceFirst(RegExp(r'-\d+$'), '');

      return triggerId;
    }
  }

  // HTTPS path: {project}/{region}/{functionName} or just {functionName}
  final parts = path.split('/');

  // If path has 3 parts, assume {project}/{region}/{functionName}
  if (parts.length == 3) {
    return parts[2];
  }

  // If path has 1 part, it's just {functionName}
  if (parts.length == 1) {
    return parts[0];
  }

  // Return the last part as function name
  return parts.isNotEmpty ? parts.last : path;
}

/// Handles the /__/quitquitquit graceful shutdown endpoint.
///
/// This endpoint is used by Cloud Run to signal graceful shutdown.
/// Matches Node.js implementation in firebase-functions.
Response _handleQuitQuitQuit(Request request) {
  // Accept both GET and POST like Node.js does
  if (request.method != 'GET' && request.method != 'POST') {
    return Response(405, headers: {'Allow': 'GET, POST'});
  }

  // In Node.js, this closes the HTTP server
  // In Dart, we'll just acknowledge the request
  // Actual shutdown would need to be handled by the server instance
  return Response.ok('OK');
}

/// Handles the /__/functions.yaml manifest endpoint.
///
/// Returns the functions manifest when FUNCTIONS_CONTROL_API is enabled.
/// This is used by firebase-tools for function discovery.
FutureOr<Response> _handleFunctionsManifest(
  Request request,
  Firebase firebase,
) {
  if (request.method != 'GET') {
    return Response(405, headers: {'Allow': 'GET'});
  }

  // Read the generated manifest file
  final manifestPath = 'functions.yaml';
  final manifestFile = File(manifestPath);

  if (!manifestFile.existsSync()) {
    return Response.notFound(
      'functions.yaml not found at $manifestPath. '
      'Run "dart run build_runner build" to generate it.',
    );
  }

  final manifestContent = manifestFile.readAsStringSync();
  return Response.ok(
    manifestContent,
    headers: {'Content-Type': 'text/yaml; charset=utf-8'},
  );
}

/// Maps Firestore CloudEvent type to method name.
String? _mapCloudEventTypeToFirestoreMethod(String eventType) =>
    switch (eventType) {
      'google.cloud.firestore.document.v1.created' => 'onDocumentCreated',
      'google.cloud.firestore.document.v1.updated' => 'onDocumentUpdated',
      'google.cloud.firestore.document.v1.deleted' => 'onDocumentDeleted',
      'google.cloud.firestore.document.v1.written' => 'onDocumentWritten',
      _ => null,
    };

/// Matches a document path against a pattern with wildcards.
///
/// Examples:
/// - 'users/123' matches 'users/{userId}'
/// - 'users/123/posts/456' matches 'users/{userId}/posts/{postId}'
/// - 'users/123' does NOT match 'posts/{postId}'
bool _matchesDocumentPattern(String documentPath, String pattern) {
  // Split both paths by '/'
  final docParts = documentPath.split('/');
  final patternParts = pattern.split('/');

  // Paths must have same number of segments
  if (docParts.length != patternParts.length) {
    return false;
  }

  // Check each segment
  for (var i = 0; i < docParts.length; i++) {
    final docPart = docParts[i];
    final patternPart = patternParts[i];

    // If pattern part is a wildcard (contains {})
    if (patternPart.startsWith('{') && patternPart.endsWith('}')) {
      // Wildcard matches any value
      continue;
    }

    // Not a wildcard - must match exactly
    if (docPart != patternPart) {
      return false;
    }
  }

  return true;
}

/// Maps Database CloudEvent type to method name.
String? _mapCloudEventTypeToDatabaseMethod(String eventType) =>
    switch (eventType) {
      'google.firebase.database.ref.v1.created' => 'onValueCreated',
      'google.firebase.database.ref.v1.updated' => 'onValueUpdated',
      'google.firebase.database.ref.v1.deleted' => 'onValueDeleted',
      'google.firebase.database.ref.v1.written' => 'onValueWritten',
      _ => null,
    };

/// Maps Storage CloudEvent type to method name.
String? _mapCloudEventTypeToStorageMethod(String eventType) =>
    switch (eventType) {
      'google.cloud.storage.object.v1.archived' => 'onObjectArchived',
      'google.cloud.storage.object.v1.finalized' => 'onObjectFinalized',
      'google.cloud.storage.object.v1.deleted' => 'onObjectDeleted',
      'google.cloud.storage.object.v1.metadataUpdated' =>
        'onObjectMetadataUpdated',
      _ => null,
    };

/// Matches a database ref path against a pattern with wildcards.
///
/// Examples:
/// - 'messages/abc123' matches 'messages/{messageId}'
/// - 'users/123/status' matches 'users/{userId}/status'
/// - 'messages/abc123' does NOT match 'users/{userId}'
bool _matchesRefPattern(String refPath, String pattern) {
  // Split both paths by '/'
  final refParts = refPath.split('/');
  final patternParts = pattern.split('/');

  // Paths must have same number of segments
  if (refParts.length != patternParts.length) {
    return false;
  }

  // Check each segment
  for (var i = 0; i < refParts.length; i++) {
    final refPart = refParts[i];
    final patternPart = patternParts[i];

    // If pattern part is a wildcard (contains {})
    if (patternPart.startsWith('{') && patternPart.endsWith('}')) {
      // Wildcard matches any value
      continue;
    }

    // Not a wildcard - must match exactly
    if (refPart != patternPart) {
      return false;
    }
  }

  return true;
}
