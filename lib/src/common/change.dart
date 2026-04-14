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

/// Represents a change to a data structure with before and after states.
///
/// This is used by both Firestore and Realtime Database triggers for
/// `onDocumentUpdated`, `onDocumentWritten`, `onValueUpdated`, and
/// `onValueWritten` handlers.
class Change<T> {
  const Change({required this.before, required this.after});

  /// The state before the change.
  /// May be null if the data didn't exist (for creates).
  final T? before;

  /// The state after the change.
  /// May be null if the data was deleted.
  final T? after;

  @override
  String toString() => 'Change(before: $before, after: $after)';
}
