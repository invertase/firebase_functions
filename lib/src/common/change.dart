// Copyright 2026, the Firebase project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT-style license that can be found in the LICENSE file.

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
