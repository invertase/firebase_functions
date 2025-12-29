import 'dart:convert';

import 'package:http/http.dart' as http;

/// Helper client for interacting with Firebase Realtime Database emulator REST API.
class DatabaseClient {
  DatabaseClient(this.baseUrl, this.projectId);

  final String baseUrl;
  final String projectId;
  final http.Client _client = http.Client();

  /// Gets the full URL for a database path.
  String _getUrl(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$normalizedPath.json?ns=$projectId';
  }

  /// Creates or sets a value at the specified path.
  ///
  /// Example:
  /// ```dart
  /// await client.setValue('messages/msg123', {
  ///   'text': 'Hello World',
  ///   'timestamp': 1234567890,
  /// });
  /// ```
  Future<void> setValue(String path, dynamic data) async {
    final url = _getUrl(path);
    final response = await _client.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to set value at $path: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Updates a value at the specified path (merges with existing data).
  ///
  /// Example:
  /// ```dart
  /// await client.updateValue('messages/msg123', {
  ///   'text': 'Updated text',
  /// });
  /// ```
  Future<void> updateValue(String path, Map<String, dynamic> data) async {
    final url = _getUrl(path);
    final response = await _client.patch(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update value at $path: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Pushes a new value with an auto-generated key.
  ///
  /// Returns the generated key.
  ///
  /// Example:
  /// ```dart
  /// final key = await client.pushValue('messages', {
  ///   'text': 'New message',
  /// });
  /// print('Created message with key: $key');
  /// ```
  Future<String> pushValue(String path, dynamic data) async {
    final url = _getUrl(path);
    final response = await _client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to push value at $path: ${response.statusCode} ${response.body}',
      );
    }

    final result = jsonDecode(response.body) as Map<String, dynamic>;
    return result['name'] as String;
  }

  /// Gets a value at the specified path.
  ///
  /// Returns null if the path doesn't exist.
  Future<dynamic> getValue(String path) async {
    final url = _getUrl(path);
    final response = await _client.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get value at $path: ${response.statusCode} ${response.body}',
      );
    }

    final body = response.body;
    if (body == 'null') {
      return null;
    }

    return jsonDecode(body);
  }

  /// Deletes a value at the specified path.
  Future<void> deleteValue(String path) async {
    final url = _getUrl(path);
    final response = await _client.delete(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete value at $path: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Closes the HTTP client.
  void close() {
    _client.close();
  }
}
