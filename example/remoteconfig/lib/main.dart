import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Remote Config update trigger
    firebase.remoteConfig.onConfigUpdated((event) async {
      final data = event.data;
      print('Remote Config updated:');
      print('  Version: ${data?.versionNumber}');
      print('  Description: ${data?.description}');
      print('  Update Origin: ${data?.updateOrigin.value}');
      print('  Update Type: ${data?.updateType.value}');
      print('  Updated By: ${data?.updateUser.email}');
    });
  });
}
