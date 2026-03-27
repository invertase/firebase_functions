// Copyright 2026 Firebase
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:meta/meta.dart';

/// Log severity levels for Cloud Logging.
///
/// See [LogSeverity](https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#logseverity).
enum LogSeverity {
  debug('DEBUG'),
  info('INFO'),
  notice('NOTICE'),
  warning('WARNING'),
  error('ERROR'),
  critical('CRITICAL'),
  alert('ALERT'),
  emergency('EMERGENCY');

  const LogSeverity(this.value);

  /// The string value used in Cloud Logging JSON entries.
  final String value;
}

/// A structured Cloud Logging log entry.
///
/// A [Map] where `severity` (required) and `message` (optional) are standard
/// Cloud Logging fields. All other keys are included in the `jsonPayload`
/// of the logged entry.
typedef LogEntry = Map<String, Object?>;

/// Removes circular references from an object graph for safe JSON
/// serialization.
///
/// Returns a new data structure with circular references replaced by the
/// string `"[Circular]"`. Does not mutate the original object.
///
/// Handles [DateTime] by converting to ISO 8601 UTC string and respects
/// objects with a `toJson()` method.
Object? removeCircular(Object? obj, [Set<Object>? existingRefs]) {
  if (obj == null || obj is bool || obj is num || obj is String) {
    return obj;
  }

  if (obj is DateTime) {
    return obj.toUtc().toIso8601String();
  }

  final refs = existingRefs ?? {};

  // Handle objects with toJson() (custom serializable types).
  if (obj is! Map && obj is! List) {
    try {
      final result = (obj as dynamic).toJson();
      return removeCircular(result, refs);
    } catch (_) {
      return obj.toString();
    }
  }

  if (refs.contains(obj)) {
    return '[Circular]';
  }
  refs.add(obj);

  late final Object? result;

  if (obj is Map) {
    final map = <String, Object?>{};
    for (final MapEntry(:key, :value) in obj.entries) {
      try {
        if (value != null && refs.contains(value)) {
          map[key.toString()] = '[Circular]';
        } else {
          map[key.toString()] = removeCircular(value, refs);
        }
      } catch (_) {
        map[key.toString()] = '[Error - cannot serialize]';
      }
    }
    result = map;
  } else {
    // obj is List
    result = List<Object?>.generate((obj as List).length, (i) {
      final value = obj[i];
      try {
        if (value != null && refs.contains(value)) {
          return '[Circular]';
        }
        return removeCircular(value, refs);
      } catch (_) {
        return '[Error - cannot serialize]';
      }
    });
  }

  refs.remove(obj);
  return result;
}

/// Whether a severity level should be written to stderr.
bool _isStderrSeverity(String severity) => switch (severity) {
  'WARNING' || 'ERROR' || 'CRITICAL' || 'ALERT' || 'EMERGENCY' => true,
  _ => false,
};

/// Creates a new [Logger] instance.
///
/// [stdoutWriter] and [stderrWriter] can be provided for testing.
@internal
Logger createLogger({
  void Function(String line)? stdoutWriter,
  void Function(String line)? stderrWriter,
}) => Logger._(stdoutWriter: stdoutWriter, stderrWriter: stderrWriter);

/// Structured logger for Cloud Logging, compatible with the Firebase
/// Functions Node.js SDK `logger` namespace.
///
/// Writes JSON-formatted [LogEntry] objects to stdout or stderr depending
/// on severity. DEBUG, INFO, and NOTICE go to stdout; WARNING, ERROR,
/// CRITICAL, ALERT, and EMERGENCY go to stderr.
///
/// ## Usage
///
/// ```dart
/// import 'package:firebase_functions/logger.dart';
///
/// // Simple message
/// logger.info('Request received');
///
/// // Message with structured data
/// logger.info('Processing', {'userId': '123', 'action': 'update'});
///
/// // Structured data only (message inside the map is preserved)
/// logger.info({'message': 'Custom', 'requestId': 'abc'});
///
/// // Low-level structured entry
/// logger.write({'severity': 'NOTICE', 'message': 'Custom', 'code': 42});
/// ```
final class Logger {
  /// Creates a [Logger] instance.
  ///
  /// Custom [stdoutWriter] and [stderrWriter] can be provided for testing.
  Logger._({
    void Function(String line)? stdoutWriter,
    void Function(String line)? stderrWriter,
  }) : _stdoutWriter = stdoutWriter ?? _defaultStdoutWriter,
       _stderrWriter = stderrWriter ?? _defaultStderrWriter;

