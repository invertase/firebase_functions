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

// ignore_for_file: experimental_member_use

import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Storage onObjectFinalized - triggers when an object is created/overwritten
    firebase.storage.onObjectFinalized(
      bucket: 'demo-test.firebasestorage.app',
      (event) async {
        final data = event.data;
        print('Object finalized in bucket: ${event.bucket}');
        print('  Name: ${data?.name}');
        print('  Content Type: ${data?.contentType}');
        print('  Size: ${data?.size}');
      },
    );

    // Storage onObjectArchived - triggers when an object is archived
    firebase.storage.onObjectArchived(bucket: 'demo-test.firebasestorage.app', (
      event,
    ) async {
      final data = event.data;
      print('Object archived in bucket: ${event.bucket}');
      print('  Name: ${data?.name}');
      print('  Storage Class: ${data?.storageClass}');
    });

    // Storage onObjectDeleted - triggers when an object is deleted
    firebase.storage.onObjectDeleted(bucket: 'demo-test.firebasestorage.app', (
      event,
    ) async {
      final data = event.data;
      print('Object deleted in bucket: ${event.bucket}');
      print('  Name: ${data?.name}');
    });

    // Storage onObjectMetadataUpdated - triggers when object metadata changes
    firebase.storage.onObjectMetadataUpdated(
      bucket: 'demo-test.firebasestorage.app',
      (event) async {
        final data = event.data;
        print('Object metadata updated in bucket: ${event.bucket}');
        print('  Name: ${data?.name}');
        print('  Metadata: ${data?.metadata}');
      },
    );
  });
}
