import 'dart:convert';

import 'package:http/http.dart' as http;

/// Helper for publishing messages to the Pub/Sub emulator.
class PubSubClient {
  PubSubClient(this.baseUrl, this.projectId);

  final String baseUrl;
  final String projectId;
  final http.Client _client = http.Client();

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

    final response = await _client.post(
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
    final messageIds =
        (body['messageIds'] as List<dynamic>).map((e) => e as String).toList();

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

    final encodedMessages =
        messages.map((msg) {
          return <String, dynamic>{
            'data': base64Encode(utf8.encode(msg.data)),
            if (msg.attributes.isNotEmpty) 'attributes': msg.attributes,
          };
        }).toList();

    final response = await _client.post(
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
    final messageIds =
        (body['messageIds'] as List<dynamic>).map((e) => e as String).toList();

    return PubSubPublishResponse(messageIds);
  }

  /// Closes the HTTP client.
  void close() {
    _client.close();
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
