import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    // Test Firestore onDocumentCreated with wildcard
    firebase.firestore.onDocumentCreated(
      document: 'users/{userId}',
      (event) async {
        print('User created: ${event.document}');
        print('Params: ${event.params}');
        final snapshot = event.data;
        print('User ID: ${snapshot.id}');
        print('User data: ${snapshot.data()}');
        print('User exists: ${snapshot.exists}');
      },
    );

    // Test Firestore onDocumentCreated with literal path
    firebase.firestore.onDocumentCreated(
      document: 'config/settings',
      (event) async {
        print('Settings document created');
      },
    );

    // Test with nested collection path
    firebase.firestore.onDocumentCreated(
      document: 'posts/{postId}/comments/{commentId}',
      (event) async {
        print('Comment created in post: ${event.params}');
      },
    );
  });
}
