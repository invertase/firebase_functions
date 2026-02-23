import 'dart:async';

import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

import '../common/cloud_event.dart';
import '../firebase.dart';
import 'options.dart';

/// Eventarc triggers namespace.
///
/// Provides methods to define Eventarc-triggered Cloud Functions.
class EventarcNamespace extends FunctionsNamespace {
  const EventarcNamespace(super.firebase);

  /// Creates a function triggered by a custom Eventarc event.
  ///
  /// The handler receives a [CloudEvent] containing the event data.
  ///
  /// Example:
  /// ```dart
  /// firebase.eventarc.onCustomEventPublished(
  ///   eventType: 'com.example.my-event',
  ///   options: const EventarcTriggerOptions(
  ///     channel: 'my-channel',
  ///     filters: {'key': 'value'},
  ///   ),
  ///   (event) async {
  ///     print('Received event: ${event.type}');
  ///     print('Data: ${event.data}');
  ///   },
  /// );
  /// ```
  void onCustomEventPublished(
    Future<void> Function(CloudEvent<Object> event) handler, {
    // ignore: experimental_member_use
    @mustBeConst required String eventType,
    // ignore: experimental_member_use
    @mustBeConst
    EventarcTriggerOptions? options = const EventarcTriggerOptions(),
  }) {
    // Generate function name from event type
    final functionName = _eventTypeToFunctionName(eventType);

    firebase.registerFunction(functionName, (request) async {
      try {
        // Read and parse CloudEvent
        final json = await parseAndValidateCloudEvent(request);

        // Parse CloudEvent with generic data
        final event = CloudEvent<Object>.fromJson(json, (data) => data);

        // Execute handler
        await handler(event);

        // Return success
        return Response.ok('');
      } on FormatException catch (e) {
        return Response(400, body: 'Invalid CloudEvent: ${e.message}');
      } catch (e) {
        return Response(500, body: 'Error processing Eventarc event: $e');
      }
    });
  }

  /// Converts an event type to a function name.
  ///
  /// Examples:
  /// - 'com.example.my-event' -> 'onCustomEventPublished_comexamplemyevent'
  String _eventTypeToFunctionName(String eventType) {
    final sanitized = eventType.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
    return 'onCustomEventPublished_$sanitized';
  }
}
