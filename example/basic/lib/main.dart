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

    print('Functions registered successfully!');
  });
}
