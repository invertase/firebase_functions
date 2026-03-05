import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Crashlytics new fatal issue alert
    firebase.alerts.crashlytics.onNewFatalIssuePublished((event) async {
      final issue = event.data?.payload.issue;
      print('New fatal issue in Crashlytics:');
      print('  Issue ID: ${issue?.id}');
      print('  Title: ${issue?.title}');
      print('  App Version: ${issue?.appVersion}');
      print('  App ID: ${event.appId}');
    });

    // Billing plan update alert
    firebase.alerts.billing.onPlanUpdatePublished((event) async {
      final payload = event.data?.payload;
      print('Billing plan updated:');
      print('  New Plan: ${payload?.billingPlan}');
      print('  Updated By: ${payload?.principalEmail}');
      print('  Type: ${payload?.notificationType}');
    });

    // Performance threshold alert with app ID filter
    firebase.alerts.performance.onThresholdAlertPublished(
      options: const AlertOptions(appId: '1:123456789:ios:abcdef'),
      (event) async {
        final payload = event.data?.payload;
        print('Performance threshold exceeded:');
        print('  Event: ${payload?.eventName}');
        print('  Metric: ${payload?.metricType}');
        print(
          '  Threshold: ${payload?.thresholdValue} ${payload?.thresholdUnit}',
        );
        print('  Actual: ${payload?.violationValue} ${payload?.violationUnit}');
      },
    );
  });
}
