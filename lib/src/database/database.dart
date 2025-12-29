/// Firebase Realtime Database triggers for Cloud Functions.
///
/// Provides event-driven triggers for Realtime Database operations:
/// - [DatabaseNamespace.onValueCreated] - Triggers when data is created
/// - [DatabaseNamespace.onValueUpdated] - Triggers when data is updated
/// - [DatabaseNamespace.onValueDeleted] - Triggers when data is deleted
/// - [DatabaseNamespace.onValueWritten] - Triggers on any write operation
///
/// Example:
/// ```dart
/// firebase.database.onValueWritten(
///   ref: 'users/{userId}',
///   (event) async {
///     final before = event.data?.before?.val();
///     final after = event.data?.after?.val();
///     print('User ${event.params['userId']} changed');
///   },
/// );
/// ```
library database;

export 'data_snapshot.dart'
    show Change, DataSnapshot, IntPriority, Priority, StringPriority;
export 'database_namespace.dart' show DatabaseNamespace;
export 'event.dart' show DatabaseEvent;
export 'options.dart' show ReferenceOptions;
