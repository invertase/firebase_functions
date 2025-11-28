import 'dart:async';

import 'package:dart_firebase_admin/firestore.dart'
    show QueryDocumentSnapshot, DocumentData;
import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

import '../common/cloud_event.dart';
import '../firebase.dart';
import 'event.dart';
import 'options.dart';

/// Firestore triggers namespace.
///
/// Provides methods to define Firestore-triggered Cloud Functions.
class FirestoreNamespace extends FunctionsNamespace {
  const FirestoreNamespace(super.firebase);

  /// Event handler that triggers when a document is created in Firestore.
  ///
  /// The handler receives a [FirestoreEvent] containing the [QueryDocumentSnapshot].
  ///
  /// Example:
  /// ```dart
  /// firebase.firestore.onDocumentCreated(
  ///   document: 'users/{userId}',
  ///   (event) async {
  ///     final snapshot = event.data;
  ///     print('New user created: ${snapshot.id}');
  ///     print('User data: ${snapshot.data()}');
  ///   },
  /// );
  /// ```
  void onDocumentCreated(
    Future<void> Function(
      FirestoreEvent<QueryDocumentSnapshot<DocumentData>> event,
    ) handler, {
    /// The Firestore document path to trigger on.
    /// Supports wildcards: 'users/{userId}', 'users/{userId}/posts/{postId}'
    // ignore: experimental_member_use
    @mustBeConst required String document,
    /// Options that can be set on an individual event-handling function.
    // ignore: experimental_member_use
    @mustBeConst DocumentOptions? options,
  }) {
    // Use the document path as the function name (sanitized)
    final functionName = _documentToFunctionName('onDocumentCreated', document);

    firebase.registerFunction(
      functionName,
      (request) async {
        try {
          // Check if this is binary content mode (CloudEvent in headers)
          final isBinaryMode = request.headers.containsKey('ce-type');

          if (isBinaryMode) {
            // Binary content mode: metadata in headers, data in body (protobuf)
            final ceType = request.headers['ce-type'];

            // Verify it's a Firestore document created event
            if (ceType != null && !_isFirestoreCreatedEvent(ceType)) {
              return Response(
                400,
                body: 'Invalid event type for Firestore onDocumentCreated: $ceType',
              );
            }

            // Extract metadata from CloudEvent headers
            final ceId = request.headers['ce-id'];
            final ceSource = request.headers['ce-source'];
            final ceTime = request.headers['ce-time'];
            final ceSubject = request.headers['ce-subject'];
            final documentPath = request.headers['ce-document'];
            final database = request.headers['ce-database'] ?? '(default)';
            final namespace = request.headers['ce-namespace'] ?? '(default)';

            if (ceId == null || ceSource == null || ceTime == null || documentPath == null) {
              return Response(
                400,
                body: 'Missing required CloudEvent headers',
              );
            }

            // Extract path parameters from document path
            final params = _extractParams(document, documentPath);

            // Print event information for debugging
            print('Firestore onDocumentCreated triggered!');
            print('Document: $documentPath');
            print('Database: $database');
            print('Namespace: $namespace');
            print('Params: $params');
            print('Event ID: $ceId');
            print('Event time: $ceTime');

            // TODO: Parse protobuf body to create DocumentSnapshot and call handler
            // The body contains protobuf-encoded document data that needs to be parsed
            // Once implemented, we'll create a FirestoreEvent with the actual DocumentSnapshot
            // and call: await handler(event)

            return Response.ok(
              'CloudEvent received. Protobuf parsing not yet implemented - '
              'handler will be called once document parsing is added.',
            );
          } else {
            // Structured content mode: full CloudEvent in JSON body
            final bodyString = await request.readAsString();
            final json = parseCloudEventJson(bodyString);

            // Validate CloudEvent structure
            validateCloudEvent(json);

            // Verify it's a Firestore document created event
            if (!_isFirestoreCreatedEvent(json['type'] as String)) {
              return Response(
                400,
                body:
                    'Invalid event type for Firestore onDocumentCreated: ${json['type']}',
              );
            }

            // Parse CloudEvent with QueryDocumentSnapshot data
            final event =
                FirestoreEvent<QueryDocumentSnapshot<DocumentData>>.fromJson(
              json,
              (data) {
                // TODO: Parse the actual DocumentSnapshot from CloudEvent data
                throw UnimplementedError(
                  'Firestore document snapshot parsing not yet implemented',
                );
              },
            );

            // Execute handler
            await handler(event);

            return Response.ok('');
          }
        } on FormatException catch (e) {
          return Response(
            400,
            body: 'Invalid CloudEvent: ${e.message}',
          );
        } catch (e, stackTrace) {
          return Response(
            500,
            body: 'Error processing Firestore event: $e\n$stackTrace',
          );
        }
      },
      documentPattern: document,
    );
  }

  /// Converts a document path to a function name.
  ///
  /// Examples:
  /// - 'users/{userId}' -> 'onDocumentCreated_users_userId'
  /// - 'users/user123' -> 'onDocumentCreated_users_user123'
  String _documentToFunctionName(String eventType, String documentPath) {
    // Remove leading/trailing slashes
    final cleaned = documentPath.replaceAll(RegExp(r'^/+|/+$'), '');

    // Replace path separators and wildcards with underscores
    final sanitized = cleaned
        .replaceAll('/', '_')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('-', '');

    return '${eventType}_$sanitized';
  }

  /// Checks if the CloudEvent type is a Firestore document created event.
  bool _isFirestoreCreatedEvent(String type) =>
      type == 'google.cloud.firestore.document.v1.created';

  /// Extracts path parameters from a document path by matching against a pattern.
  ///
  /// Example:
  /// - pattern: 'users/{userId}'
  /// - documentPath: 'users/abc123'
  /// - returns: {'userId': 'abc123'}
  Map<String, String> _extractParams(String pattern, String documentPath) {
    final params = <String, String>{};
    final patternParts = pattern.split('/');
    final documentParts = documentPath.split('/');

    if (patternParts.length != documentParts.length) {
      return params;
    }

    for (var i = 0; i < patternParts.length; i++) {
      final patternPart = patternParts[i];
      final documentPart = documentParts[i];

      // Extract parameter name from wildcards like {userId}
      if (patternPart.startsWith('{') && patternPart.endsWith('}')) {
        final paramName = patternPart.substring(1, patternPart.length - 1);
        params[paramName] = documentPart;
      }
    }

    return params;
  }

  /// Extracts the project ID from a CloudEvent source.
  ///
  /// Source format: //firestore.googleapis.com/projects/{project}/databases/{database}/...
  String _extractProject(String source) {
    final uri = Uri.parse(source.replaceFirst('//', 'https://'));
    final pathSegments = uri.pathSegments;

    // Find 'projects' segment and return the next one
    final projectIndex = pathSegments.indexOf('projects');
    if (projectIndex != -1 && projectIndex + 1 < pathSegments.length) {
      return pathSegments[projectIndex + 1];
    }

    return 'unknown-project';
  }
}
