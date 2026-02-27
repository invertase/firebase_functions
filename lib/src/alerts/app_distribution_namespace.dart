import 'dart:async';

import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

import '../common/cloud_event.dart';
import '../common/utilities.dart';
import '../firebase.dart';
import 'alert_event.dart';
import 'alert_type.dart';
import 'options.dart';

/// App Distribution alerts sub-namespace.
///
/// Provides methods to handle App Distribution-specific alerts.
class AppDistributionNamespace {
  const AppDistributionNamespace(this._firebase);

  final Firebase _firebase;

  /// Handles new tester iOS device alerts.
  void onNewTesterIosDevicePublished(
    FutureOr<void> Function(AlertEvent<NewTesterDevicePayload> event) handler, {
    // ignore: experimental_member_use
    @mustBeConst AlertOptions? options = const AlertOptions(),
  }) {
    _registerAppDistributionHandler<NewTesterDevicePayload>(
      const AppDistributionNewTesterIosDevice(),
      handler,
      NewTesterDevicePayload.fromJson,
      options,
    );
  }

  /// Handles in-app feedback alerts.
  void onInAppFeedbackPublished(
    FutureOr<void> Function(AlertEvent<InAppFeedbackPayload> event) handler, {
    // ignore: experimental_member_use
    @mustBeConst AlertOptions? options = const AlertOptions(),
  }) {
    _registerAppDistributionHandler<InAppFeedbackPayload>(
      const AppDistributionInAppFeedback(),
      handler,
      InAppFeedbackPayload.fromJson,
      options,
    );
  }

  void _registerAppDistributionHandler<T extends Object>(
    AppDistributionAlertType alertType,
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
      } catch (e, stackTrace) {
        return logEventHandlerError(e, stackTrace);
      }
    });
  }

  String _alertTypeToFunctionName(String alertType) {
    final sanitized = alertType.replaceAll('.', '_').replaceAll('-', '');
    return 'onAlertPublished_$sanitized';
  }

  bool _isAlertEvent(String type) => type == alertEventType;
}
