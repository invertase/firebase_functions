import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Storage onObjectFinalized - triggers when an object is created/overwritten
    firebase.storage.onObjectFinalized(
      bucket: 'demo-test.firebasestorage.app',
      (event) async {
        final data = event.data;
        print('Object finalized in bucket: ${event.bucket}');
        print('  Name: ${data?.name}');
        print('  Content Type: ${data?.contentType}');
        print('  Size: ${data?.size}');
      },
    );

    // Storage onObjectArchived - triggers when an object is archived
    firebase.storage.onObjectArchived(bucket: 'demo-test.firebasestorage.app', (
      event,
    ) async {
      final data = event.data;
      print('Object archived in bucket: ${event.bucket}');
      print('  Name: ${data?.name}');
      print('  Storage Class: ${data?.storageClass}');
    });

    // Storage onObjectDeleted - triggers when an object is deleted
    firebase.storage.onObjectDeleted(bucket: 'demo-test.firebasestorage.app', (
      event,
    ) async {
      final data = event.data;
      print('Object deleted in bucket: ${event.bucket}');
      print('  Name: ${data?.name}');
    });

    // Storage onObjectMetadataUpdated - triggers when object metadata changes
    firebase.storage.onObjectMetadataUpdated(
      bucket: 'demo-test.firebasestorage.app',
      (event) async {
        final data = event.data;
        print('Object metadata updated in bucket: ${event.bucket}');
        print('  Name: ${data?.name}');
        print('  Metadata: ${data?.metadata}');
      },
    );
  });
}
