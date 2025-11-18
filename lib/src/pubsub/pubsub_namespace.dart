import 'dart:async';

import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

import '../common/cloud_event.dart';
import '../firebase.dart';
import 'message.dart';
import 'options.dart';

/// Pub/Sub triggers namespace.
///
/// Provides methods to define Pub/Sub-triggered Cloud Functions.
class PubSubNamespace extends FunctionsNamespace {
  const PubSubNamespace(super.firebase);

  /// Creates a function triggered by Pub/Sub messages.
  ///
  /// The handler receives a [CloudEvent] containing the [PubsubMessage].
  ///
  /// Example:
  /// ```dart
  /// firebase.pubsub.onMessagePublished(
  ///   topic: 'my-topic',
  ///   (event) async {
  ///     final message = event.data;
  ///     print('Received: ${message.textData}');
  ///     print('Attributes: ${message.attributes}');
  ///   },
  /// );
  /// ```
  void onMessagePublished(
    Future<void> Function(CloudEvent<PubsubMessage> event) handler, {
    // ignore: experimental_member_use
    @mustBeConst required String topic,
    // ignore: experimental_member_use
    @mustBeConst PubSubOptions? options = const PubSubOptions(),
  }) {
    // Generate function name from topic
    final functionName = _topicToFunctionName(topic);

    firebase.registerFunction(
      functionName,
      (request) async {
        try {
          // Read and parse CloudEvent
          final bodyString = await request.readAsString();
          final json = parseCloudEventJson(bodyString);

          // Validate CloudEvent structure
          validateCloudEvent(json);

          // Verify it's a Pub/Sub event
          if (!_isPubSubEvent(json['type'] as String)) {
            return Response(
              400,
              body: 'Invalid event type for Pub/Sub: ${json['type']}',
            );
          }

          // Parse CloudEvent with PubsubMessage data
          final event = CloudEvent<PubsubMessage>.fromJson(
            json,
            (data) => PubsubMessage.fromJson(data),
          );

          // Execute handler
          await handler(event);

          // Return success
          return Response.ok('');
        } on FormatException catch (e) {
          return Response(
            400,
            body: 'Invalid CloudEvent: ${e.message}',
          );
        } catch (e) {
          return Response(
            500,
            body: 'Error processing Pub/Sub message: $e',
          );
        }
      },
    );
  }

  /// Converts a topic name to a function name.
  ///
  /// Examples:
  /// - 'my-topic' -> 'onMessagePublished_mytopic'
  /// - 'projects/my-project/topics/my-topic' -> 'onMessagePublished_mytopic'
  String _topicToFunctionName(String topic) {
    // Extract just the topic name (last segment)
    final segments = topic.split('/');
    final topicName = segments.last;

    // Remove hyphens to match Node.js behavior
    final sanitizedTopic = topicName.replaceAll('-', '');

    return 'onMessagePublished_$sanitizedTopic';
  }

  /// Checks if the CloudEvent type is a Pub/Sub message event.
  bool _isPubSubEvent(String type) =>
      type == 'google.cloud.pubsub.topic.v1.messagePublished';
}
