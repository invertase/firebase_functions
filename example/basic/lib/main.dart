import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    // HTTPS onRequest example
    firebase.https.onRequest(
      name: 'helloWorld',
      (request) async => Response.ok('Hello from Dart Functions!'),
    );

    // HTTPS onCall example (untyped)
    firebase.https.onCall(
      name: 'greet',
      (request, response) async {
        final data = request.data as Map<String, dynamic>?;
        final name = data?['name'] as String? ?? 'World';
        return CallableResult({'message': 'Hello $name!'});
      },
    );

    // HTTPS onCall with streaming example
    firebase.https.onCall(
      name: 'streamNumbers',
      (request, response) async {
        // Stream numbers if client accepts streaming
        if (request.acceptsStreaming) {
          for (var i = 1; i <= 5; i++) {
            await response.sendChunk({'count': i});
            await Future<void>.delayed(Duration(milliseconds: 500));
          }
        }
        return CallableResult({'message': 'Done streaming'});
      },
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
