// Copyright 2026 Google LLC
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
