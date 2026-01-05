import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

import 'document_snapshot.dart';

/// Firestore protobuf parser for CloudEvents.
///
/// This parses the google.events.cloud.firestore.v1.DocumentEventData message
/// which contains document snapshots in protobuf format.
///
/// Protobuf wire format reference:
/// - Field 1 (value): Document after the write
/// - Field 2 (old_value): Document before the write (for updates)
/// - Field 3 (update_mask): Fields that were updated

/// Attempts to parse Firestore DocumentEventData from protobuf bytes.
///
/// Returns a map with:
/// - 'value': The new/current document state (EmulatorDocumentSnapshot)
/// - 'old_value': The old document state (for updates), may be null
///
/// The CloudEvent protobuf structure is:
/// ```protobuf
/// message DocumentEventData {
///   google.firestore.v1.Document value = 1;
///   google.firestore.v1.Document old_value = 2;
///   google.firestore.v1.DocumentMask update_mask = 3;
/// }
/// ```
Map<String, EmulatorDocumentSnapshot?>? parseDocumentEventData(
  Uint8List bytes,
) {
  try {
    final input = CodedBufferReader(bytes);
    EmulatorDocumentSnapshot? value;
    EmulatorDocumentSnapshot? oldValue;

    // Parse protobuf wire format manually
    while (!input.isAtEnd()) {
      final tag = input.readTag();
      final fieldNumber = tag >>> 3;

      switch (fieldNumber) {
        case 1: // value field
          final docBytes = input.readBytes();
          value = _parseFirestoreDocument(docBytes);
          break;
        case 2: // old_value field
          final docBytes = input.readBytes();
          oldValue = _parseFirestoreDocument(docBytes);
          break;
        case 3: // update_mask field (skip for now)
          input.skipField(tag);
          break;
        default:
          input.skipField(tag);
      }
    }

    return {
      'value': value,
      'old_value': oldValue,
    };
  } catch (e, stack) {
    print('Error parsing DocumentEventData protobuf: $e');
    print('Stack: $stack');
    return null;
  }
}

/// Parses a google.firestore.v1.Document from protobuf bytes.
///
/// The Document protobuf structure is:
/// ```protobuf
/// message Document {
///   string name = 1;
///   map<string, Value> fields = 2;
///   google.protobuf.Timestamp create_time = 3;
///   google.protobuf.Timestamp update_time = 4;
/// }
/// ```
EmulatorDocumentSnapshot? _parseFirestoreDocument(Uint8List bytes) {
  try {
    // Parse protobuf Document manually
    final input = CodedBufferReader(bytes);
    String? name;
    final fields = <String, dynamic>{};
    DateTime? createTime;
    DateTime? updateTime;

    while (!input.isAtEnd()) {
      final tag = input.readTag();
      final fieldNumber = tag >>> 3;

      switch (fieldNumber) {
        case 1: // name
          name = input.readString();
          break;
        case 2: // fields (map<string, Value>)
          final mapBytes = input.readBytes();
          final mapInput = CodedBufferReader(mapBytes);

          String? key;
          dynamic value;

          while (!mapInput.isAtEnd()) {
            final mapTag = mapInput.readTag();
            final mapFieldNumber = mapTag >>> 3;

            if (mapFieldNumber == 1) {
              // Key
              key = mapInput.readString();
            } else if (mapFieldNumber == 2) {
              // Value
              final valueBytes = mapInput.readBytes();
              value = _parseFirestoreValue(valueBytes);
            } else {
              mapInput.skipField(mapTag);
            }
          }

          if (key != null) {
            fields[key] = value;
          }
          break;
        case 3: // create_time
          final timestampBytes = input.readBytes();
          createTime = _parseTimestamp(timestampBytes);
          break;
        case 4: // update_time
          final timestampBytes = input.readBytes();
          updateTime = _parseTimestamp(timestampBytes);
          break;
        default:
          input.skipField(tag);
      }
    }

    if (name == null) {
      print('Warning: Document has no name field');
      return null;
    }

    // Extract document ID and path from name
    // Format: projects/{project}/databases/{db}/documents/{path}
    final parts = name.split('/documents/');
    final path = parts.length > 1 ? parts[1] : '';
    final pathParts = path.split('/');
    final id = pathParts.isNotEmpty ? pathParts.last : '';

    return EmulatorDocumentSnapshot(
      id: id,
      path: path,
      fields: fields,
      createTime: createTime,
      updateTime: updateTime,
    );
  } catch (e, stack) {
    print('Error parsing Document protobuf: $e');
    print('Stack: $stack');
    return null;
  }
}

