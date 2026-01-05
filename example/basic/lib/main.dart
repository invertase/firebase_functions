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
        print('  ID: ${message?.messageId}');
        print('  Published: ${message?.publishTime}');
        print('  Data: ${message?.textData}');
        print('  Attributes: ${message?.attributes}');
      },
    );

    // Firestore trigger examples
    firebase.firestore.onDocumentCreated(
      document: 'users/{userId}',
      (event) async {
        final data = event.data?.data();
        print('Document created: users/${event.params['userId']}');
        print('  Name: ${data?['name']}');
        print('  Email: ${data?['email']}');
      },
    );

    firebase.firestore.onDocumentUpdated(
      document: 'users/{userId}',
      (event) async {
        final before = event.data?.before?.data();
        final after = event.data?.after?.data();
        print('Document updated: users/${event.params['userId']}');
        print('  Before: $before');
        print('  After: $after');
      },
    );

    firebase.firestore.onDocumentDeleted(
      document: 'users/{userId}',
      (event) async {
        final data = event.data?.data();
        print('Document deleted: users/${event.params['userId']}');
        print('  Final data: $data');
      },
    );

    firebase.firestore.onDocumentWritten(
      document: 'users/{userId}',
      (event) async {
        final before = event.data?.before?.data();
        final after = event.data?.after?.data();
        print('Document written: users/${event.params['userId']}');
        if (before == null && after != null) {
          print('  Operation: CREATE');
        } else if (before != null && after != null) {
          print('  Operation: UPDATE');
        } else if (before != null && after == null) {
          print('  Operation: DELETE');
        }
      },
    );

    // Nested collection trigger example
    firebase.firestore.onDocumentCreated(
      document: 'posts/{postId}/comments/{commentId}',
      (event) async {
        final data = event.data?.data();
        print(
          'Comment created: posts/${event.params['postId']}/comments/${event.params['commentId']}',
        );
        print('  Text: ${data?['text']}');
        print('  Author: ${data?['author']}');
      },
    );

    print('Functions registered successfully!');
  });
}
