import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'firebase.dart';

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
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware(emulatorEnv))
      .addHandler((request) => _routeRequest(request, firebase, emulatorEnv));

  // Start HTTP server
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    port,
  );

  print(
    'Firebase Functions serving at http://${server.address.host}:${server.port}',
  );
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
    return _routeToTargetFunction(
      request,
      firebase,
      env,
      functionTarget,
    );
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
  final targetFunction =
      functions.cast<FirebaseFunctionDeclaration?>().firstWhere(
            (f) => f?.name == functionTarget,
            orElse: () => null,
          );

  if (targetFunction == null) {
    return Response.notFound(
      'Function "$functionTarget" not found. '
      'Available functions: ${functions.map((f) => f.name).join(", ")}',
    );
  }

  // Validate signature type if specified
  final signatureType = env.environment['FUNCTION_SIGNATURE_TYPE'];
  if (signatureType != null) {
    final isHttpSignature = signatureType == 'http';
    final isHttpFunction = targetFunction.external;

    // Signature type mismatch
    if (isHttpSignature && !isHttpFunction) {
      return Response.internalServerError(
        body:
            'Function "$functionTarget" is an event function but FUNCTION_SIGNATURE_TYPE=http',
      );
    }
    if (!isHttpSignature && isHttpFunction) {
      return Response.internalServerError(
        body:
            'Function "$functionTarget" is an HTTP function but FUNCTION_SIGNATURE_TYPE=$signatureType',
      );
    }
  }

  // Validate HTTP method for event functions
  if (!targetFunction.external && request.method.toUpperCase() != 'POST') {
    return Response(
      405,
      body: 'Event function "$functionTarget" only accepts POST requests',
      headers: {'Allow': 'POST'},
    );
  }

  // Execute the target function (all requests go to this function)
  return targetFunction.handler(request);
}

/// Routes request by path matching (development/shared process mode).
FutureOr<Response> _routeByPath(
  Request request,
  List<FirebaseFunctionDeclaration> functions,
  String requestPath,
) async {
  // Extract the function name from the path
  // Event triggers come as: /functions/projects/{project}/triggers/{triggerId}
  // HTTPS functions come as: /{functionName} (already stripped by firebase-tools)
  final functionName = _extractFunctionName(requestPath);

  // Try to find a matching function by name
  for (final function in functions) {
    // Internal functions (events) only accept POST requests
    if (!function.external && request.method.toUpperCase() != 'POST') {
      continue;
    }

    // Match by function name
    if (functionName == function.name) {
      return function.handler(request);
    }
  }

  // Fallback: If path extraction failed and this is a POST request with CloudEvent,
  // try to extract the function name from the CloudEvent body
  if (functionName.isEmpty &&
      request.method.toUpperCase() == 'POST' &&
      (request.headers['content-type']?.contains('application/json') ?? false)) {
    final result = await _tryMatchCloudEventFunction(request, functions);
    if (result != null) {
      // Use the recreated request with the body since we consumed the original
      return result.$2.handler(result.$1);
    }
  }

  // No matching function found
  return Response.notFound(
    'Function not found: $requestPath\n'
    'Available functions: ${functions.map((f) => f.name).join(", ")}',
  );
}

/// Tries to match a function by parsing the CloudEvent body.
///
/// This is a fallback for when path-based routing fails.
/// Supports Pub/Sub CloudEvents by extracting the topic from the source field.
///
/// Returns a record of (Request, FirebaseFunctionDeclaration) where the Request
/// is recreated with the body since we consumed the original stream.
Future<(Request, FirebaseFunctionDeclaration)?> _tryMatchCloudEventFunction(
  Request request,
  List<FirebaseFunctionDeclaration> functions,
) async {
  try {
    // Read and parse the request body as JSON
    final bodyString = await request.readAsString();
    final body = jsonDecode(bodyString) as Map<String, dynamic>;

    // Check if this is a valid CloudEvent
    if (!body.containsKey('source') || !body.containsKey('type')) {
      return null;
    }

    final source = body['source'] as String;
    final type = body['type'] as String;

    // Handle Pub/Sub CloudEvents
    // Source format: //pubsub.googleapis.com/projects/{project}/topics/{topic}
    if (type == 'google.cloud.pubsub.topic.v1.messagePublished' &&
        source.contains('/topics/')) {
      final topicName = source.split('/topics/').last;

      // Sanitize topic name to match function naming convention
      // Topic "my-topic" becomes function "onMessagePublished_mytopic"
      final sanitizedTopic = topicName.replaceAll('-', '').toLowerCase();
      final expectedFunctionName = 'onMessagePublished_$sanitizedTopic';

      // Try to find a matching function
      for (final function in functions) {
        if (function.name == expectedFunctionName && !function.external) {
          print(
            'CloudEvent fallback matched topic "$topicName" to function "$expectedFunctionName"',
          );

          // Recreate the request with the body since we consumed the stream
          final newRequest = request.change(body: bodyString);
          return (newRequest, function);
        }
      }
    }

    // TODO: Add support for other CloudEvent types (Firestore, Storage, etc.)

    return null;
  } catch (e) {
    print('Failed to parse CloudEvent for function matching: $e');
    return null;
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
  // Remove leading slash
  var path = requestPath;
  if (path.startsWith('/')) {
    path = path.substring(1);
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
  print('Received shutdown signal via /__/quitquitquit');

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
  final manifestPath = '.dart_tool/firebase/functions.yaml';
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
