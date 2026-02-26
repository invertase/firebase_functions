import '../common/cloud_event.dart';

/// The type of principal that triggered the event.
///
/// Matches the Node.js SDK's `AuthType` type.
enum AuthType {
  /// A non-user principal used to identify a workload or machine user.
  serviceAccount('service_account'),

  /// A non-user client API key.
  apiKey('api_key'),

  /// An obscured identity used when Cloud Platform or another system
  /// triggered the event (e.g., TTL-based database deletion).
  system('system'),

  /// An unauthenticated action.
  unauthenticated('unauthenticated'),

  /// A general type to capture all other principals not captured
  /// in other auth types.
  unknown('unknown');

  const AuthType(this.value);

  /// The wire value as sent in CloudEvent headers.
  final String value;

  /// Parses an [AuthType] from the wire value string.
  ///
  /// Returns [AuthType.unknown] if the value is not recognized.
  static AuthType fromString(String value) => switch (value) {
    'service_account' => AuthType.serviceAccount,
    'api_key' => AuthType.apiKey,
    'system' => AuthType.system,
    'unauthenticated' => AuthType.unauthenticated,
    _ => AuthType.unknown,
  };
}

/// A CloudEvent that contains a DocumentSnapshot or a `Change<DocumentSnapshot>`.
///
/// This event type extends the base [CloudEvent] with Firestore-specific fields.
class FirestoreEvent<T extends Object?> extends CloudEvent<T> {
  const FirestoreEvent({
    super.data,
    required super.id,
    required super.source,
    required super.specversion,
    super.subject,
    required super.time,
    required super.type,
    required this.location,
    required this.project,
    required this.database,
    required this.namespace,
    required this.document,
    required this.params,
  });

  /// Parses a FirestoreEvent from JSON.
  factory FirestoreEvent.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) dataDecoder,
  ) {
    final source = json['source'] as String;

    // Extract Firestore-specific fields from source
    // Source format: //firestore.googleapis.com/projects/{project}/databases/{database}/documents/{document}
    final sourceUri = Uri.parse(source.replaceFirst('//', 'https://'));
    final pathSegments = sourceUri.pathSegments;

    // Parse: projects/{project}/databases/{database}/documents/{document}
    final project = pathSegments[1];
    final database = pathSegments[3];
    final documentPath = pathSegments.sublist(5).join('/');

    // Extract location from subject or use default
    // Subject format: documents/{document}
    final subject = json['subject'] as String?;

    // Parse params from document path wildcards
    // This will be enhanced when we add wildcard support
    final params = <String, String>{};

    return FirestoreEvent<T>(
      data: dataDecoder(json['data'] as Map<String, dynamic>),
      id: json['id'] as String,
      source: source,
      specversion: json['specversion'] as String,
      subject: subject,
      time: DateTime.parse(json['time'] as String),
      type: json['type'] as String,
      location: json['location'] as String? ?? 'us-central1',
      project: project,
      database: database,
      namespace: '(default)',
      document: documentPath,
      params: params,
    );
  }

  /// The location of the Firestore instance.
  final String location;

  /// The project identifier.
  final String project;

  /// The Firestore database.
  final String database;

  /// The Firestore namespace.
  final String namespace;

  /// The document path.
  final String document;

  /// An object containing the values of the path patterns.
  /// Only named capture groups will be populated - {key}, {key=*}, {key=**}
  final Map<String, String> params;

  @override
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) dataEncoder) {
    final json = super.toJson(dataEncoder);
    json['location'] = location;
    json['project'] = project;
    json['database'] = database;
    json['namespace'] = namespace;
    json['document'] = document;
    json['params'] = params;
    return json;
  }
}

/// A [FirestoreEvent] that includes authentication context.
///
/// This event type is used by the `WithAuthContext` trigger variants
/// (e.g., [FirestoreNamespace.onDocumentCreatedWithAuthContext]).
///
/// The auth context identifies which principal triggered the Firestore write.
/// Note: this is different from HTTPS callable auth — it identifies the
/// principal type (service account, API key, etc.), not a Firebase Auth user.
///
/// Example:
/// ```dart
/// firebase.firestore.onDocumentCreatedWithAuthContext(
///   document: 'users/{userId}',
///   (event) async {
///     print('Auth type: ${event.authType}');
///     print('Auth ID: ${event.authId}');
///   },
/// );
/// ```
class FirestoreAuthEvent<T extends Object?> extends FirestoreEvent<T> {
  const FirestoreAuthEvent({
    super.data,
    required super.id,
    required super.source,
    required super.specversion,
    super.subject,
    required super.time,
    required super.type,
    required super.location,
    required super.project,
    required super.database,
    required super.namespace,
    required super.document,
    required super.params,
    required this.authType,
    this.authId,
  });

  /// The type of principal that triggered the event.
  final AuthType authType;

  /// The unique identifier for the principal.
  ///
  /// May be `null` for system-triggered or unauthenticated events.
  final String? authId;

  @override
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) dataEncoder) {
    final json = super.toJson(dataEncoder);
    json['authType'] = authType.value;
    if (authId != null) json['authId'] = authId;
    return json;
  }
}
