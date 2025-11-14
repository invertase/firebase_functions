import 'dart:convert';

/// A Pub/Sub message.
///
/// Matches the structure from the Node.js SDK and CloudEvents specification.
class PubsubMessage {
  /// The binary data in the message (base64-encoded in CloudEvents).
  final String data;

  /// Attributes for this message (key-value pairs).
  final Map<String, String> attributes;

  /// ID of the message (assigned by Pub/Sub).
  final String messageId;

  /// The time the message was published.
  final DateTime publishTime;

  /// Ordering key for this message (if applicable).
  final String? orderingKey;

  const PubsubMessage({
    required this.data,
    required this.attributes,
    required this.messageId,
    required this.publishTime,
    this.orderingKey,
  });

  /// Parses a PubsubMessage from JSON (CloudEvent data format).
  ///
  /// Expected format:
  /// ```json
  /// {
  ///   "message": {
  ///     "data": "base64-encoded-data",
  ///     "attributes": {"key": "value"},
  ///     "messageId": "123456",
  ///     "publishTime": "2024-01-01T12:00:00Z",
  ///     "orderingKey": "optional-key"
  ///   },
  ///   "subscription": "projects/my-project/subscriptions/my-sub"
  /// }
  /// ```
  factory PubsubMessage.fromJson(Map<String, dynamic> json) {
    final message = json['message'] as Map<String, dynamic>;

    return PubsubMessage(
      data: message['data'] as String,
      attributes: Map<String, String>.from(
        message['attributes'] as Map? ?? {},
      ),
      messageId: message['messageId'] as String,
      publishTime: DateTime.parse(message['publishTime'] as String),
      orderingKey: message['orderingKey'] as String?,
    );
  }

  /// Converts this message to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'message': <String, dynamic>{
          'data': data,
          'attributes': attributes,
          'messageId': messageId,
          'publishTime': publishTime.toIso8601String(),
          if (orderingKey != null) 'orderingKey': orderingKey,
        },
      };

  /// Decodes the base64-encoded data as a UTF-8 string.
  String get textData {
    try {
      return utf8.decode(base64.decode(data));
    } on FormatException {
      throw FormatException('Message data is not valid base64');
    }
  }

  /// Decodes the base64-encoded data as raw bytes.
  List<int> get binaryData {
    try {
      return base64.decode(data);
    } on FormatException {
      throw FormatException('Message data is not valid base64');
    }
  }

  /// Decodes the base64-encoded data as JSON.
  dynamic get jsonData {
    try {
      return jsonDecode(textData);
    } on FormatException {
      throw FormatException('Message data is not valid JSON');
    }
  }
}
