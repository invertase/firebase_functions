/// Structured logger for Cloud Logging, compatible with the Firebase
/// Functions Node.js SDK `logger` namespace.
///
/// ## Usage
///
/// ```dart
/// import 'package:firebase_functions/logger.dart';
///
/// logger.info('Request received');
/// logger.warn('Slow query', {'durationMs': 1200, 'query': 'SELECT ...'});
/// logger.error('Failed to process request');
/// ```
///
/// ## Structured Logging
///
/// Pass a [Map<String, Object?>] as the second argument to include
/// structured data in the Cloud Logging `jsonPayload`:
///
/// ```dart
/// logger.info('User signed in', {
///   'userId': user.id,
///   'provider': 'google',
/// });
/// ```
///
/// Or pass a [Map] as the sole argument for structured-only entries:
///
/// ```dart
/// logger.info({'message': 'Batch complete', 'processedCount': 42});
/// ```
///
/// ## Severity Routing
///
/// - **stdout**: DEBUG, INFO, NOTICE
/// - **stderr**: WARNING, ERROR, CRITICAL, ALERT, EMERGENCY
library;

export 'src/logger/logger.dart';
