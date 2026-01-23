import 'dart:async';

import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

import '../common/cloud_event.dart';
import '../firebase.dart';
import 'alert_event.dart';
import 'alert_type.dart';
import 'options.dart';

/// Billing alerts sub-namespace.
///
/// Provides methods to handle billing-specific alerts.
class BillingNamespace {
  const BillingNamespace(this._firebase);

  final Firebase _firebase;

  /// Handles billing plan update alerts.
  void onPlanUpdatePublished(
    FutureOr<void> Function(AlertEvent<PlanUpdatePayload> event) handler, {
    // ignore: experimental_member_use
    @mustBeConst AlertOptions? options = const AlertOptions(),
  }) {
    _registerBillingHandler<PlanUpdatePayload>(
      const BillingPlanUpdate(),
      handler,
      PlanUpdatePayload.fromJson,
      options,
    );
  }

  /// Handles automated billing plan update alerts.
  void onPlanAutomatedUpdatePublished(
    FutureOr<void> Function(AlertEvent<PlanAutomatedUpdatePayload> event)
    handler, {
    // ignore: experimental_member_use
    @mustBeConst AlertOptions? options = const AlertOptions(),
  }) {
    _registerBillingHandler<PlanAutomatedUpdatePayload>(
      const BillingPlanAutomatedUpdate(),
      handler,
      PlanAutomatedUpdatePayload.fromJson,
      options,
    );
  }

  void _registerBillingHandler<T extends Object>(
    BillingAlertType alertType,
    FutureOr<void> Function(AlertEvent<T> event) handler,
    T Function(Map<String, dynamic>) payloadDecoder,
    AlertOptions? options,
  ) {
    final functionName = _alertTypeToFunctionName(alertType.value);

    _firebase.registerFunction(functionName, (request) async {
      try {
        final bodyString = await request.readAsString();
        final json = parseCloudEventJson(bodyString);
        validateCloudEvent(json);

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
