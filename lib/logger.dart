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

export 'src/logger/logger.dart'
    hide createLogger, projectIdZoneKey, traceIdZoneKey;
