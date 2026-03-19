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
