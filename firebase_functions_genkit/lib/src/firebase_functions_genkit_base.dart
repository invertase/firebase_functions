import 'package:firebase_functions/firebase_functions.dart';
import 'package:firebase_functions/src/firebase.dart';
import 'package:genkit/client.dart' show ActionStream;
import 'package:genkit/src/core/flow.dart';
// ignore: experimental_member_use
import 'package:meta/meta.dart' show mustBeConst;

extension GenkitExt on HttpsNamespace {
  void onCallGenkit<Output extends Object, Schema, Init>(
    // Must repeat the name
    // ignore: experimental_member_use
    @mustBeConst String name,
    Flow<Object?, Output, Schema, Init> flow,
  ) {
    // ignore: non_const_argument_for_const_parameter
    onCall(name: name, (request, response) async {
      if (!request.acceptsStreaming) {
        return CallableResult(await flow.run(request.data));
      }

      final actionStream = flow.stream(request.data);
      actionStream.forEach((chunk) => response.sendChunk(chunk));
      return CallableResult(actionStream.result);
    });
  }
}
