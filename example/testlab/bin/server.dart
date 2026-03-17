// Copyright 2026, the Firebase project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT-style license that can be found in the LICENSE file.

import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Test Lab onTestMatrixCompleted - triggers when a test matrix completes
    firebase.testLab.onTestMatrixCompleted((event) async {
      final data = event.data;
      print('Test matrix completed:');
      print('  Matrix ID: ${data?.testMatrixId}');
      print('  State: ${data?.state.value}');
      print('  Outcome: ${data?.outcomeSummary.value}');
      print('  Client: ${data?.clientInfo.client}');
      print('  Results URI: ${data?.resultStorage.resultsUri}');
    });
  });
}
