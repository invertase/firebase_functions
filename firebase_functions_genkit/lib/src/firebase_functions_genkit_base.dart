import 'package:firebase_functions/firebase_functions.dart';
import 'package:genkit/genkit.dart';
// ignore: experimental_member_use
import 'package:meta/meta.dart' show mustBeConst;

extension GenkitExt on HttpsNamespace {
  void onCallGenkit<Output extends Object, Schema, Init>({
    // Must repeat the name
    // ignore: experimental_member_use
    @mustBeConst required String name,
    required Flow<Object?, Output, Schema, Init> flow,
    // ignore: experimental_member_use
    @mustBeConst CallableOptions? options = const CallableOptions(),
  }) {
    // ignore: non_const_argument_for_const_parameter
    onCall(name: name, options: options, (request, response) async {
      if (request.acceptsStreaming) {
        final actionStream = flow.stream(request.data);
        actionStream.forEach((chunk) => response.sendChunk(chunk));
        return CallableResult(actionStream.result);
      } else {
        return CallableResult(await flow.run(request.data));
      }
    });
  }
}
