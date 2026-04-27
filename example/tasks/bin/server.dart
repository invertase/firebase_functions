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
    // Basic task queue function
    firebase.tasks.onTaskDispatched(name: 'processOrder', (request) async {
      final data = request.data as Map<String, dynamic>;
      print('Processing order: ${data['orderId']}');
      print('Task ID: ${request.id}');
      print('Queue: ${request.queueName}');
      print('Retry count: ${request.retryCount}');
    });

    // Task queue function with options
    firebase.tasks.onTaskDispatched(
      name: 'sendEmail',
      options: const TaskQueueOptions(
        retryConfig: TaskQueueRetryConfig(
          maxAttempts: MaxAttempts(5),
          maxRetrySeconds: TaskMaxRetrySeconds(300),
          minBackoffSeconds: TaskMinBackoffSeconds(10),
          maxBackoffSeconds: TaskMaxBackoffSeconds(60),
          maxDoublings: TaskMaxDoublings(3),
        ),
        rateLimits: TaskQueueRateLimits(
          maxConcurrentDispatches: MaxConcurrentDispatches(100),
          maxDispatchesPerSecond: MaxDispatchesPerSecond(50),
        ),
        memory: Memory(MemoryOption.mb512),
      ),
      (request) async {
        final data = request.data as Map<String, dynamic>;
        print('Sending email to: ${data['to']}');
        print('Subject: ${data['subject']}');
      },
    );
  });
}
