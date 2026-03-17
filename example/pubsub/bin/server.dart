// Copyright 2026, the Firebase project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT-style license that can be found in the LICENSE file.

import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Pub/Sub trigger - triggers when a message is published to a topic
    firebase.pubsub.onMessagePublished(topic: 'my-topic', (event) async {
      final message = event.data;
      print('Received Pub/Sub message:');
      print('  ID: ${message?.messageId}');
      print('  Published: ${message?.publishTime}');
      print('  Data: ${message?.textData}');
      print('  Attributes: ${message?.attributes}');
    });
  });
}
