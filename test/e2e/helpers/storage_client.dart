import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Helper client for interacting with the Firebase Storage emulator.
class StorageClient {
  StorageClient(this.baseUrl, this.bucket);

  final String baseUrl;
  final String bucket;
  final http.Client _client = http.Client();

  /// Uploads a file to the storage emulator.
  ///
  /// Returns the object metadata from the emulator response.
  Future<Map<String, dynamic>> uploadObject(
    String objectPath, {
    Uint8List? data,
    String contentType = 'application/octet-stream',
  }) async {
    final bytes = data ?? Uint8List.fromList(utf8.encode('test file content'));
    final url = Uri.parse(
      '$baseUrl/upload/storage/v1/b/$bucket/o'
      '?uploadType=media&name=${Uri.encodeComponent(objectPath)}',
    );

    final response = await _client.post(
      url,
      headers: {'Content-Type': contentType},
      body: bytes,
    );

    if (response.statusCode != 200) {
      throw StorageException(
        'Failed to upload object: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Deletes an object from the storage emulator.
  Future<void> deleteObject(String objectPath) async {
    final url = Uri.parse(
      '$baseUrl/storage/v1/b/$bucket/o/${Uri.encodeComponent(objectPath)}',
    );

    final response = await _client.delete(url);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw StorageException(
        'Failed to delete object: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Gets object metadata from the storage emulator.
  Future<Map<String, dynamic>?> getObjectMetadata(String objectPath) async {
    final url = Uri.parse(
      '$baseUrl/storage/v1/b/$bucket/o/${Uri.encodeComponent(objectPath)}',
    );

    final response = await _client.get(url);

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw StorageException(
        'Failed to get metadata: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Closes the HTTP client.
  void close() {
    _client.close();
  }
}

/// Exception thrown when Storage operations fail.
class StorageException implements Exception {
  StorageException(this.message);

  final String message;

  @override
  String toString() => 'StorageException: $message';
}
