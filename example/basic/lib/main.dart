import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    // HTTPS onRequest example
    firebase.https.onRequest(
      name: 'helloWorld',
      (request) async => Response.ok('Hello from Dart Functions!'),
    );

    // Pub/Sub trigger example
    firebase.pubsub.onMessagePublished(
      topic: 'my-topic',
      (event) async {
        final message = event.data;
        print('Received Pub/Sub message:');
        print('  ID: ${message.messageId}');
        print('  Published: ${message.publishTime}');
        print('  Data: ${message.textData}');
        print('  Attributes: ${message.attributes}');
      },
    );

    print('Functions registered successfully!');
  });
}
