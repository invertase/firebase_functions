/// The data within Firebase Remote Config update events.
class ConfigUpdateData {
  const ConfigUpdateData({
    required this.versionNumber,
    required this.updateTime,
    required this.updateUser,
    required this.description,
    required this.updateOrigin,
    required this.updateType,
    this.rollbackSource,
  });

  /// Parses a ConfigUpdateData from JSON (CloudEvent data format).
  factory ConfigUpdateData.fromJson(Map<String, dynamic> json) {
    return ConfigUpdateData(
      versionNumber: json['versionNumber'] as num,
      updateTime: DateTime.parse(json['updateTime'] as String),
      updateUser: ConfigUser.fromJson(
        json['updateUser'] as Map<String, dynamic>,
      ),
      description: json['description'] as String? ?? '',
      updateOrigin: ConfigUpdateOrigin.fromValue(
        json['updateOrigin'] as String,
      ),
      updateType: ConfigUpdateType.fromValue(json['updateType'] as String),
      rollbackSource: json['rollbackSource'] as int?,
    );
  }

  /// The version number of the version's corresponding Remote Config template.
  final num versionNumber;

  /// When the Remote Config template was written to the Remote Config server.
  final DateTime updateTime;

  /// Aggregation of all metadata fields about the account that performed
  /// the update.
  final ConfigUser updateUser;

  /// The user-provided description of the corresponding Remote Config template.
  final String description;

  /// Where the update action originated.
  final ConfigUpdateOrigin updateOrigin;

  /// What type of update was made.
  final ConfigUpdateType updateType;

  /// Only present if this version is the result of a rollback, and will be
  /// the version number of the Remote Config template that was rolled-back to.
  final int? rollbackSource;

  /// Converts this data to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'versionNumber': versionNumber,
    'updateTime': updateTime.toIso8601String(),
    'updateUser': updateUser.toJson(),
    'description': description,
    'updateOrigin': updateOrigin.value,
    'updateType': updateType.value,
    if (rollbackSource != null) 'rollbackSource': rollbackSource,
  };
}

/// The person/service account that wrote a Remote Config template.
class ConfigUser {
  const ConfigUser({
    required this.name,
    required this.email,
    required this.imageUrl,
  });

  /// Parses a ConfigUser from JSON.
  factory ConfigUser.fromJson(Map<String, dynamic> json) {
    return ConfigUser(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  /// Display name.
  final String name;

  /// Email address.
  final String email;

  /// Image URL.
  final String imageUrl;

  /// Converts this user to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'email': email,
    'imageUrl': imageUrl,
  };
}

/// What type of update origin was associated with the Remote Config template
/// version.
enum ConfigUpdateOrigin {
  remoteConfigUpdateOriginUnspecified(
    'REMOTE_CONFIG_UPDATE_ORIGIN_UNSPECIFIED',
  ),
  console('CONSOLE'),
  restApi('REST_API'),
  adminSdkNode('ADMIN_SDK_NODE');

  const ConfigUpdateOrigin(this.value);

  /// The string value as sent in CloudEvents.
  final String value;

  /// Parses a ConfigUpdateOrigin from its string value.
  static ConfigUpdateOrigin fromValue(String value) {
    return ConfigUpdateOrigin.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ConfigUpdateOrigin.remoteConfigUpdateOriginUnspecified,
    );
  }
}

/// What type of update was associated with the Remote Config template version.
enum ConfigUpdateType {
  remoteConfigUpdateTypeUnspecified('REMOTE_CONFIG_UPDATE_TYPE_UNSPECIFIED'),
  incrementalUpdate('INCREMENTAL_UPDATE'),
  forcedUpdate('FORCED_UPDATE'),
  rollback('ROLLBACK');

  const ConfigUpdateType(this.value);

  /// The string value as sent in CloudEvents.
  final String value;

  /// Parses a ConfigUpdateType from its string value.
  static ConfigUpdateType fromValue(String value) {
    return ConfigUpdateType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ConfigUpdateType.remoteConfigUpdateTypeUnspecified,
    );
  }
}
