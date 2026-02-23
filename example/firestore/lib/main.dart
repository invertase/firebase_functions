import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Firestore onDocumentCreated - triggers when a document is created
    firebase.firestore.onDocumentCreated(document: 'users/{userId}', (
      event,
    ) async {
      final data = event.data?.data();
      print('Document created: users/${event.params['userId']}');
      print('  Name: ${data?['name']}');
      print('  Email: ${data?['email']}');
    });

    // Firestore onDocumentUpdated - triggers when a document is updated
    firebase.firestore.onDocumentUpdated(document: 'users/{userId}', (
      event,
    ) async {
      final before = event.data?.before?.data();
      final after = event.data?.after?.data();
      print('Document updated: users/${event.params['userId']}');
      print('  Before: $before');
      print('  After: $after');
    });

    // Firestore onDocumentDeleted - triggers when a document is deleted
    firebase.firestore.onDocumentDeleted(document: 'users/{userId}', (
      event,
    ) async {
      final data = event.data?.data();
      print('Document deleted: users/${event.params['userId']}');
      print('  Final data: $data');
    });

    // Firestore onDocumentWritten - triggers on any write operation
    firebase.firestore.onDocumentWritten(document: 'users/{userId}', (
      event,
    ) async {
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
    });

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
  });
}
