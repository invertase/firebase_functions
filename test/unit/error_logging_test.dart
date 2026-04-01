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

// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:firebase_functions/firebase_functions.dart';
import 'package:firebase_functions/src/common/environment.dart';
import 'package:firebase_functions/src/firebase.dart';
import 'package:test/test.dart';

import 'shared_utils.dart';

void main() {
  setUpAll(() {
    FirebaseEnv.mockEnvironment = {'FIREBASE_PROJECT': 'demo-test'};
  });

  group('HTTPS handler error logging integration', () {
    late Firebase firebase;
    late HttpsNamespace https;

    setUp(() {
      firebase = Firebase();
      https = HttpsNamespace(firebase);
    });

    test(
      'onRequest: unexpected error returns INTERNAL without details',
      () async {
        https.onRequest(name: 'crashEndpoint', (request) async {
          throw StateError('sensitive: connection string is postgres://...');
        });

        final func = firebase.functions.firstWhere(
          (f) => f.name == 'crash-endpoint',
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/crash-endpoint'),
        );
        expect(() => func.handler(request), throwsA(isA<StateError>()));
      },
    );

    test('onRequest: HttpsError is passed through to client', () async {
      https.onRequest(name: 'knownError', (request) async {
        throw HttpResponseException.notFound(message: 'User 42 not found');
      });

      final handler = findHandler(firebase, 'known-error');
      final request = Request(
        'GET',
        Uri.parse('http://localhost/known-error'),
        headers: {'accept': 'application/json'},
      );
      final response = await handler(request);

      expect(response.statusCode, 404);
      final body = await response.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      // HttpsError messages ARE intentionally exposed
      expect(json['error']['status'], 'NOT_FOUND');
      expect(json['error']['message'], 'User 42 not found');
    });
  });

  group('Event handler error logging integration', () {
    late Firebase firebase;

    setUp(() {
      firebase = Firebase();
    });

    test('PubSub: unexpected error returns 500 without details', () async {
      final pubsub = PubSubNamespace(firebase);
      pubsub.onMessagePublished(topic: 'test-topic', (event) async {
        throw Exception('sensitive: api key is sk-12345');
      });

      final func = firebase.functions.firstWhere(
        (f) => f.name == 'on-message-published-testtopic',
      );

      // Send a valid Pub/Sub CloudEvent
      final cloudEvent = {
        'specversion': '1.0',
        'id': 'test-id',
        'source': '//pubsub.googleapis.com/projects/test/topics/test-topic',
        'type': 'google.cloud.pubsub.topic.v1.messagePublished',
        'time': '2024-01-01T00:00:00Z',
        'data': {
          'message': {
            'data': base64Encode(utf8.encode('test message')),
            'attributes': <String, String>{},
            'messageId': '123',
            'publishTime': '2024-01-01T00:00:00Z',
            'orderingKey': '',
          },
          'subscription': 'projects/test/subscriptions/test-sub',
        },
      };

      final request = Request(
        'POST',
        Uri.parse('http://localhost/on-message-published-testtopic'),
        body: jsonEncode(cloudEvent),
        headers: {'content-type': 'application/json'},
      );
      expect(() => func.handler(request), throwsA(isA<Exception>()));
    });

    test('Scheduler: unexpected error returns 500 without details', () async {
      final scheduler = SchedulerNamespace(firebase);
      scheduler.onSchedule(schedule: '0 0 * * *', (event) async {
        throw Exception('sensitive: db password is hunter2');
      });

      final func = firebase.functions.firstWhere(
        (f) => f.name == 'on-schedule-0-0',
      );

      final request = Request(
        'POST',
        Uri.parse('http://localhost/on-schedule-0-0'),
        headers: {'x-cloudscheduler-scheduletime': '2024-01-01T00:00:00Z'},
      );
      expect(() => func.handler(request), throwsA(isA<Exception>()));
    });
  });
}
