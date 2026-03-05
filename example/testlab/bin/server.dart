import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Test Lab onTestMatrixCompleted - triggers when a test matrix completes
    firebase.testLab.onTestMatrixCompleted((event) async {
      final data = event.data;
      print('Test matrix completed:');
      print('  Matrix ID: ${data?.testMatrixId}');
      print('  State: ${data?.state.value}');
      print('  Outcome: ${data?.outcomeSummary.value}');
      print('  Client: ${data?.clientInfo.client}');
      print('  Results URI: ${data?.resultStorage.resultsUri}');
    });
  });
}
