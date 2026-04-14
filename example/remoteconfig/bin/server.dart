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
    // Remote Config update trigger
    firebase.remoteConfig.onConfigUpdated((event) async {
      final data = event.data;
      print('Remote Config updated:');
      print('  Version: ${data?.versionNumber}');
      print('  Description: ${data?.description}');
      print('  Update Origin: ${data?.updateOrigin.value}');
      print('  Update Type: ${data?.updateType.value}');
      print('  Updated By: ${data?.updateUser.email}');
    });
  });
}
