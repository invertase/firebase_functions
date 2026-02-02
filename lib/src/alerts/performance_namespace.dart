import 'dart:async';

import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

import '../common/cloud_event.dart';
import '../firebase.dart';
import 'alert_event.dart';
import 'alert_type.dart';
import 'options.dart';

/// Performance alerts sub-namespace.
///
/// Provides methods to handle Performance-specific alerts.
class PerformanceNamespace {
  const PerformanceNamespace(this._firebase);

  final Firebase _firebase;

  /// Handles performance threshold alerts.
  void onThresholdAlertPublished(
    FutureOr<void> Function(AlertEvent<ThresholdAlertPayload> event) handler, {
    // ignore: experimental_member_use
    @mustBeConst AlertOptions? options = const AlertOptions(),
  }) {
    _registerPerformanceHandler<ThresholdAlertPayload>(
      const PerformanceThreshold(),
      handler,
      ThresholdAlertPayload.fromJson,
      options,
    );
  }

  void _registerPerformanceHandler<T extends Object>(
    PerformanceAlertType alertType,
    FutureOr<void> Function(AlertEvent<T> event) handler,
    T Function(Map<String, dynamic>) payloadDecoder,
    AlertOptions? options,
  ) {
    final functionName = _alertTypeToFunctionName(alertType.value);

    _firebase.registerFunction(functionName, (request) async {
      try {
        final json = await parseAndValidateCloudEvent(request);

        if (!_isAlertEvent(json['type'] as String)) {
          return Response(
            400,
            body: 'Invalid event type for alerts: ${json['type']}',
          );
        }

        final event = AlertEvent<T>.fromJson(json, payloadDecoder);
        await handler(event);
        return Response.ok('');
      } on FormatException catch (e) {
        return Response(400, body: 'Invalid CloudEvent: ${e.message}');
      } catch (e) {
        return Response(500, body: 'Error processing alert: $e');
      }
    });
  }

  String _alertTypeToFunctionName(String alertType) {
    final sanitized = alertType.replaceAll('.', '_').replaceAll('-', '');
    return 'onAlertPublished_$sanitized';
  }

  bool _isAlertEvent(String type) => type == alertEventType;
}