  final void Function(String line) _stdoutWriter;
  final void Function(String line) _stderrWriter;

  static void _defaultStdoutWriter(String line) => io.stdout.writeln(line);
  static void _defaultStderrWriter(String line) => io.stderr.writeln(line);

  /// Writes a [LogEntry] to stdout or stderr depending on severity.
  ///
  /// The entry must contain a `severity` key. If a trace ID is available
  /// in the current [Zone] (via [traceIdZoneKey]), it is automatically added
  /// to the entry.
  void write(LogEntry entry) {
    // Add trace context if available.

    final projectId = Zone.current[projectIdZoneKey] as String?;
    final traceId = Zone.current[traceIdZoneKey] as String?;

    if (projectId != null && traceId != null) {
      entry['logging.googleapis.com/trace'] =
          'projects/$projectId/traces/$traceId';
    }

    final sanitized = removeCircular(entry);
    final json = jsonEncode(sanitized);

    final severity = entry['severity'] as String? ?? 'INFO';
    if (_isStderrSeverity(severity)) {
      _stderrWriter(json);
    } else {
      _stdoutWriter(json);
    }
  }

  /// Writes a DEBUG severity log.
  ///
  /// If [messageOrPayload] is a [Map<String, Object?>] and [jsonPayload]
  /// is null, the map is used directly as the structured log entry
  /// (preserving any `message` key within it).
  ///
  /// Otherwise, [messageOrPayload] is converted to a string for the
  /// `message` field, and [jsonPayload] entries are merged into the entry.
  void debug(Object? messageOrPayload, [Map<String, Object?>? jsonPayload]) {
    write(_entryFromArgs('DEBUG', messageOrPayload, jsonPayload));
  }

  /// Writes an INFO severity log. Alias for [info].
  void log(Object? messageOrPayload, [Map<String, Object?>? jsonPayload]) {
    write(_entryFromArgs('INFO', messageOrPayload, jsonPayload));
  }

  /// Writes an INFO severity log.
  void info(Object? messageOrPayload, [Map<String, Object?>? jsonPayload]) {
    write(_entryFromArgs('INFO', messageOrPayload, jsonPayload));
  }

  /// Writes a WARNING severity log.
  void warn(Object? messageOrPayload, [Map<String, Object?>? jsonPayload]) {
    write(_entryFromArgs('WARNING', messageOrPayload, jsonPayload));
  }

  /// Writes an ERROR severity log.
  void error(Object? messageOrPayload, [Map<String, Object?>? jsonPayload]) {
    write(_entryFromArgs('ERROR', messageOrPayload, jsonPayload));
  }
}

/// Constructs a [LogEntry] from a severity, message, and optional JSON
/// payload.
///
/// When [messageOrPayload] is a [Map<String, Object?>] and [jsonPayload]
/// is null, the map is used directly as structured data (matching Node.js
/// behavior where a lone plain-object argument is treated as the entry).
///
/// Otherwise, [messageOrPayload] is stringified and set as the `message`
/// field, overwriting any `message` key from [jsonPayload].
LogEntry _entryFromArgs(
  String severity,
  Object? messageOrPayload,
  Map<String, Object?>? jsonPayload,
) {
  // If only a Map was passed, treat it as structured data.
  if (messageOrPayload is Map<String, Object?> && jsonPayload == null) {
    return {...messageOrPayload, 'severity': severity};
  }

  final entry = <String, Object?>{
    if (jsonPayload != null) ...jsonPayload,
    'severity': severity,
  };

  final messageStr = '$messageOrPayload';
  if (messageStr.isNotEmpty) {
    entry['message'] = messageStr;
  }

  return entry;
}

/// Default [Logger] instance.
///
/// This is the primary way to use the logger:
/// ```dart
/// import 'package:firebase_functions/logger.dart';
///
/// logger.info('Hello');
/// logger.warn('Something is off', {'requestId': 'abc'});
/// ```
final logger = Logger._();

/// Standard HTTP header used by
/// [Cloud Trace](https://cloud.google.com/trace/docs/setup).
@internal
const cloudTraceContextHeader = 'x-cloud-trace-context';

/// Zone key for propagating trace IDs.
@internal
final Object traceIdZoneKey = Object();

/// Zone key for propagating project ID.
@internal
final Object projectIdZoneKey = Object();
