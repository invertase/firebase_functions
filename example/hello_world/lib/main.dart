import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // 1. Simplest possible function — returns "Hello, World!"
    firebase.https.onRequest(
      name: 'helloWorld',
      (request) async => Response.ok('Hello, World!'),
    );

    // 2. Callable function — takes { "name": "Alice" }, returns a greeting
    firebase.https.onCall(name: 'greet', (request, response) async {
      final data = request.data as Map<String, dynamic>?;
      final name = data?['name'] ?? 'World';
      return CallableResult({'message': 'Hello, $name!'});
    });

    // 3. Authenticated callable — returns user info or throws if unauthenticated
    firebase.https.onCall(name: 'whoAmI', (request, response) async {
      final auth = request.auth;
      if (auth == null) {
        throw UnauthenticatedError('You must be signed in to call this function');
      }

      return CallableResult({
        'uid': auth.uid,
        'token': auth.token,
      });
    });
  });
}
