import 'package:google_cloud_firestore/google_cloud_firestore.dart'
    show DocumentData;

export '../common/change.dart';

/// Parses Firestore REST API field format into Dart values.
///
/// Firestore REST API uses typed wrappers like:
/// - {stringValue: "text"} → "text"
/// - {integerValue: "123"} → 123
/// - {booleanValue: true} → true
/// - {mapValue: {fields: {...}}} → Map
/// - {arrayValue: {values: [...]}} → List
dynamic parseFirestoreValue(Map<String, dynamic> field) {
  if (field.containsKey('stringValue')) {
    return field['stringValue'] as String;
  }
  if (field.containsKey('integerValue')) {
    final value = field['integerValue'];
    return value is String ? int.parse(value) : value as int;
  }
  if (field.containsKey('doubleValue')) {
    final value = field['doubleValue'];
    return value is String ? double.parse(value) : value as double;
  }
  if (field.containsKey('booleanValue')) {
    return field['booleanValue'] as bool;
  }
  if (field.containsKey('timestampValue')) {
    return DateTime.parse(field['timestampValue'] as String);
  }
  if (field.containsKey('nullValue')) {
    return null;
  }
  if (field.containsKey('mapValue')) {
    final mapValue = field['mapValue'] as Map<String, dynamic>;
    final fields = mapValue['fields'] as Map<String, dynamic>? ?? {};
    return parseFirestoreFields(fields);
  }
  if (field.containsKey('arrayValue')) {
    final arrayValue = field['arrayValue'] as Map<String, dynamic>;
    final values = arrayValue['values'] as List? ?? [];
    return values
        .map((v) => parseFirestoreValue(v as Map<String, dynamic>))
        .toList();
  }
  // Unsupported type - return as-is
  return field;
}

/// Parses Firestore REST API fields map into a plain Dart Map.
///
/// Input: {name: {stringValue: "John"}, age: {integerValue: "25"}}
/// Output: {name: "John", age: 25}
Map<String, dynamic> parseFirestoreFields(Map<String, dynamic> fields) {
  final result = <String, dynamic>{};
  for (final entry in fields.entries) {
    result[entry.key] = parseFirestoreValue(
      entry.value as Map<String, dynamic>,
    );
  }
  return result;
}

/// A lightweight document snapshot for emulator mode.
///
/// This provides a similar interface to dart_firebase_admin's QueryDocumentSnapshot
/// but works with data fetched from the Firestore emulator REST API.
class EmulatorDocumentSnapshot {
  EmulatorDocumentSnapshot({
    required this.id,
    required this.path,
    required this.fields,
    required this.createTime,
    required this.updateTime,
  });

  /// Creates a snapshot from Firestore REST API response.
  ///
  /// Example response:
  /// {
  ///   "name": "projects/demo/databases/(default)/documents/users/abc123",
  ///   "fields": {"name": {"stringValue": "John"}},
  ///   "createTime": "2025-12-01T12:00:00Z",
  ///   "updateTime": "2025-12-01T12:00:00Z"
  /// }
  factory EmulatorDocumentSnapshot.fromRestApi(Map<String, dynamic> response) {
    final name = response['name'] as String;
    final fields = response['fields'] as Map<String, dynamic>? ?? {};
    final createTime = response['createTime'] as String?;
    final updateTime = response['updateTime'] as String?;

    // Extract document ID and path from name
    // name format: "projects/{project}/databases/{db}/documents/{path}"
    final nameParts = name.split('/documents/');
    final fullPath = nameParts.length > 1 ? nameParts[1] : '';
    final pathParts = fullPath.split('/');
    final documentId = pathParts.isNotEmpty ? pathParts.last : '';

    return EmulatorDocumentSnapshot(
      id: documentId,
      path: fullPath,
      fields: parseFirestoreFields(fields),
      createTime: createTime != null ? DateTime.parse(createTime) : null,
      updateTime: updateTime != null ? DateTime.parse(updateTime) : null,
    );
  }

  /// The document ID.
  final String id;

  /// The full document path (e.g., "users/abc123").
  final String path;

  /// The document fields as a plain Dart Map.
  final DocumentData fields;

  /// When the document was created.
  final DateTime? createTime;

  /// When the document was last updated.
  final DateTime? updateTime;

  /// Returns the document data.
  ///
  /// This matches the Node.js `snapshot.data()` API.
  DocumentData data() => fields;

  /// Gets a specific field value.
  dynamic get(String fieldPath) => fields[fieldPath];

  /// Whether the document exists.
  bool get exists => true;

  /// Gets a specific field value.
  ///
  /// This is a convenience method that matches Node.js API.
  /// Equivalent to calling `data()[fieldPath]`.
  dynamic operator [](String fieldPath) => fields[fieldPath];

  @override
  String toString() => 'EmulatorDocumentSnapshot($path)';
}
