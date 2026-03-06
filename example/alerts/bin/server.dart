import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // App Distribution new tester iOS device alert
    firebase.alerts.appDistribution.onNewTesterIosDevicePublished((
      event,
    ) async {
      final payload = event.data?.payload;
      print('New tester iOS device:');
      print('  Tester: ${payload?.testerName} (${payload?.testerEmail})');
      print('  Device: ${payload?.testerDeviceModelName}');
      print('  Identifier: ${payload?.testerDeviceIdentifier}');
    });

    // Crashlytics new fatal issue alert
    firebase.alerts.crashlytics.onNewFatalIssuePublished((event) async {
      final issue = event.data?.payload.issue;
      print('New fatal issue in Crashlytics:');
      print('  Issue ID: ${issue?.id}');
      print('  Title: ${issue?.title}');
      print('  App Version: ${issue?.appVersion}');
      print('  App ID: ${event.appId}');
    });

    // Crashlytics new ANR issue alert
    firebase.alerts.crashlytics.onNewAnrIssuePublished((event) async {
      final issue = event.data?.payload.issue;
      print('New ANR issue in Crashlytics:');
      print('  Issue ID: ${issue?.id}');
      print('  Title: ${issue?.title}');
      print('  App ID: ${event.appId}');
    });

    // Crashlytics new non-fatal issue alert
    firebase.alerts.crashlytics.onNewNonfatalIssuePublished((event) async {
      final issue = event.data?.payload.issue;
      print('New non-fatal issue in Crashlytics:');
      print('  Issue ID: ${issue?.id}');
      print('  Title: ${issue?.title}');
      print('  App ID: ${event.appId}');
    });

    // Crashlytics stability digest alert
    firebase.alerts.crashlytics.onStabilityDigestPublished((event) async {
      final payload = event.data?.payload;
      print('Stability digest: ${payload?.digestDate}');
      print('Trending issues: ${payload?.trendingIssues.length ?? 0}');
    });

    // Crashlytics velocity alert
    firebase.alerts.crashlytics.onVelocityAlertPublished((event) async {
      final payload = event.data?.payload;
      print('Crashlytics velocity alert:');
      print('  Issue: ${payload?.issue.title}');
      print('  Crash count: ${payload?.crashCount}');
      print('  Percentage: ${payload?.crashPercentage}%');
      print('  First version: ${payload?.firstVersion}');
    });

    // Billing plan update alert
    firebase.alerts.billing.onPlanUpdatePublished((event) async {
      final payload = event.data?.payload;
      print('Billing plan updated:');
      print('  New Plan: ${payload?.billingPlan}');
      print('  Updated By: ${payload?.principalEmail}');
      print('  Type: ${payload?.notificationType}');
    });

    // Billing automated plan update alert
    firebase.alerts.billing.onPlanAutomatedUpdatePublished((event) async {
      final payload = event.data?.payload;
      print('Billing automated plan update:');
      print('  Plan: ${payload?.billingPlan}');
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

    // App Distribution in-app feedback alert
    firebase.alerts.appDistribution.onInAppFeedbackPublished((event) async {
      final payload = event.data?.payload;
      print('In-app feedback:');
      print('  Tester: ${payload?.testerEmail}');
      print('  App version: ${payload?.appVersion}');
      print('  Text: ${payload?.text}');
      print('  Console: ${payload?.feedbackConsoleUri}');
    });
  });
}
