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

// ignore_for_file: experimental_member_use

import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Database onValueCreated - triggers when data is created
    firebase.database.onValueCreated(ref: 'messages/{messageId}', (
      event,
    ) async {
      final data = event.data?.val();
      print('Database value created: messages/${event.params['messageId']}');
      print('  Data: $data');
      print('  Instance: ${event.instance}');
      print('  Ref: ${event.ref}');
    });

    // Database onValueUpdated - triggers when data is updated
    firebase.database.onValueUpdated(ref: 'messages/{messageId}', (
      event,
    ) async {
      final before = event.data?.before?.val();
      final after = event.data?.after?.val();
      print('Database value updated: messages/${event.params['messageId']}');
      print('  Before: $before');
      print('  After: $after');
    });

    // Database onValueDeleted - triggers when data is deleted
    firebase.database.onValueDeleted(ref: 'messages/{messageId}', (
      event,
    ) async {
      final data = event.data?.val();
      print('Database value deleted: messages/${event.params['messageId']}');
      print('  Final data: $data');
    });

    // Database onValueWritten - triggers on any write (create, update, delete)
    firebase.database.onValueWritten(ref: 'messages/{messageId}', (
      event,
    ) async {
      final before = event.data?.before;
      final after = event.data?.after;
      print('Database value written: messages/${event.params['messageId']}');
      if (before == null || !before.exists()) {
        print('  Operation: CREATE');
        print('  New data: ${after?.val()}');
      } else if (after == null || !after.exists()) {
        print('  Operation: DELETE');
        print('  Deleted data: ${before.val()}');
      } else {
        print('  Operation: UPDATE');
        print('  Before: ${before.val()}');
        print('  After: ${after.val()}');
      }
    });

    // Nested path database trigger
    firebase.database.onValueWritten(ref: 'users/{userId}/status', (
      event,
    ) async {
      final after = event.data?.after?.val();
      print('User status changed: ${event.params['userId']}');
      print('  New status: $after');
    });
  });
}
