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
    Map<String, dynamic> Function(CallableRequest<Object?>)? contextProvider,
  }) {
    // ignore: non_const_argument_for_const_parameter
    onCall(name: name, options: options, (request, response) async {
      if (request.acceptsStreaming) {
        final actionStream = flow.stream(
          request.data,
          context: contextProvider?.call(request),
        );
        actionStream.forEach((chunk) => response.sendChunk(chunk));
        return CallableResult(actionStream.result);
      } else {
        return CallableResult(
          await flow.run(request.data, context: contextProvider?.call(request)),
        );
      }
    });
  }
}
