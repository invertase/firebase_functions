import 'package:firebase_functions/firebase_functions.dart';

// =============================================================================
// Parameterized Configuration Examples
// =============================================================================

// Define parameters - these are read from environment variables at runtime
// and can be configured at deploy time via .env files or CLI prompts.
final welcomeMessage = defineString(
  'WELCOME_MESSAGE',
  ParamOptions(
    defaultValue: 'Hello from Dart Functions!',
    label: 'Welcome Message',
    description: 'The greeting message returned by the helloWorld function',
  ),
);

final minInstances = defineInt(
  'MIN_INSTANCES',
  ParamOptions(
    defaultValue: 0,
    label: 'Minimum Instances',
    description: 'Minimum number of instances to keep warm',
  ),
);

final isProduction = defineBoolean(
  'IS_PRODUCTION',
  ParamOptions(
    defaultValue: false,
    description: 'Whether this is a production deployment',
  ),
);

void main(List<String> args) {
  fireUp(args, (firebase) {
    // HTTPS onRequest example - using parameterized configuration
    firebase.https.onRequest(
      name: 'helloWorld',
      // ignore: non_const_argument_for_const_parameter
      options: HttpsOptions(
        // Use parameters in options - evaluated at deploy time
        minInstances: DeployOption.param(minInstances),
      ),
      (request) async {
        // Access parameter value at runtime
        return Response.ok(welcomeMessage.value());
      },
    );

    // Conditional configuration based on boolean parameter
    firebase.https.onRequest(
      name: 'configuredEndpoint',
      // ignore: non_const_argument_for_const_parameter
      options: HttpsOptions(
        // Use thenElse for conditional configuration at deploy time
        // isProduction.thenElse(trueValue, falseValue) returns an expression
        memory: Memory.expression(isProduction.thenElse(2048, 512)),
      ),
      (request) async {
        // Access parameter value at runtime
        final env = isProduction.value() ? 'production' : 'development';
        return Response.ok('Running in $env mode');
      },
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

    // ==========================================================================
    // Realtime Database trigger examples
    // ==========================================================================

    // Database onValueCreated - triggers when data is created
    firebase.database.onValueCreated(
      ref: 'messages/{messageId}',
      (event) async {
        final data = event.data?.val();
        print('Database value created: messages/${event.params['messageId']}');
        print('  Data: $data');
        print('  Instance: ${event.instance}');
        print('  Ref: ${event.ref}');
      },
    );

    // Database onValueUpdated - triggers when data is updated
    firebase.database.onValueUpdated(
      ref: 'messages/{messageId}',
      (event) async {
        final before = event.data?.before?.val();
        final after = event.data?.after?.val();
        print('Database value updated: messages/${event.params['messageId']}');
        print('  Before: $before');
        print('  After: $after');
      },
    );

    // Database onValueDeleted - triggers when data is deleted
    firebase.database.onValueDeleted(
      ref: 'messages/{messageId}',
      (event) async {
        final data = event.data?.val();
        print('Database value deleted: messages/${event.params['messageId']}');
        print('  Final data: $data');
      },
    );

    // Database onValueWritten - triggers on any write (create, update, delete)
    firebase.database.onValueWritten(
      ref: 'messages/{messageId}',
      (event) async {
        final before = event.data?.before;
        final after = event.data?.after;
        print('Database value written: messages/${event.params['messageId']}');
        if (before == null || !before.exists()) {
          print('  Operation: CREATE');
          print('  New data: ${after?.val()}');
        } else if (after == null || !after.exists()) {
          print('  Operation: DELETE');
          print('  Deleted data: ${before.val()}');
        } else {
          print('  Operation: UPDATE');
          print('  Before: ${before.val()}');
          print('  After: ${after.val()}');
        }
      },
    );

    // Nested path database trigger
    firebase.database.onValueWritten(
      ref: 'users/{userId}/status',
      (event) async {
        final after = event.data?.after?.val();
        print('User status changed: ${event.params['userId']}');
        print('  New status: $after');
      },
    );

    print('Functions registered successfully!');
  });
}
