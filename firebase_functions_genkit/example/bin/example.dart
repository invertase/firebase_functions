import 'package:firebase_functions/firebase_functions.dart';
import 'package:firebase_functions_genkit/firebase_functions_genkit.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

const name = 'jokeTeller';

void main(List<String> args) {
  final gemini = googleAI();
  final ai = Genkit(plugins: [gemini]);
  final flow = ai.defineFlow(
    name: name,
    inputSchema: stringSchema(),
    outputSchema: stringSchema(),
    streamSchema: stringSchema(),
    fn: (jokeType, context) async {
      final prompt = 'Tell me a $jokeType joke.';
      final stream = ai.generateStream(
        model: gemini.model('gemini-2.5-flash'),
        prompt: prompt,
      );
      await stream.forEach((chunk) => context.sendChunk(chunk.text));
      return stream.result.text;
    },
  );

  fireUp(args, (firebase) {
    firebase.https.onCallGenkit(
      name: name,
      flow: flow,
      contextProvider: (context) => {'auth': context.auth?.token?['email']},
    );
  });
}
