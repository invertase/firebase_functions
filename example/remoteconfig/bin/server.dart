// Copyright 2026, the Firebase project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT-style license that can be found in the LICENSE file.

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
