import '../common/cloud_event.dart';

/// A CloudEvent that contains a DataSnapshot or a Change<DataSnapshot>.
///
/// This event type extends the base [CloudEvent] with Realtime Database-specific fields.
class DatabaseEvent<T extends Object?> extends CloudEvent<T> {
  const DatabaseEvent({
    super.data,
    required super.id,
    required super.source,
    required super.specversion,
    super.subject,
    required super.time,
    required super.type,
    required this.firebaseDatabaseHost,
    required this.instance,
    required this.ref,
    required this.location,
    required this.params,
  });

  /// Parses a DatabaseEvent from JSON.
  factory DatabaseEvent.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) dataDecoder,
  ) {
    final source = json['source'] as String;

    // Extract instance from source
    // Source format: //firebase.googleapis.com/projects/{project}/instances/{instance}/refs/{ref}
    final sourceUri = Uri.parse(source.replaceFirst('//', 'https://'));
    final pathSegments = sourceUri.pathSegments;

    // Parse: projects/{project}/instances/{instance}/refs/{ref}
    var instance = '';
    var refPath = '';

    for (var i = 0; i < pathSegments.length; i++) {
      if (pathSegments[i] == 'instances' && i + 1 < pathSegments.length) {
        instance = pathSegments[i + 1];
      }
      if (pathSegments[i] == 'refs' && i + 1 < pathSegments.length) {
        refPath = pathSegments.sublist(i + 1).join('/');
      }
    }

    // Parse params from ref path wildcards (will be enhanced with actual extraction)
    final params = <String, String>{};

    return DatabaseEvent<T>(
      data: dataDecoder(json['data'] as Map<String, dynamic>),
      id: json['id'] as String,
      source: source,
      specversion: json['specversion'] as String,
      subject: json['subject'] as String?,
      time: DateTime.parse(json['time'] as String),
      type: json['type'] as String,
      firebaseDatabaseHost: json['firebasedatabasehost'] as String? ?? '',
      instance: instance,
      ref: refPath,
      location: json['location'] as String? ?? 'us-central1',
      params: params,
    );
  }

  /// The domain of the database instance.
  ///
  /// For example: 'firebaseio.com' or 'firebasedatabase.app'.
  final String firebaseDatabaseHost;

  /// The instance ID portion of the fully qualified resource name.
  ///
  /// For example: 'my-project-default-rtdb'.
  final String instance;

  /// The database reference path.
  ///
  /// For example: '/users/user123' or '/messages/-N123abc'.
  final String ref;

  /// The location of the database.
  ///
  /// For example: 'us-central1'.
  final String location;

  /// An object containing the values of the path patterns.
  ///
  /// Only named capture groups will be populated - {key}, {key=*}, {key=**}
  ///
  /// For example, if the ref pattern is '/users/{userId}/posts/{postId}'
  /// and the actual ref is '/users/abc123/posts/xyz789', then params
  /// will be {'userId': 'abc123', 'postId': 'xyz789'}.
  final Map<String, String> params;

  @override
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) dataEncoder) {
    final json = super.toJson(dataEncoder);
    json['firebaseDatabaseHost'] = firebaseDatabaseHost;
    json['instance'] = instance;
    json['ref'] = ref;
    json['location'] = location;
    json['params'] = params;
    return json;
  }
}
