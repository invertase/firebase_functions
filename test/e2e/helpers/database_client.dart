// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:convert';

import 'test_client_base.dart';

/// Helper client for interacting with Firebase Realtime Database emulator REST API.
final class DatabaseClient extends TestClientBase {
  DatabaseClient(super.baseUrl, this.projectId);

  final String projectId;

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
    final response = await client.put(
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
    final response = await client.patch(
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
    final response = await client.post(
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
    final response = await client.get(Uri.parse(url));

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
    final response = await client.delete(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete value at $path: ${response.statusCode} ${response.body}',
      );
    }
  }
}
