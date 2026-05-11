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
  await runFunctions((firebase) {
    // Basic scheduled function - runs every day at midnight
    firebase.scheduler.onSchedule(schedule: '0 0 * * *', (event) async {
      print('Scheduled function triggered:');
      print('  Job Name: ${event.jobName}');
      print('  Schedule Time: ${event.scheduleTime}');
    });

    // Scheduled function with timezone and retry config
    firebase.scheduler.onSchedule(
      schedule: '0 9 * * 1-5',
      options: const ScheduleOptions(
        timeZone: TimeZone('America/New_York'),
        retryConfig: RetryConfig(
          retryCount: RetryCount(3),
          maxRetrySeconds: MaxRetrySeconds(60),
          minBackoffSeconds: MinBackoffSeconds(5),
          maxBackoffSeconds: MaxBackoffSeconds(30),
        ),
        memory: Memory(MemoryOption.mb256),
      ),
      (event) async {
        print('Weekday morning report:');
        print('  Executed at: ${event.scheduleDateTime}');
      },
    );
  });
}
