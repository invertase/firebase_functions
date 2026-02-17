import '../common/cloud_event.dart';
import 'storage_object_data.dart';

/// A CloudEvent for Cloud Storage object events.
///
/// Extends [CloudEvent] with a convenience [bucket] getter.
class StorageEvent extends CloudEvent<StorageObjectData> {
  const StorageEvent({
    required super.id,
    required super.source,
    required super.specversion,
    required super.time,
    required super.type,
    super.data,
    super.subject,
  });

  /// Creates a StorageEvent from a CloudEvent JSON payload.
  factory StorageEvent.fromJson(Map<String, dynamic> json) {
    final cloudEvent = CloudEvent<StorageObjectData>.fromJson(
      json,
      StorageObjectData.fromJson,
    );

    return StorageEvent(
      id: cloudEvent.id,
      source: cloudEvent.source,
      specversion: cloudEvent.specversion,
      time: cloudEvent.time,
      type: cloudEvent.type,
      data: cloudEvent.data,
      subject: cloudEvent.subject,
    );
  }

  /// The name of the bucket containing the object that triggered the event.
  String get bucket => data!.bucket;
}
