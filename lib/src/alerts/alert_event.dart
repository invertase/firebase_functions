import '../common/cloud_event.dart';

/// The CloudEvent data emitted by Firebase Alerts.
class AlertData<T extends Object?> {
  const AlertData({
    required this.createTime,
    this.endTime,
    required this.payload,
  });

  factory AlertData.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) payloadDecoder,
  ) => AlertData<T>(
    createTime: DateTime.parse(json['createTime'] as String),
    endTime:
        json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
    payload: payloadDecoder(json['payload'] as Map<String, dynamic>),
  );

  /// Time that the event was created.
  final DateTime createTime;

  /// Time that the event ended.
  /// Optional, only present for ongoing alerts.
  final DateTime? endTime;

  /// Payload of the event, which includes the details of the specific alert.
  final T payload;

  Map<String, dynamic> toJson(
    Map<String, dynamic> Function(T) payloadEncoder,
  ) => {
    'createTime': createTime.toIso8601String(),
    if (endTime != null) 'endTime': endTime!.toIso8601String(),
    'payload': payloadEncoder(payload),
  };
}

/// A custom CloudEvent for Firebase Alerts (with custom extension attributes).
class AlertEvent<T extends Object?> extends CloudEvent<AlertData<T>> {
  const AlertEvent({
    super.data,
    required super.id,
    required super.source,
    required super.specversion,
    super.subject,
    required super.time,
    required super.type,
    required this.alertType,
    this.appId,
  });

  /// Creates an AlertEvent from a JSON map.
  ///
  /// The [payloadDecoder] function is used to parse the payload from JSON.
  factory AlertEvent.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) payloadDecoder,
  ) {
    // Handle alerttype -> alertType conversion (lowercase from CloudEvents)
    final alertTypeValue =
        json['alertType'] as String? ?? json['alerttype'] as String?;
    final appIdValue = json['appId'] as String? ?? json['appid'] as String?;

    return AlertEvent<T>(
      data: AlertData.fromJson(
        json['data'] as Map<String, dynamic>,
        payloadDecoder,
      ),
      id: json['id'] as String,
      source: json['source'] as String,
      specversion: json['specversion'] as String,
      subject: json['subject'] as String?,
      time: DateTime.parse(json['time'] as String),
      type: json['type'] as String,
      alertType: alertTypeValue ?? '',
      appId: appIdValue,
    );
  }

  /// The type of the alerts that got triggered.
  final String alertType;

  /// The Firebase App ID that's associated with the alert.
  /// This is optional, and only present when the alert is targeting
  /// a specific Firebase App.
  final String? appId;
}

/// The CloudEvent type for Firebase Alerts.
const alertEventType = 'google.firebase.firebasealerts.alerts.v1.published';
