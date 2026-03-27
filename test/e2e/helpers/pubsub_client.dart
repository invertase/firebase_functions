// Copyright 2026 Firebase
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

/// Helper for publishing messages to the Pub/Sub emulator.
final class PubSubClient extends TestClientBase {
  PubSubClient(super.baseUrl, this.projectId);

  final String projectId;

  /// Publishes a message to a topic in the Pub/Sub emulator.
  ///
  /// The [data] will be automatically base64-encoded.
  /// Optional [attributes] can be provided as key-value pairs.
  Future<PubSubPublishResponse> publishMessage(
    String topic, {
    required String data,
    Map<String, String>? attributes,
  }) async {
    final base64Data = base64Encode(utf8.encode(data));

    final message = <String, dynamic>{
      'data': base64Data,
      if (attributes != null && attributes.isNotEmpty) 'attributes': attributes,
    };

    return publishRawMessage(topic, message);
  }

  /// Publishes a raw message (data already base64-encoded) to a topic.
  ///
  /// Use this when you need full control over the message structure.
  Future<PubSubPublishResponse> publishRawMessage(
    String topic,
    Map<String, dynamic> message,
  ) async {
    final url = Uri.parse(
      '$baseUrl/v1/projects/$projectId/topics/$topic:publish',
    );

    final response = await client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'messages': [message],
      }),
    );

    if (response.statusCode != 200) {
      throw PubSubException(
        'Failed to publish message: ${response.statusCode} ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final messageIds = (body['messageIds'] as List<dynamic>)
        .map((e) => e as String)
        .toList();

    return PubSubPublishResponse(messageIds);
  }

  /// Publishes multiple messages to a topic in batch.
  Future<PubSubPublishResponse> publishMessages(
    String topic,
    List<PubSubMessage> messages,
  ) async {
    final url = Uri.parse(
      '$baseUrl/v1/projects/$projectId/topics/$topic:publish',
    );

    final encodedMessages = messages.map((msg) {
      return <String, dynamic>{
        'data': base64Encode(utf8.encode(msg.data)),
        if (msg.attributes.isNotEmpty) 'attributes': msg.attributes,
      };
    }).toList();

    final response = await client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'messages': encodedMessages}),
    );

    if (response.statusCode != 200) {
      throw PubSubException(
        'Failed to publish messages: ${response.statusCode} ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final messageIds = (body['messageIds'] as List<dynamic>)
        .map((e) => e as String)
        .toList();

    return PubSubPublishResponse(messageIds);
  }
}

/// A Pub/Sub message to be published.
class PubSubMessage {
  PubSubMessage(this.data, {this.attributes = const {}});

  final String data;
  final Map<String, String> attributes;
}

/// Response from publishing message(s).
class PubSubPublishResponse {
  PubSubPublishResponse(this.messageIds);

  final List<String> messageIds;

  /// Returns the first message ID (useful for single message publishes).
  String get messageId => messageIds.first;
}

/// Exception thrown when Pub/Sub operations fail.
class PubSubException implements Exception {
  PubSubException(this.message);

  final String message;

  @override
  String toString() => 'PubSubException: $message';
}
