import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

import '../common/cloud_event.dart';
import '../firebase.dart';
import 'document_snapshot.dart';
import 'event.dart';
import 'options.dart';
import 'protobuf_parser.dart';

/// Firestore triggers namespace.
///
/// Provides methods to define Firestore-triggered Cloud Functions.
class FirestoreNamespace extends FunctionsNamespace {
  const FirestoreNamespace(super.firebase);

  /// Event handler that triggers when a document is created in Firestore.
  ///
  /// The handler receives a [FirestoreEvent] containing an [EmulatorDocumentSnapshot].
  ///
  /// Example:
  /// ```dart
  /// firebase.firestore.onDocumentCreated(
  ///   document: 'users/{userId}',
  ///   (event) async {
  ///     // Access document data (similar to Node.js)
  ///     final data = event.data?.data();
  ///     print('User data: $data');
  ///     print('User name: ${data?['name']}');
  ///
  ///     // Access path parameters
  ///     print('User ID: ${event.params['userId']}');
  ///
  ///     // Access document metadata
  ///     print('Document path: ${event.document}');
  ///     print('Document ID: ${event.data?.id}');
  ///   },
  /// );
  /// ```
  void onDocumentCreated(
    Future<void> Function(FirestoreEvent<EmulatorDocumentSnapshot?> event)
    handler, {

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

    firebase.registerFunction(functionName, (request) async {
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
              body:
                  'Invalid event type for Firestore onDocumentCreated: $ceType',
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

          if (ceId == null ||
              ceSource == null ||
              ceTime == null ||
              documentPath == null) {
            return Response(400, body: 'Missing required CloudEvent headers');
          }

          // Extract path parameters from document path
          final params = _extractParams(document, documentPath);

          // Parse protobuf body to get document snapshot
          EmulatorDocumentSnapshot? snapshot;
          try {
            final bodyBytes = await request.read().fold<List<int>>(
              [],
              (previous, element) => previous..addAll(element),
            );

            if (bodyBytes.isNotEmpty) {
              final parsed = parseDocumentEventData(
                Uint8List.fromList(bodyBytes),
              );

              if (parsed != null) {
                snapshot = parsed['value'];
              }
            }
          } catch (_) {
            // Protobuf parsing failed - snapshot remains null
          }

          // Create event with parsed document snapshot
          try {
            final event = FirestoreEvent<EmulatorDocumentSnapshot?>(
              data: snapshot,
              id: ceId,
              source: ceSource,
              specversion: '1.0',
              subject: ceSubject,
              time: DateTime.parse(ceTime),
              type: ceType!,
              location: 'us-central1',
              project: _extractProject(ceSource),
              database: database,
              namespace: namespace,
              document: documentPath,
              params: params,
            );

            await handler(event);
          } catch (e) {
            return Response(500, body: 'Handler error: $e');
          }

          return Response.ok('');
        } else {
          // Structured content mode: full CloudEvent in JSON body
          final json = await parseAndValidateCloudEvent(request);

          // Verify it's a Firestore document created event
          if (!_isFirestoreCreatedEvent(json['type'] as String)) {
            return Response(
              400,
              body:
                  'Invalid event type for Firestore onDocumentCreated: ${json['type']}',
            );
          }

          // Parse CloudEvent with EmulatorDocumentSnapshot data
          final event = FirestoreEvent<EmulatorDocumentSnapshot?>.fromJson(
            json,
            (data) {
              // TODO: Parse protobuf data from structured CloudEvent
              // For now, return null until protobuf parsing is implemented
              return null;
            },
          );

          // Execute handler
          await handler(event);

          return Response.ok('');
        }
      } on FormatException catch (e) {
        return Response(400, body: 'Invalid CloudEvent: ${e.message}');
      } catch (e, stackTrace) {
        return Response(
          500,
          body: 'Error processing Firestore event: $e\n$stackTrace',
        );
      }
    }, documentPattern: document);
  }

  /// Event handler that triggers when a document is updated in Firestore.
  ///
  /// The handler receives a [FirestoreEvent] containing a [Change] object
  /// with `before` and `after` snapshots.
  ///
  /// Example:
  /// ```dart
  /// firebase.firestore.onDocumentUpdated(
  ///   document: 'users/{userId}',
  ///   (event) async {
  ///     final before = event.data?.before.data();
  ///     final after = event.data?.after.data();
  ///
  ///     print('User ${event.params['userId']} updated');
  ///     print('Old name: ${before?['name']}');
  ///     print('New name: ${after?['name']}');
  ///   },
  /// );
  /// ```
  void onDocumentUpdated(
    Future<void> Function(
      FirestoreEvent<Change<EmulatorDocumentSnapshot>?> event,
    )
    handler, {

    /// The Firestore document path to trigger on.
    /// Supports wildcards: 'users/{userId}', 'users/{userId}/posts/{postId}'
    // ignore: experimental_member_use
    @mustBeConst required String document,

    /// Options that can be set on an individual event-handling function.
    // ignore: experimental_member_use
    @mustBeConst DocumentOptions? options,
  }) {
    final functionName = _documentToFunctionName('onDocumentUpdated', document);

    firebase.registerFunction(functionName, (request) async {
      try {
        final isBinaryMode = request.headers.containsKey('ce-type');

        if (isBinaryMode) {
          final ceType = request.headers['ce-type'];

          if (ceType != null && !_isFirestoreUpdatedEvent(ceType)) {
            return Response(
              400,
              body:
                  'Invalid event type for Firestore onDocumentUpdated: $ceType',
            );
          }

          final ceId = request.headers['ce-id'];
          final ceSource = request.headers['ce-source'];
          final ceTime = request.headers['ce-time'];
          final ceSubject = request.headers['ce-subject'];
          final documentPath = request.headers['ce-document'];
          final database = request.headers['ce-database'] ?? '(default)';
          final namespace = request.headers['ce-namespace'] ?? '(default)';

          if (ceId == null ||
              ceSource == null ||
              ceTime == null ||
              documentPath == null) {
            return Response(400, body: 'Missing required CloudEvent headers');
          }

          final params = _extractParams(document, documentPath);

          // Parse protobuf body to get before/after snapshots
          EmulatorDocumentSnapshot? beforeSnapshot;
          EmulatorDocumentSnapshot? afterSnapshot;
          try {
            final bodyBytes = await request.read().fold<List<int>>(
              [],
              (previous, element) => previous..addAll(element),
            );

            if (bodyBytes.isNotEmpty) {
              final parsed = parseDocumentEventData(
                Uint8List.fromList(bodyBytes),
              );

              if (parsed != null) {
                beforeSnapshot = parsed['old_value'];
                afterSnapshot = parsed['value'];
              }
            }
          } catch (_) {
            // Protobuf parsing failed - snapshots remain null
          }

          try {
            final change = Change<EmulatorDocumentSnapshot>(
              before: beforeSnapshot,
              after: afterSnapshot,
            );

            final event = FirestoreEvent<Change<EmulatorDocumentSnapshot>?>(
              data: change,
              id: ceId,
              source: ceSource,
              specversion: '1.0',
              subject: ceSubject,
              time: DateTime.parse(ceTime),
              type: ceType!,
              location: 'us-central1',
              project: _extractProject(ceSource),
              database: database,
              namespace: namespace,
              document: documentPath,
              params: params,
            );

            await handler(event);
          } catch (e) {
            return Response(500, body: 'Handler error: $e');
          }

          return Response.ok('');
        } else {
          return Response(
            501,
            body:
                'Structured CloudEvent mode not yet supported for onDocumentUpdated',
          );
        }
      } catch (e, stackTrace) {
        return Response(
          500,
          body: 'Error processing Firestore event: $e\n$stackTrace',
        );
      }
    }, documentPattern: document);
  }

  /// Event handler that triggers when a document is deleted in Firestore.
  ///
  /// The handler receives a [FirestoreEvent] containing the deleted document snapshot.
  ///
  /// Example:
  /// ```dart
  /// firebase.firestore.onDocumentDeleted(
  ///   document: 'users/{userId}',
  ///   (event) async {
  ///     final deletedData = event.data?.data();
  ///     print('User ${event.params['userId']} deleted');
  ///     print('Final data: $deletedData');
  ///   },
  /// );
  /// ```
  void onDocumentDeleted(
    Future<void> Function(FirestoreEvent<EmulatorDocumentSnapshot?> event)
    handler, {

    /// The Firestore document path to trigger on.
    /// Supports wildcards: 'users/{userId}', 'users/{userId}/posts/{postId}'
    // ignore: experimental_member_use
    @mustBeConst required String document,

    /// Options that can be set on an individual event-handling function.
    // ignore: experimental_member_use
    @mustBeConst DocumentOptions? options,
  }) {
    final functionName = _documentToFunctionName('onDocumentDeleted', document);

    firebase.registerFunction(functionName, (request) async {
      try {
        final isBinaryMode = request.headers.containsKey('ce-type');

        if (isBinaryMode) {
          final ceType = request.headers['ce-type'];

          if (ceType != null && !_isFirestoreDeletedEvent(ceType)) {
            return Response(
              400,
              body:
                  'Invalid event type for Firestore onDocumentDeleted: $ceType',
            );
          }

          final ceId = request.headers['ce-id'];
          final ceSource = request.headers['ce-source'];
          final ceTime = request.headers['ce-time'];
          final ceSubject = request.headers['ce-subject'];
          final documentPath = request.headers['ce-document'];
          final database = request.headers['ce-database'] ?? '(default)';
          final namespace = request.headers['ce-namespace'] ?? '(default)';

          if (ceId == null ||
              ceSource == null ||
              ceTime == null ||
              documentPath == null) {
            return Response(400, body: 'Missing required CloudEvent headers');
          }

          final params = _extractParams(document, documentPath);

          // Parse protobuf body to get deleted document snapshot
          EmulatorDocumentSnapshot? snapshot;
          try {
            final bodyBytes = await request.read().fold<List<int>>(
              [],
              (previous, element) => previous..addAll(element),
            );

            if (bodyBytes.isNotEmpty) {
              final parsed = parseDocumentEventData(
                Uint8List.fromList(bodyBytes),
              );

              if (parsed != null) {
                // For delete events, the document state before deletion is in 'value'
                snapshot = parsed['value'];
              }
            }
          } catch (_) {
            // Protobuf parsing failed - snapshot remains null
          }

          try {
            final event = FirestoreEvent<EmulatorDocumentSnapshot?>(
              data: snapshot,
              id: ceId,
              source: ceSource,
              specversion: '1.0',
              subject: ceSubject,
              time: DateTime.parse(ceTime),
              type: ceType!,
              location: 'us-central1',
              project: _extractProject(ceSource),
              database: database,
              namespace: namespace,
              document: documentPath,
              params: params,
            );

            await handler(event);
          } catch (e) {
            return Response(500, body: 'Handler error: $e');
          }

          return Response.ok('');
        } else {
          return Response(
            501,
            body:
                'Structured CloudEvent mode not yet supported for onDocumentDeleted',
          );
        }
      } catch (e, stackTrace) {
        return Response(
          500,
          body: 'Error processing Firestore event: $e\n$stackTrace',
        );
      }
    }, documentPattern: document);
  }

  /// Event handler that triggers on any write to a document (create, update, or delete).
  ///
  /// The handler receives a [FirestoreEvent] containing a [Change] object.
  /// Use `before.exists` and `after.exists` to determine the operation type.
  ///
  /// Example:
  /// ```dart
  /// firebase.firestore.onDocumentWritten(
  ///   document: 'users/{userId}',
  ///   (event) async {
  ///     final before = event.data?.before;
  ///     final after = event.data?.after;
  ///
  ///     if (before == null || !before.exists) {
  ///       print('Document created');
  ///     } else if (after == null || !after.exists) {
  ///       print('Document deleted');
  ///     } else {
  ///       print('Document updated');
  ///     }
  ///   },
  /// );
  /// ```
  void onDocumentWritten(
    Future<void> Function(
      FirestoreEvent<Change<EmulatorDocumentSnapshot>?> event,
    )
    handler, {

    /// The Firestore document path to trigger on.
    /// Supports wildcards: 'users/{userId}', 'users/{userId}/posts/{postId}'
    // ignore: experimental_member_use
    @mustBeConst required String document,

    /// Options that can be set on an individual event-handling function.
    // ignore: experimental_member_use
    @mustBeConst DocumentOptions? options,
  }) {
    final functionName = _documentToFunctionName('onDocumentWritten', document);

    firebase.registerFunction(functionName, (request) async {
      try {
        final isBinaryMode = request.headers.containsKey('ce-type');

        if (isBinaryMode) {
          final ceType = request.headers['ce-type'];

          if (ceType != null && !_isFirestoreWrittenEvent(ceType)) {
            return Response(
              400,
              body:
                  'Invalid event type for Firestore onDocumentWritten: $ceType',
            );
          }

          final ceId = request.headers['ce-id'];
          final ceSource = request.headers['ce-source'];
          final ceTime = request.headers['ce-time'];
          final ceSubject = request.headers['ce-subject'];
          final documentPath = request.headers['ce-document'];
          final database = request.headers['ce-database'] ?? '(default)';
          final namespace = request.headers['ce-namespace'] ?? '(default)';

          if (ceId == null ||
              ceSource == null ||
              ceTime == null ||
              documentPath == null) {
            return Response(400, body: 'Missing required CloudEvent headers');
          }

          final params = _extractParams(document, documentPath);

          // Parse protobuf body to get before/after snapshots
          EmulatorDocumentSnapshot? beforeSnapshot;
          EmulatorDocumentSnapshot? afterSnapshot;
          try {
            final bodyBytes = await request.read().fold<List<int>>(
              [],
              (previous, element) => previous..addAll(element),
            );

            if (bodyBytes.isNotEmpty) {
              final parsed = parseDocumentEventData(
                Uint8List.fromList(bodyBytes),
              );

              if (parsed != null) {
                beforeSnapshot = parsed['old_value'];
                afterSnapshot = parsed['value'];
              }
            }
          } catch (_) {
            // Protobuf parsing failed - snapshots remain null
          }

          try {
            final change = Change<EmulatorDocumentSnapshot>(
              before: beforeSnapshot,
              after: afterSnapshot,
            );

            final event = FirestoreEvent<Change<EmulatorDocumentSnapshot>?>(
              data: change,
              id: ceId,
              source: ceSource,
              specversion: '1.0',
              subject: ceSubject,
              time: DateTime.parse(ceTime),
              type: ceType!,
              location: 'us-central1',
              project: _extractProject(ceSource),
              database: database,
              namespace: namespace,
              document: documentPath,
              params: params,
            );

            await handler(event);
          } catch (e) {
            return Response(500, body: 'Handler error: $e');
          }

          return Response.ok('');
        } else {
          return Response(
            501,
            body:
                'Structured CloudEvent mode not yet supported for onDocumentWritten',
          );
        }
      } catch (e, stackTrace) {
        return Response(
          500,
          body: 'Error processing Firestore event: $e\n$stackTrace',
        );
      }
    }, documentPattern: document);
  }

  /// Event handler that triggers when a document is created in Firestore,
  /// with authentication context.
  ///
  /// Similar to [onDocumentCreated], but the handler receives a
  /// [FirestoreAuthEvent] that includes [AuthType] and an optional auth ID
  /// identifying the principal that triggered the write.
  ///
  /// Example:
  /// ```dart
  /// firebase.firestore.onDocumentCreatedWithAuthContext(
  ///   document: 'users/{userId}',
  ///   (event) async {
  ///     print('Auth type: ${event.authType}');
  ///     print('Auth ID: ${event.authId}');
  ///     final data = event.data?.data();
  ///     print('Document created: ${event.document}');
  ///   },
  /// );
  /// ```
  void onDocumentCreatedWithAuthContext(
    Future<void> Function(FirestoreAuthEvent<EmulatorDocumentSnapshot?> event)
    handler, {
    // ignore: experimental_member_use
    @mustBeConst required String document,
    // ignore: experimental_member_use
    @mustBeConst DocumentOptions? options,
  }) {
    final functionName = _documentToFunctionName(
      'onDocumentCreatedWithAuthContext',
      document,
    );

    firebase.registerFunction(functionName, (request) async {
      try {
        final isBinaryMode = request.headers.containsKey('ce-type');

        if (isBinaryMode) {
          final ceType = request.headers['ce-type'];

          if (ceType != null && !_isFirestoreCreatedEvent(ceType)) {
            return Response(
              400,
              body:
                  'Invalid event type for Firestore onDocumentCreatedWithAuthContext: $ceType',
            );
          }

          final ceId = request.headers['ce-id'];
          final ceSource = request.headers['ce-source'];
          final ceTime = request.headers['ce-time'];
          final ceSubject = request.headers['ce-subject'];
          final documentPath = request.headers['ce-document'];
          final database = request.headers['ce-database'] ?? '(default)';
          final namespace = request.headers['ce-namespace'] ?? '(default)';
          final authType = request.headers['ce-authtype'];
          final authId = request.headers['ce-authid'];

          if (ceId == null ||
              ceSource == null ||
              ceTime == null ||
              documentPath == null) {
            return Response(400, body: 'Missing required CloudEvent headers');
          }

          final params = _extractParams(document, documentPath);

          EmulatorDocumentSnapshot? snapshot;
          try {
            final bodyBytes = await request.read().fold<List<int>>(
              [],
              (previous, element) => previous..addAll(element),
            );

            if (bodyBytes.isNotEmpty) {
              final parsed = parseDocumentEventData(
                Uint8List.fromList(bodyBytes),
              );

              if (parsed != null) {
                snapshot = parsed['value'];
              }
            }
          } catch (_) {}

          try {
            final event = FirestoreAuthEvent<EmulatorDocumentSnapshot?>(
              data: snapshot,
              id: ceId,
              source: ceSource,
              specversion: '1.0',
              subject: ceSubject,
              time: DateTime.parse(ceTime),
              type: ceType!,
              location: 'us-central1',
              project: _extractProject(ceSource),
              database: database,
              namespace: namespace,
              document: documentPath,
              params: params,
              authType: AuthType.fromString(authType ?? 'unknown'),
              authId: authId,
            );

            await handler(event);
          } catch (e) {
            return Response(500, body: 'Handler error: $e');
          }

          return Response.ok('');
        } else {
          final json = await parseAndValidateCloudEvent(request);

          if (!_isFirestoreCreatedEvent(json['type'] as String)) {
            return Response(
              400,
              body:
                  'Invalid event type for Firestore onDocumentCreatedWithAuthContext: ${json['type']}',
            );
          }

          final event = FirestoreAuthEvent<EmulatorDocumentSnapshot?>(
            data: null,
            id: json['id'] as String,
            source: json['source'] as String,
            specversion: json['specversion'] as String,
            subject: json['subject'] as String?,
            time: DateTime.parse(json['time'] as String),
            type: json['type'] as String,
            location: json['location'] as String? ?? 'us-central1',
            project: 'unknown',
            database: '(default)',
            namespace: '(default)',
            document: '',
            params: {},
            authType: AuthType.fromString(
              json['authtype'] as String? ?? 'unknown',
            ),
            authId: json['authid'] as String?,
          );

          await handler(event);
          return Response.ok('');
        }
      } on FormatException catch (e) {
        return Response(400, body: 'Invalid CloudEvent: ${e.message}');
      } catch (e, stackTrace) {
        return Response(
          500,
          body: 'Error processing Firestore event: $e\n$stackTrace',
        );
      }
    }, documentPattern: document);
  }

  /// Event handler that triggers when a document is updated in Firestore,
  /// with authentication context.
  ///
  /// Similar to [onDocumentUpdated], but the handler receives a
  /// [FirestoreAuthEvent] that includes [AuthType] and an optional auth ID.
  ///
  /// Example:
  /// ```dart
  /// firebase.firestore.onDocumentUpdatedWithAuthContext(
  ///   document: 'users/{userId}',
  ///   (event) async {
  ///     print('Auth type: ${event.authType}');
  ///     final before = event.data?.before.data();
  ///     final after = event.data?.after.data();
  ///   },
  /// );
  /// ```
  void onDocumentUpdatedWithAuthContext(
    Future<void> Function(
      FirestoreAuthEvent<Change<EmulatorDocumentSnapshot>?> event,
    )
    handler, {
    // ignore: experimental_member_use
    @mustBeConst required String document,
    // ignore: experimental_member_use
    @mustBeConst DocumentOptions? options,
  }) {
    final functionName = _documentToFunctionName(
      'onDocumentUpdatedWithAuthContext',
      document,
    );

    firebase.registerFunction(functionName, (request) async {
      try {
        final isBinaryMode = request.headers.containsKey('ce-type');

        if (isBinaryMode) {
          final ceType = request.headers['ce-type'];

          if (ceType != null && !_isFirestoreUpdatedEvent(ceType)) {
            return Response(
              400,
              body:
                  'Invalid event type for Firestore onDocumentUpdatedWithAuthContext: $ceType',
            );
          }

          final ceId = request.headers['ce-id'];
          final ceSource = request.headers['ce-source'];
          final ceTime = request.headers['ce-time'];
          final ceSubject = request.headers['ce-subject'];
          final documentPath = request.headers['ce-document'];
          final database = request.headers['ce-database'] ?? '(default)';
          final namespace = request.headers['ce-namespace'] ?? '(default)';
          final authType = request.headers['ce-authtype'];
          final authId = request.headers['ce-authid'];

          if (ceId == null ||
              ceSource == null ||
              ceTime == null ||
              documentPath == null) {
            return Response(400, body: 'Missing required CloudEvent headers');
          }

          final params = _extractParams(document, documentPath);

          EmulatorDocumentSnapshot? beforeSnapshot;
          EmulatorDocumentSnapshot? afterSnapshot;
          try {
            final bodyBytes = await request.read().fold<List<int>>(
              [],
              (previous, element) => previous..addAll(element),
            );

            if (bodyBytes.isNotEmpty) {
              final parsed = parseDocumentEventData(
                Uint8List.fromList(bodyBytes),
              );

              if (parsed != null) {
                beforeSnapshot = parsed['old_value'];
                afterSnapshot = parsed['value'];
              }
            }
          } catch (_) {}

          try {
            final change = Change<EmulatorDocumentSnapshot>(
              before: beforeSnapshot,
              after: afterSnapshot,
            );

            final event = FirestoreAuthEvent<Change<EmulatorDocumentSnapshot>?>(
              data: change,
              id: ceId,
              source: ceSource,
              specversion: '1.0',
              subject: ceSubject,
              time: DateTime.parse(ceTime),
              type: ceType!,
              location: 'us-central1',
              project: _extractProject(ceSource),
              database: database,
              namespace: namespace,
              document: documentPath,
              params: params,
              authType: AuthType.fromString(authType ?? 'unknown'),
              authId: authId,
            );

            await handler(event);
          } catch (e) {
            return Response(500, body: 'Handler error: $e');
          }

          return Response.ok('');
        } else {
          return Response(
            501,
            body:
                'Structured CloudEvent mode not yet supported for onDocumentUpdatedWithAuthContext',
          );
        }
      } catch (e, stackTrace) {
        return Response(
          500,
          body: 'Error processing Firestore event: $e\n$stackTrace',
        );
      }
    }, documentPattern: document);
  }

  /// Event handler that triggers when a document is deleted in Firestore,
  /// with authentication context.
  ///
  /// Similar to [onDocumentDeleted], but the handler receives a
  /// [FirestoreAuthEvent] that includes [AuthType] and an optional auth ID.
  ///
  /// Example:
  /// ```dart
  /// firebase.firestore.onDocumentDeletedWithAuthContext(
  ///   document: 'users/{userId}',
  ///   (event) async {
  ///     print('Auth type: ${event.authType}');
  ///     print('Deleted by: ${event.authId}');
  ///   },
  /// );
  /// ```
  void onDocumentDeletedWithAuthContext(
    Future<void> Function(FirestoreAuthEvent<EmulatorDocumentSnapshot?> event)
    handler, {
    // ignore: experimental_member_use
    @mustBeConst required String document,
    // ignore: experimental_member_use
    @mustBeConst DocumentOptions? options,
  }) {
    final functionName = _documentToFunctionName(
      'onDocumentDeletedWithAuthContext',
      document,
    );

    firebase.registerFunction(functionName, (request) async {
      try {
        final isBinaryMode = request.headers.containsKey('ce-type');

        if (isBinaryMode) {
          final ceType = request.headers['ce-type'];

          if (ceType != null && !_isFirestoreDeletedEvent(ceType)) {
            return Response(
              400,
              body:
                  'Invalid event type for Firestore onDocumentDeletedWithAuthContext: $ceType',
            );
          }

          final ceId = request.headers['ce-id'];
          final ceSource = request.headers['ce-source'];
          final ceTime = request.headers['ce-time'];
          final ceSubject = request.headers['ce-subject'];
          final documentPath = request.headers['ce-document'];
          final database = request.headers['ce-database'] ?? '(default)';
          final namespace = request.headers['ce-namespace'] ?? '(default)';
          final authType = request.headers['ce-authtype'];
          final authId = request.headers['ce-authid'];

          if (ceId == null ||
              ceSource == null ||
              ceTime == null ||
              documentPath == null) {
            return Response(400, body: 'Missing required CloudEvent headers');
          }

          final params = _extractParams(document, documentPath);

          EmulatorDocumentSnapshot? snapshot;
          try {
            final bodyBytes = await request.read().fold<List<int>>(
              [],
              (previous, element) => previous..addAll(element),
            );

            if (bodyBytes.isNotEmpty) {
              final parsed = parseDocumentEventData(
                Uint8List.fromList(bodyBytes),
              );

              if (parsed != null) {
                snapshot = parsed['value'];
              }
            }
          } catch (_) {}

          try {
            final event = FirestoreAuthEvent<EmulatorDocumentSnapshot?>(
              data: snapshot,
              id: ceId,
              source: ceSource,
              specversion: '1.0',
              subject: ceSubject,
              time: DateTime.parse(ceTime),
              type: ceType!,
              location: 'us-central1',
              project: _extractProject(ceSource),
              database: database,
              namespace: namespace,
              document: documentPath,
              params: params,
              authType: AuthType.fromString(authType ?? 'unknown'),
              authId: authId,
            );

            await handler(event);
          } catch (e) {
            return Response(500, body: 'Handler error: $e');
          }

          return Response.ok('');
        } else {
          return Response(
            501,
            body:
                'Structured CloudEvent mode not yet supported for onDocumentDeletedWithAuthContext',
          );
        }
      } catch (e, stackTrace) {
        return Response(
          500,
          body: 'Error processing Firestore event: $e\n$stackTrace',
        );
      }
    }, documentPattern: document);
  }

  /// Event handler that triggers on any write to a document (create, update,
  /// or delete), with authentication context.
  ///
  /// Similar to [onDocumentWritten], but the handler receives a
  /// [FirestoreAuthEvent] that includes [AuthType] and an optional auth ID.
  ///
  /// Example:
  /// ```dart
  /// firebase.firestore.onDocumentWrittenWithAuthContext(
  ///   document: 'users/{userId}',
  ///   (event) async {
  ///     print('Auth type: ${event.authType}');
  ///     print('Auth ID: ${event.authId}');
  ///     final before = event.data?.before;
  ///     final after = event.data?.after;
  ///   },
  /// );
  /// ```
  void onDocumentWrittenWithAuthContext(
    Future<void> Function(
      FirestoreAuthEvent<Change<EmulatorDocumentSnapshot>?> event,
    )
    handler, {
    // ignore: experimental_member_use
    @mustBeConst required String document,
    // ignore: experimental_member_use
    @mustBeConst DocumentOptions? options,
  }) {
    final functionName = _documentToFunctionName(
      'onDocumentWrittenWithAuthContext',
      document,
    );

    firebase.registerFunction(functionName, (request) async {
      try {
        final isBinaryMode = request.headers.containsKey('ce-type');

        if (isBinaryMode) {
          final ceType = request.headers['ce-type'];

          if (ceType != null && !_isFirestoreWrittenEvent(ceType)) {
            return Response(
              400,
              body:
                  'Invalid event type for Firestore onDocumentWrittenWithAuthContext: $ceType',
            );
          }

          final ceId = request.headers['ce-id'];
          final ceSource = request.headers['ce-source'];
          final ceTime = request.headers['ce-time'];
          final ceSubject = request.headers['ce-subject'];
          final documentPath = request.headers['ce-document'];
          final database = request.headers['ce-database'] ?? '(default)';
          final namespace = request.headers['ce-namespace'] ?? '(default)';
          final authType = request.headers['ce-authtype'];
          final authId = request.headers['ce-authid'];

          if (ceId == null ||
              ceSource == null ||
              ceTime == null ||
              documentPath == null) {
            return Response(400, body: 'Missing required CloudEvent headers');
          }

          final params = _extractParams(document, documentPath);

          EmulatorDocumentSnapshot? beforeSnapshot;
          EmulatorDocumentSnapshot? afterSnapshot;
          try {
            final bodyBytes = await request.read().fold<List<int>>(
              [],
              (previous, element) => previous..addAll(element),
            );

            if (bodyBytes.isNotEmpty) {
              final parsed = parseDocumentEventData(
                Uint8List.fromList(bodyBytes),
              );

              if (parsed != null) {
                beforeSnapshot = parsed['old_value'];
                afterSnapshot = parsed['value'];
              }
            }
          } catch (_) {}

          try {
            final change = Change<EmulatorDocumentSnapshot>(
              before: beforeSnapshot,
              after: afterSnapshot,
            );

            final event = FirestoreAuthEvent<Change<EmulatorDocumentSnapshot>?>(
              data: change,
              id: ceId,
              source: ceSource,
              specversion: '1.0',
              subject: ceSubject,
              time: DateTime.parse(ceTime),
              type: ceType!,
              location: 'us-central1',
              project: _extractProject(ceSource),
              database: database,
              namespace: namespace,
              document: documentPath,
              params: params,
              authType: AuthType.fromString(authType ?? 'unknown'),
              authId: authId,
            );

            await handler(event);
          } catch (e) {
            return Response(500, body: 'Handler error: $e');
          }

          return Response.ok('');
        } else {
          return Response(
            501,
            body:
                'Structured CloudEvent mode not yet supported for onDocumentWrittenWithAuthContext',
          );
        }
      } catch (e, stackTrace) {
        return Response(
          500,
          body: 'Error processing Firestore event: $e\n$stackTrace',
        );
      }
    }, documentPattern: document);
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
  /// Accepts both the base type and the `.withAuthContext` variant.
  bool _isFirestoreCreatedEvent(String type) =>
      type == 'google.cloud.firestore.document.v1.created' ||
      type == 'google.cloud.firestore.document.v1.created.withAuthContext';

  /// Checks if the CloudEvent type is a Firestore document updated event.
  /// Accepts both the base type and the `.withAuthContext` variant.
  bool _isFirestoreUpdatedEvent(String type) =>
      type == 'google.cloud.firestore.document.v1.updated' ||
      type == 'google.cloud.firestore.document.v1.updated.withAuthContext';

  /// Checks if the CloudEvent type is a Firestore document deleted event.
  /// Accepts both the base type and the `.withAuthContext` variant.
  bool _isFirestoreDeletedEvent(String type) =>
      type == 'google.cloud.firestore.document.v1.deleted' ||
      type == 'google.cloud.firestore.document.v1.deleted.withAuthContext';

  /// Checks if the CloudEvent type is a Firestore document written event.
  /// Accepts both the base type and the `.withAuthContext` variant.
  bool _isFirestoreWrittenEvent(String type) =>
      type == 'google.cloud.firestore.document.v1.written' ||
      type == 'google.cloud.firestore.document.v1.written.withAuthContext';

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
  /// Note: Source may have nested paths like projects/projects/demo-test
  String _extractProject(String source) {
    final uri = Uri.parse(source.replaceFirst('//', 'https://'));
    final pathSegments = uri.pathSegments;

    // Find LAST 'projects' segment and return the next one
    // This handles cases like: projects/projects/demo-test
    var projectIndex = -1;
    for (var i = pathSegments.length - 1; i >= 0; i--) {
      if (pathSegments[i] == 'projects' && i + 1 < pathSegments.length) {
        projectIndex = i;
        break;
      }
    }

    if (projectIndex != -1) {
      return pathSegments[projectIndex + 1];
    }

    return 'unknown-project';
  }
}
