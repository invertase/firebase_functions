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
import 'dart:typed_data';

import 'test_client_base.dart';

/// Helper client for interacting with the Firebase Storage emulator.
final class StorageClient extends TestClientBase {
  StorageClient(super.baseUrl, this.bucket);

  final String bucket;

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

    final response = await client.post(
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

    final response = await client.delete(url);

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

    final response = await client.get(url);

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
}

/// Exception thrown when Storage operations fail.
class StorageException implements Exception {
  StorageException(this.message);

  final String message;

  @override
  String toString() => 'StorageException: $message';
}
