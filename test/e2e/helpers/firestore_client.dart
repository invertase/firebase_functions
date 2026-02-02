import 'dart:convert';

import 'package:http/http.dart' as http;

/// Helper client for interacting with Firestore emulator REST API.
class FirestoreClient {
  FirestoreClient(this.baseUrl);

  final String baseUrl;
  final http.Client _client = http.Client();

  /// Creates a document with the specified ID.
  ///
  /// Accepts a plain Dart map and automatically converts it to Firestore format.
  ///
  /// Example:
  /// ```dart
  /// await client.createDocument('users', 'user123', {
  ///   'name': 'John Doe',
  ///   'age': 28,
  ///   'tags': ['admin', 'premium'],
  /// });
  /// ```
  Future<Map<String, dynamic>> createDocument(
    String collectionPath,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final url = '$baseUrl/$collectionPath?documentId=$documentId';
    final response = await _client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fields': fields(data)}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to create document: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Updates a document using PATCH.
  ///
  /// Accepts a plain Dart map and automatically converts it to Firestore format.
  ///
  /// Example:
  /// ```dart
  /// await client.updateDocument('users/user123', {
  ///   'name': 'Jane Smith',
  ///   'age': 29,
  /// });
  /// ```
  Future<Map<String, dynamic>> updateDocument(
    String documentPath,
    Map<String, dynamic> data,
  ) async {
    final url = '$baseUrl/$documentPath';
    final response = await _client.patch(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fields': fields(data)}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update document: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Deletes a document.
  Future<void> deleteDocument(String documentPath) async {
    final url = '$baseUrl/$documentPath';
    final response = await _client.delete(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete document: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Gets a document.
  Future<Map<String, dynamic>?> getDocument(String documentPath) async {
    final url = '$baseUrl/$documentPath';
    final response = await _client.get(Uri.parse(url));

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get document: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Helper to create a string field value.
  static Map<String, dynamic> stringValue(String value) => {
    'stringValue': value,
  };

  /// Helper to create an integer field value.
  static Map<String, dynamic> intValue(int value) => {
    'integerValue': value.toString(),
  };

  /// Helper to create a double field value.
  static Map<String, dynamic> doubleValue(double value) => {
    'doubleValue': value,
  };

  /// Helper to create a boolean field value.
  static Map<String, dynamic> boolValue({required bool value}) => {
    'booleanValue': value,
  };

  /// Helper to create a null field value.
  static Map<String, dynamic> nullValue() => {'nullValue': null};

  /// Helper to create a map field value.
  static Map<String, dynamic> mapValue(Map<String, dynamic> fields) => {
    'mapValue': {'fields': fields},
  };

  /// Helper to create an array field value.
  static Map<String, dynamic> arrayValue(List<Map<String, dynamic>> values) => {
    'arrayValue': {'values': values},
  };

  /// Automatically converts a Dart value to Firestore field format.
  ///
  /// Supports:
  /// - String, int, double, bool, null
  /// - Lists (converted to arrayValue)
  /// - Maps (converted to mapValue with nested fields)
  ///
  /// Example:
  /// ```dart
  /// value('hello')  // {'stringValue': 'hello'}
  /// value(42)       // {'integerValue': '42'}
  /// value([1, 2])   // {'arrayValue': {'values': [...]}}
  /// value({'key': 'value'})  // {'mapValue': {'fields': {...}}}
  /// ```
  static Map<String, dynamic> value(dynamic val) {
    if (val is String) return stringValue(val);
    if (val is int) return intValue(val);
    if (val is double) return doubleValue(val);
    if (val is bool) return boolValue(value: val);
    if (val == null) return nullValue();

    if (val is List) {
      return arrayValue(val.map((e) => value(e)).toList());
    }

    if (val is Map) {
      final firestoreFields = <String, dynamic>{};
      for (final entry in val.entries) {
        firestoreFields[entry.key.toString()] = value(entry.value);
      }
      return mapValue(firestoreFields);
    }

    throw ArgumentError('Unsupported type: ${val.runtimeType}');
  }

  /// Converts a map of Dart values to Firestore fields format.
  ///
  /// This is a convenience method for converting an entire document's fields.
  ///
  /// Example:
  /// ```dart
  /// fields({
  ///   'name': 'John Doe',
  ///   'age': 28,
  ///   'active': true,
  ///   'tags': ['admin', 'premium'],
  /// })
  /// ```
  static Map<String, dynamic> fields(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      result[entry.key] = value(entry.value);
    }
    return result;
  }

  /// Closes the HTTP client.
  void close() {
    _client.close();
  }
}
