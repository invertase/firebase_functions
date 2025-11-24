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
  final targetFunction = functions.cast<FirebaseFunctionDeclaration?>().firstWhere(
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
) {
  // Try to find a matching function by path
  for (final function in functions) {
    // Internal functions (events) only accept POST requests
    if (!function.external && request.method.toUpperCase() != 'POST') {
      continue;
    }

    // Match path
    if (requestPath == function.path) {
      return function.handler(request);
    }
  }

  // No matching function found
  return Response.notFound(
    'Function not found: $requestPath\n'
    'Available functions: ${functions.map((f) => f.name).join(", ")}',
  );
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
