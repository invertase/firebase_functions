/// Data model for Cloud Storage object events.
class StorageObjectData {
  const StorageObjectData({
    required this.bucket,
    required this.name,
    required this.generation,
    required this.metageneration,
    this.cacheControl,
    this.componentCount,
    this.contentDisposition,
    this.contentEncoding,
    this.contentLanguage,
    this.contentType,
    this.crc32c,
    this.customerEncryption,
    this.etag,
    this.id,
    this.kind,
    this.md5Hash,
    this.mediaLink,
    this.metadata,
    this.selfLink,
    this.size,
    this.storageClass,
    this.timeCreated,
    this.timeDeleted,
    this.timeStorageClassUpdated,
    this.updated,
  });

  /// Parses a StorageObjectData from JSON (CloudEvent data format).
  factory StorageObjectData.fromJson(Map<String, dynamic> json) {
    return StorageObjectData(
      bucket: json['bucket'] as String,
      name: json['name'] as String,
      generation: json['generation'] as String? ?? '',
      metageneration: json['metageneration'] as String? ?? '',
      cacheControl: json['cacheControl'] as String?,
      componentCount: json['componentCount'] as int?,
      contentDisposition: json['contentDisposition'] as String?,
      contentEncoding: json['contentEncoding'] as String?,
      contentLanguage: json['contentLanguage'] as String?,
      contentType: json['contentType'] as String?,
      crc32c: json['crc32c'] as String?,
      customerEncryption: json['customerEncryption'] != null
          ? CustomerEncryption.fromJson(
              json['customerEncryption'] as Map<String, dynamic>,
            )
          : null,
      etag: json['etag'] as String?,
      id: json['id'] as String?,
      kind: json['kind'] as String?,
      md5Hash: json['md5Hash'] as String?,
      mediaLink: json['mediaLink'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, String>.from(json['metadata'] as Map)
          : null,
      selfLink: json['selfLink'] as String?,
      size: json['size'] as String?,
      storageClass: json['storageClass'] as String?,
      timeCreated: json['timeCreated'] != null
          ? DateTime.parse(json['timeCreated'] as String)
          : null,
      timeDeleted: json['timeDeleted'] != null
          ? DateTime.parse(json['timeDeleted'] as String)
          : null,
      timeStorageClassUpdated: json['timeStorageClassUpdated'] != null
          ? DateTime.parse(json['timeStorageClassUpdated'] as String)
          : null,
      updated: json['updated'] != null
          ? DateTime.parse(json['updated'] as String)
          : null,
    );
  }

  /// The name of the bucket containing this object.
  final String bucket;

  /// Cache-Control directive for the object data.
  final String? cacheControl;

  /// Number of underlying components that make up this object (for composite objects).
  final int? componentCount;

  /// Content-Disposition of the object data.
  final String? contentDisposition;

  /// Content-Encoding of the object data.
  final String? contentEncoding;

  /// Content-Language of the object data.
  final String? contentLanguage;

  /// Content-Type of the object data.
  final String? contentType;

  /// CRC32c checksum.
  final String? crc32c;

  /// Metadata of customer-supplied encryption key, if the object is encrypted
  /// by such a key.
  final CustomerEncryption? customerEncryption;

  /// HTTP 1.1 Entity tag for the object.
  final String? etag;

  /// The content generation of this object. Used for object versioning.
  final String generation;

  /// The ID of the object, including the bucket name, object name, and
  /// generation number.
  final String? id;

  /// The kind of item this is. For objects, this is always "storage#object".
  final String? kind;

  /// MD5 hash of the data.
  final String? md5Hash;

  /// Media download link.
  final String? mediaLink;

  /// User-provided metadata, in key/value pairs.
  final Map<String, String>? metadata;

  /// The version of the metadata for this object at this generation.
  final String metageneration;

  /// The name of the object.
  final String name;

  /// The link to this object.
  final String? selfLink;

  /// Content-Length of the data in bytes.
  final String? size;

  /// Storage class of the object.
  final String? storageClass;

  /// The creation time of the object.
  final DateTime? timeCreated;

  /// The deletion time of the object (only present for deleted objects).
  final DateTime? timeDeleted;

  /// The time at which the object's storage class was last changed.
  final DateTime? timeStorageClassUpdated;

  /// The modification time of the object metadata.
  final DateTime? updated;

  /// Converts this data to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'bucket': bucket,
    'name': name,
    'generation': generation,
    'metageneration': metageneration,
    if (cacheControl != null) 'cacheControl': cacheControl,
    if (componentCount != null) 'componentCount': componentCount,
    if (contentDisposition != null) 'contentDisposition': contentDisposition,
    if (contentEncoding != null) 'contentEncoding': contentEncoding,
    if (contentLanguage != null) 'contentLanguage': contentLanguage,
    if (contentType != null) 'contentType': contentType,
    if (crc32c != null) 'crc32c': crc32c,
    if (customerEncryption != null)
      'customerEncryption': customerEncryption!.toJson(),
    if (etag != null) 'etag': etag,
    if (id != null) 'id': id,
    if (kind != null) 'kind': kind,
    if (md5Hash != null) 'md5Hash': md5Hash,
    if (mediaLink != null) 'mediaLink': mediaLink,
    if (metadata != null) 'metadata': metadata,
    if (selfLink != null) 'selfLink': selfLink,
    if (size != null) 'size': size,
    if (storageClass != null) 'storageClass': storageClass,
    if (timeCreated != null) 'timeCreated': timeCreated!.toIso8601String(),
    if (timeDeleted != null) 'timeDeleted': timeDeleted!.toIso8601String(),
    if (timeStorageClassUpdated != null)
      'timeStorageClassUpdated': timeStorageClassUpdated!.toIso8601String(),
    if (updated != null) 'updated': updated!.toIso8601String(),
  };
}

/// Metadata of customer-supplied encryption key.
class CustomerEncryption {
  const CustomerEncryption({
    required this.encryptionAlgorithm,
    required this.keySha256,
  });

  /// Parses a CustomerEncryption from JSON.
  factory CustomerEncryption.fromJson(Map<String, dynamic> json) {
    return CustomerEncryption(
      encryptionAlgorithm: json['encryptionAlgorithm'] as String? ?? '',
      keySha256: json['keySha256'] as String? ?? '',
    );
  }

  /// The encryption algorithm.
  final String encryptionAlgorithm;

  /// SHA256 hash value of the encryption key.
  final String keySha256;

  /// Converts this data to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'encryptionAlgorithm': encryptionAlgorithm,
    'keySha256': keySha256,
  };
}
