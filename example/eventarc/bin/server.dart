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
    // Basic Eventarc custom event - uses default Firebase channel
    firebase.eventarc.onCustomEventPublished(eventType: 'com.example.myevent', (
      event,
    ) async {
      print('Received custom Eventarc event:');
      print('  Type: ${event.type}');
      print('  Source: ${event.source}');
      print('  Data: ${event.data}');
    });

    // Eventarc custom event with channel and filters
    firebase.eventarc.onCustomEventPublished(
      eventType: 'com.example.filtered',
      options: const EventarcTriggerOptions(
        channel: 'my-channel',
        filters: {'category': 'important'},
      ),
      (event) async {
        print('Received filtered Eventarc event:');
        print('  Type: ${event.type}');
        print('  Data: ${event.data}');
      },
    );
  });
}
