import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) {
  fireUp(args, (firebase) {
    // Test Firestore onDocumentCreated with wildcard
    firebase.firestore.onDocumentCreated(
      document: 'users/{userId}',
      (event) async {
        print('=== USER HANDLER CALLED ===');
        print('User created: ${event.document}');
        print('Params: ${event.params}');
        print('Event ID: ${event.id}');
        print('Event time: ${event.time}');

        // Access document data (similar to Node.js)
        if (event.data != null) {
          final data = event.data!.data();
          print('Document data: $data');

          // Access specific fields
          if (data.containsKey('name')) {
            print('User name: ${data['name']}');
          }
          if (data.containsKey('email')) {
            print('User email: ${data['email']}');
          }
        }
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

    // Test onDocumentUpdated
    firebase.firestore.onDocumentUpdated(
      document: 'users/{userId}',
      (event) async {
        print('=== USER UPDATED HANDLER CALLED ===');
        print('User updated: ${event.document}');
        print('Params: ${event.params}');

        // Access before and after states
        if (event.data != null) {
          final before = event.data!.before;
          final after = event.data!.after;

          if (before != null && after != null) {
            print('Before: ${before.data()}');
            print('After: ${after.data()}');

            // Check what changed
            final beforeData = before.data();
            final afterData = after.data();

            if (beforeData['name'] != afterData['name']) {
              print(
                  'Name changed: ${beforeData['name']} -> ${afterData['name']}',);
            }
          }
        }
      },
    );

    // Test onDocumentDeleted
    firebase.firestore.onDocumentDeleted(
      document: 'users/{userId}',
      (event) async {
        print('=== USER DELETED HANDLER CALLED ===');
        print('User deleted: ${event.document}');
        print('User ID: ${event.params['userId']}');

        // Access the final state before deletion
        if (event.data != null) {
          final deletedData = event.data!.data();
          print('Deleted user data: $deletedData');
        }
      },
    );

    // Test onDocumentWritten (catches all operations)
    firebase.firestore.onDocumentWritten(
      document: 'users/{userId}',
      (event) async {
        print('=== USER WRITTEN HANDLER CALLED ===');
        print('User written: ${event.document}');

        if (event.data != null) {
          final before = event.data!.before;
          final after = event.data!.after;

          // Determine operation type
          if (before == null && after != null) {
            print('Operation: CREATE');
            print('New user data: ${after.data()}');
          } else if (before != null && after == null) {
            print('Operation: DELETE');
            print('Deleted user data: ${before.data()}');
          } else if (before != null && after != null) {
            print('Operation: UPDATE');
            print('Before: ${before.data()}');
            print('After: ${after.data()}');
          }
        }
      },
    );
  });
}