/// Parses a google.firestore.v1.Value from protobuf bytes.
dynamic _parseFirestoreValue(Uint8List bytes) {
  try {
    final input = CodedBufferReader(bytes);

    while (!input.isAtEnd()) {
      final tag = input.readTag();
      final fieldNumber = tag >>> 3;

      // Value is a oneof, so only one field will be set
      switch (fieldNumber) {
        case 11: // string_value
          return input.readString();
        case 2: // integer_value
          return input.readInt64();
        case 3: // double_value
          return input.readDouble();
        case 1: // boolean_value
          return input.readBool();
        case 10: // timestamp_value
          final timestampBytes = input.readBytes();
          return _parseTimestamp(timestampBytes);
        case 17: // null_value
          input.readEnum();
          return null;
        case 6: // map_value
          final mapBytes = input.readBytes();
          return _parseMapValue(mapBytes);
        case 9: // array_value
          final arrayBytes = input.readBytes();
          return _parseArrayValue(arrayBytes);
        default:
          input.skipField(tag);
      }
    }

    return null;
  } catch (e) {
    print('Error parsing Value: $e');
    return null;
  }
}

/// Parses a MapValue (nested map).
Map<String, dynamic> _parseMapValue(Uint8List bytes) {
  final result = <String, dynamic>{};
  final input = CodedBufferReader(bytes);

  while (!input.isAtEnd()) {
    final tag = input.readTag();
    final fieldNumber = tag >>> 3;

    if (fieldNumber == 1) {
      // fields map
      final entryBytes = input.readBytes();
      final entryInput = CodedBufferReader(entryBytes);

      String? key;
      dynamic value;

      while (!entryInput.isAtEnd()) {
        final entryTag = entryInput.readTag();
        final entryFieldNumber = entryTag >>> 3;

        if (entryFieldNumber == 1) {
          key = entryInput.readString();
        } else if (entryFieldNumber == 2) {
          final valueBytes = entryInput.readBytes();
          value = _parseFirestoreValue(valueBytes);
        } else {
          entryInput.skipField(entryTag);
        }
      }

      if (key != null) {
        result[key] = value;
      }
    } else {
      input.skipField(tag);
    }
  }

  return result;
}

/// Parses an ArrayValue (list).
List<dynamic> _parseArrayValue(Uint8List bytes) {
  final result = <dynamic>[];
  final input = CodedBufferReader(bytes);

  while (!input.isAtEnd()) {
    final tag = input.readTag();
    final fieldNumber = tag >>> 3;

    if (fieldNumber == 1) {
      // values repeated
      final valueBytes = input.readBytes();
      result.add(_parseFirestoreValue(valueBytes));
    } else {
      input.skipField(tag);
    }
  }

  return result;
}

/// Parses a google.protobuf.Timestamp.
DateTime? _parseTimestamp(Uint8List bytes) {
  try {
    final input = CodedBufferReader(bytes);
    int? seconds;
    int? nanos;

    while (!input.isAtEnd()) {
      final tag = input.readTag();
      final fieldNumber = tag >>> 3;

      if (fieldNumber == 1) {
        // seconds
        seconds = input.readInt64().toInt();
      } else if (fieldNumber == 2) {
        // nanos
        nanos = input.readInt32();
      } else {
        input.skipField(tag);
      }
    }

    if (seconds != null) {
      final micros = seconds * 1000000 + (nanos ?? 0) ~/ 1000;
      return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
    }

    return null;
  } catch (e) {
    print('Error parsing Timestamp: $e');
    return null;
  }
}
