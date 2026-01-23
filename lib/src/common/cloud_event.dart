/// Represents a CloudEvents v1.0 event.
///
/// CloudEvents is a specification for describing event data in a common way.
/// Firebase Functions uses CloudEvents for all event-driven triggers.
///
/// See: https://cloudevents.io/
class CloudEvent<T extends Object?> {
  const CloudEvent({
    this.data,
    required this.id,
    required this.source,
    required this.specversion,
    this.subject,
    required this.time,
    required this.type,
  });

  /// Parses a CloudEvent from JSON.
  ///
  /// The [dataDecoder] function is used to convert the JSON data field
  /// into the appropriate type T.
  factory CloudEvent.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) dataDecoder,
  ) =>
      CloudEvent<T>(
        data: dataDecoder(json['data'] as Map<String, dynamic>),
        id: json['id'] as String,
        source: json['source'] as String,
        specversion: json['specversion'] as String,
        subject: json['subject'] as String?,
        time: DateTime.parse(json['time'] as String),
        type: json['type'] as String,
      );

  /// The event data. Type depends on the event source.
  /// May be null in emulator mode when protobuf parsing is not available.
  final T? data;

  /// Unique identifier for this event.
  final String id;

  /// Identifies the context in which an event happened.
  final String source;

  /// The version of the CloudEvents specification (should be '1.0').
  final String specversion;

  /// Subject of the event in the context of the event producer.
  final String? subject;

  /// Timestamp of when the occurrence happened.
  final DateTime time;

  /// Type of event (e.g., 'google.cloud.pubsub.topic.v1.messagePublished').
  final String type;

  /// Converts this CloudEvent to JSON.
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) dataEncoder) =>
      <String, dynamic>{
        'specversion': specversion,
        'id': id,
        'source': source,
        'type': type,
        'time': time.toIso8601String(),
        if (subject != null) 'subject': subject,
        if (data != null) 'data': dataEncoder(data as T),
      };
}

/// Parses a raw CloudEvent JSON string into a Map.
Map<String, dynamic> parseCloudEventJson(Object? decoded) {
  try {
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'CloudEvent body must be a JSON object',
      );
    }
    return decoded;
  } on FormatException catch (e) {
    throw FormatException('Invalid CloudEvent JSON: ${e.message}');
  }
}

/// Validates that a JSON object has the required CloudEvent fields.
void validateCloudEvent(Map<String, dynamic> json) {
  const requiredFields = ['specversion', 'id', 'source', 'type', 'time'];

  for (final field in requiredFields) {
    if (!json.containsKey(field)) {
      throw FormatException('CloudEvent missing required field: $field');
    }
  }

  if (json['specversion'] != '1.0') {
    throw FormatException(
      'Unsupported CloudEvent version: ${json['specversion']}',
    );
  }
}
