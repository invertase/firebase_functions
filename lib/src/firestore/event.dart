import '../common/cloud_event.dart';

/// A CloudEvent that contains a DocumentSnapshot or a Change<DocumentSnapshot>.
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
