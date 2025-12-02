import 'dart:convert';

import 'package:http/http.dart' as http;

/// Helper client for interacting with Firestore emulator REST API.
class FirestoreClient {
  FirestoreClient(this.baseUrl);

  final String baseUrl;
  final http.Client _client = http.Client();

  /// Creates a document with the specified ID.
  Future<Map<String, dynamic>> createDocument(
    String collectionPath,
    String documentId,
    Map<String, dynamic> fields,
  ) async {
    final url = '$baseUrl/$collectionPath?documentId=$documentId';
    final response = await _client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fields': fields}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to create document: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Updates a document using PATCH.
  Future<Map<String, dynamic>> updateDocument(
    String documentPath,
    Map<String, dynamic> fields,
  ) async {
    final url = '$baseUrl/$documentPath';
    final response = await _client.patch(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fields': fields}),
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
  static Map<String, dynamic> stringValue(String value) =>
      {'stringValue': value};

  /// Helper to create an integer field value.
  static Map<String, dynamic> intValue(int value) =>
      {'integerValue': value.toString()};

  /// Helper to create a double field value.
  static Map<String, dynamic> doubleValue(double value) =>
      {'doubleValue': value};

  /// Helper to create a boolean field value.
  static Map<String, dynamic> boolValue({required bool value}) =>
      {'booleanValue': value};

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

  /// Closes the HTTP client.
  void close() {
    _client.close();
  }
}
