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

            // For now, just acknowledge the event since we don't have protobuf parsing
            print('Firestore onDocumentCreated triggered!');
            print('Document: ${request.headers['ce-document']}');
            print('Database: ${request.headers['ce-database']}');
            print('Namespace: ${request.headers['ce-namespace']}');

            // TODO: Parse protobuf body and create DocumentSnapshot
            // For now, execute handler with a placeholder event
            // await handler(event);

            return Response.ok('CloudEvent received (protobuf parsing TODO)');
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
}
