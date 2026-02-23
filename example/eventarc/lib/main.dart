import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Basic Eventarc custom event - uses default Firebase channel
    firebase.eventarc.onCustomEventPublished(eventType: 'com.example.myevent', (
      event,
    ) async {
      print('Received custom Eventarc event:');
      print('  Type: ${event.type}');
      print('  Source: ${event.source}');
      print('  Data: ${event.data}');
    });

    // Eventarc custom event with channel and filters
    firebase.eventarc.onCustomEventPublished(
      eventType: 'com.example.filtered',
      options: const EventarcTriggerOptions(
        channel: 'my-channel',
        filters: {'category': 'important'},
      ),
      (event) async {
        print('Received filtered Eventarc event:');
        print('  Type: ${event.type}');
        print('  Data: ${event.data}');
      },
    );
  });
}
