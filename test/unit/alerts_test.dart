import 'package:firebase_functions/firebase_functions.dart';
import 'package:test/test.dart';

void main() {
  group('AlertType', () {
    group('CrashlyticsAlertType', () {
      test('CrashlyticsNewFatalIssue has correct value', () {
        const alertType = CrashlyticsNewFatalIssue();
        expect(alertType.value, 'crashlytics.newFatalIssue');
        expect(alertType.payloadType, NewFatalIssuePayload);
      });

      test('CrashlyticsNewNonfatalIssue has correct value', () {
        const alertType = CrashlyticsNewNonfatalIssue();
        expect(alertType.value, 'crashlytics.newNonfatalIssue');
        expect(alertType.payloadType, NewNonfatalIssuePayload);
      });

      test('CrashlyticsRegression has correct value', () {
        const alertType = CrashlyticsRegression();
        expect(alertType.value, 'crashlytics.regression');
        expect(alertType.payloadType, RegressionAlertPayload);
      });

      test('CrashlyticsStabilityDigest has correct value', () {
        const alertType = CrashlyticsStabilityDigest();
        expect(alertType.value, 'crashlytics.stabilityDigest');
        expect(alertType.payloadType, StabilityDigestPayload);
      });

      test('CrashlyticsVelocity has correct value', () {
        const alertType = CrashlyticsVelocity();
        expect(alertType.value, 'crashlytics.velocity');
        expect(alertType.payloadType, VelocityAlertPayload);
      });

      test('CrashlyticsNewAnrIssue has correct value', () {
        const alertType = CrashlyticsNewAnrIssue();
        expect(alertType.value, 'crashlytics.newAnrIssue');
        expect(alertType.payloadType, NewAnrIssuePayload);
      });
    });

    group('BillingAlertType', () {
      test('BillingPlanUpdate has correct value', () {
        const alertType = BillingPlanUpdate();
        expect(alertType.value, 'billing.planUpdate');
        expect(alertType.payloadType, PlanUpdatePayload);
      });

      test('BillingPlanAutomatedUpdate has correct value', () {
        const alertType = BillingPlanAutomatedUpdate();
        expect(alertType.value, 'billing.planAutomatedUpdate');
        expect(alertType.payloadType, PlanAutomatedUpdatePayload);
      });
    });

    group('AppDistributionAlertType', () {
      test('AppDistributionNewTesterIosDevice has correct value', () {
        const alertType = AppDistributionNewTesterIosDevice();
        expect(alertType.value, 'appDistribution.newTesterIosDevice');
        expect(alertType.payloadType, NewTesterDevicePayload);
      });

      test('AppDistributionInAppFeedback has correct value', () {
        const alertType = AppDistributionInAppFeedback();
        expect(alertType.value, 'appDistribution.inAppFeedback');
        expect(alertType.payloadType, InAppFeedbackPayload);
      });
    });

    group('PerformanceAlertType', () {
      test('PerformanceThreshold has correct value', () {
        const alertType = PerformanceThreshold();
        expect(alertType.value, 'performance.threshold');
        expect(alertType.payloadType, ThresholdAlertPayload);
      });
    });
  });

  group('Crashlytics Payloads', () {
    test('Issue.fromJson parses correctly', () {
      final json = {
        'id': 'issue-123',
        'title': 'Crash in main()',
        'subtitle': 'NullPointerException',
        'appVersion': '1.0.0',
      };

      final issue = Issue.fromJson(json);

      expect(issue.id, 'issue-123');
      expect(issue.title, 'Crash in main()');
      expect(issue.subtitle, 'NullPointerException');
      expect(issue.appVersion, '1.0.0');
    });

    test('Issue.toJson round-trips correctly', () {
      const issue = Issue(
        id: 'issue-456',
        title: 'Test Issue',
        subtitle: 'Test Subtitle',
        appVersion: '2.0.0',
      );

      final json = issue.toJson();
      final parsed = Issue.fromJson(json);

      expect(parsed.id, issue.id);
      expect(parsed.title, issue.title);
      expect(parsed.subtitle, issue.subtitle);
      expect(parsed.appVersion, issue.appVersion);
    });

    test('NewFatalIssuePayload.fromJson parses correctly', () {
      final json = {
        'issue': {
          'id': 'fatal-123',
          'title': 'Fatal Crash',
          'subtitle': 'Fatal error',
          'appVersion': '1.0.0',
        },
      };

      final payload = NewFatalIssuePayload.fromJson(json);

      expect(payload.issue.id, 'fatal-123');
      expect(payload.issue.title, 'Fatal Crash');
    });

    test('RegressionAlertPayload.fromJson parses correctly', () {
      final json = {
        'type': 'fatal',
        'issue': {
          'id': 'regression-123',
          'title': 'Regression',
          'subtitle': 'Issue regressed',
          'appVersion': '1.1.0',
        },
        'resolveTime': '2024-01-01T12:00:00Z',
      };

      final payload = RegressionAlertPayload.fromJson(json);

      expect(payload.type, 'fatal');
      expect(payload.issue.id, 'regression-123');
      expect(payload.resolveTime, DateTime.utc(2024, 1, 1, 12));
    });

    test('StabilityDigestPayload.fromJson parses correctly', () {
      final json = {
        'digestDate': '2024-01-15T00:00:00Z',
        'trendingIssues': [
          {
            'type': 'fatal',
            'issue': {
              'id': 'trending-1',
              'title': 'Trending Issue',
              'subtitle': 'Subtitle',
              'appVersion': '1.0.0',
            },
            'eventCount': 100,
            'userCount': 50,
          },
        ],
      };

      final payload = StabilityDigestPayload.fromJson(json);

      expect(payload.digestDate, DateTime.utc(2024, 1, 15));
      expect(payload.trendingIssues.length, 1);
      expect(payload.trendingIssues.first.eventCount, 100);
      expect(payload.trendingIssues.first.userCount, 50);
    });

    test('VelocityAlertPayload.fromJson parses correctly', () {
      final json = {
        'issue': {
          'id': 'velocity-123',
          'title': 'Velocity Alert',
          'subtitle': 'High crash rate',
          'appVersion': '1.0.0',
        },
        'createTime': '2024-01-01T12:00:00Z',
        'crashCount': 500,
        'crashPercentage': 15.5,
        'firstVersion': '0.9.0',
      };

      final payload = VelocityAlertPayload.fromJson(json);

      expect(payload.issue.id, 'velocity-123');
      expect(payload.crashCount, 500);
      expect(payload.crashPercentage, 15.5);
      expect(payload.firstVersion, '0.9.0');
    });
  });

  group('Billing Payloads', () {
    test('PlanUpdatePayload.fromJson parses correctly', () {
      final json = {
        'billingPlan': 'Blaze',
        'principalEmail': 'user@example.com',
        'notificationType': 'upgrade',
      };

      final payload = PlanUpdatePayload.fromJson(json);

      expect(payload.billingPlan, 'Blaze');
      expect(payload.principalEmail, 'user@example.com');
      expect(payload.notificationType, 'upgrade');
    });

    test('PlanAutomatedUpdatePayload.fromJson parses correctly', () {
      final json = {
        'billingPlan': 'Spark',
        'notificationType': 'downgrade',
      };

      final payload = PlanAutomatedUpdatePayload.fromJson(json);

      expect(payload.billingPlan, 'Spark');
      expect(payload.notificationType, 'downgrade');
    });
  });

  group('App Distribution Payloads', () {
    test('NewTesterDevicePayload.fromJson parses correctly', () {
      final json = {
        'testerName': 'John Doe',
        'testerEmail': 'john@example.com',
        'testerDeviceModelName': 'iPhone 15 Pro',
        'testerDeviceIdentifier': 'ABCD1234',
      };

      final payload = NewTesterDevicePayload.fromJson(json);

      expect(payload.testerName, 'John Doe');
      expect(payload.testerEmail, 'john@example.com');
      expect(payload.testerDeviceModelName, 'iPhone 15 Pro');
      expect(payload.testerDeviceIdentifier, 'ABCD1234');
    });

    test('InAppFeedbackPayload.fromJson parses correctly', () {
      final json = {
        'feedbackReport':
            'projects/123/apps/456/releases/789/feedbackReports/abc',
        'feedbackConsoleUri': 'https://console.firebase.google.com/feedback',
        'testerName': 'Jane Doe',
        'testerEmail': 'jane@example.com',
        'appVersion': '1.2.3 (45)',
        'text': 'Great app but needs dark mode!',
        'screenshotUri': 'https://storage.googleapis.com/screenshot.png',
      };

      final payload = InAppFeedbackPayload.fromJson(json);

      expect(payload.feedbackReport, contains('feedbackReports'));
      expect(payload.testerName, 'Jane Doe');
      expect(payload.text, 'Great app but needs dark mode!');
      expect(payload.screenshotUri, isNotNull);
    });

    test('InAppFeedbackPayload handles optional fields', () {
      final json = {
        'feedbackReport':
            'projects/123/apps/456/releases/789/feedbackReports/abc',
        'feedbackConsoleUri': 'https://console.firebase.google.com/feedback',
        'testerEmail': 'jane@example.com',
        'appVersion': '1.2.3',
        'text': 'Feedback without screenshot',
      };

      final payload = InAppFeedbackPayload.fromJson(json);

      expect(payload.testerName, isNull);
      expect(payload.screenshotUri, isNull);
    });
  });

  group('Performance Payloads', () {
    test('ThresholdAlertPayload.fromJson parses correctly', () {
      final json = {
        'eventName': 'my_custom_trace',
        'eventType': 'trace',
        'metricType': 'duration',
        'numSamples': 1000,
        'thresholdValue': 2.5,
        'thresholdUnit': 'seconds',
        'conditionPercentile': 95,
        'appVersion': '1.0.0',
        'violationValue': 3.2,
        'violationUnit': 'seconds',
        'investigateUri': 'https://console.firebase.google.com/perf',
      };

      final payload = ThresholdAlertPayload.fromJson(json);

      expect(payload.eventName, 'my_custom_trace');
      expect(payload.eventType, 'trace');
      expect(payload.metricType, 'duration');
      expect(payload.numSamples, 1000);
      expect(payload.thresholdValue, 2.5);
      expect(payload.conditionPercentile, 95);
      expect(payload.appVersion, '1.0.0');
      expect(payload.violationValue, 3.2);
    });

    test('ThresholdAlertPayload omits conditionPercentile when 0', () {
      final json = {
        'eventName': 'network_request',
        'eventType': 'network',
        'metricType': 'success_rate',
        'numSamples': 500,
        'thresholdValue': 95.0,
        'thresholdUnit': 'percent',
        'conditionPercentile': 0, // Should be omitted
        'appVersion': '', // Should be omitted
        'violationValue': 90.0,
        'violationUnit': 'percent',
        'investigateUri': 'https://console.firebase.google.com/perf',
      };

      final payload = ThresholdAlertPayload.fromJson(json);

      expect(payload.conditionPercentile, isNull);
      expect(payload.appVersion, isNull);
    });
  });

  group('AlertData', () {
    test('fromJson parses correctly', () {
      final json = {
        'createTime': '2024-01-01T12:00:00Z',
        'endTime': '2024-01-01T13:00:00Z',
        'payload': {
          'billingPlan': 'Blaze',
          'principalEmail': 'user@example.com',
          'notificationType': 'upgrade',
        },
      };

      final alertData = AlertData<PlanUpdatePayload>.fromJson(
        json,
        PlanUpdatePayload.fromJson,
      );

      expect(alertData.createTime, DateTime.utc(2024, 1, 1, 12));
      expect(alertData.endTime, DateTime.utc(2024, 1, 1, 13));
      expect(alertData.payload.billingPlan, 'Blaze');
    });

    test('fromJson handles missing endTime', () {
      final json = {
        'createTime': '2024-01-01T12:00:00Z',
        'payload': {
          'billingPlan': 'Spark',
          'principalEmail': 'user@example.com',
          'notificationType': 'downgrade',
        },
      };

      final alertData = AlertData<PlanUpdatePayload>.fromJson(
        json,
        PlanUpdatePayload.fromJson,
      );

      expect(alertData.createTime, DateTime.utc(2024, 1, 1, 12));
      expect(alertData.endTime, isNull);
    });
  });

  group('AlertEvent', () {
    test('fromJson parses correctly', () {
      final json = {
        'specversion': '1.0',
        'id': 'event-123',
        'source': '//firebasealerts.googleapis.com/projects/my-project',
        'type': 'google.firebase.firebasealerts.alerts.v1.published',
        'time': '2024-01-01T12:00:00Z',
        'alerttype': 'billing.planUpdate',
        'data': {
          'createTime': '2024-01-01T12:00:00Z',
          'payload': {
            'billingPlan': 'Blaze',
            'principalEmail': 'user@example.com',
            'notificationType': 'upgrade',
          },
        },
      };

      final event = AlertEvent<PlanUpdatePayload>.fromJson(
        json,
        PlanUpdatePayload.fromJson,
      );

      expect(event.specversion, '1.0');
      expect(event.id, 'event-123');
      expect(event.alertType, 'billing.planUpdate');
      expect(event.appId, isNull);
      expect(event.data!.payload.billingPlan, 'Blaze');
    });

    test('fromJson parses appid correctly', () {
      final json = {
        'specversion': '1.0',
        'id': 'event-456',
        'source': '//firebasealerts.googleapis.com/projects/my-project',
        'type': 'google.firebase.firebasealerts.alerts.v1.published',
        'time': '2024-01-01T12:00:00Z',
        'alerttype': 'crashlytics.newFatalIssue',
        'appid': '1:123456789:ios:abcdef',
        'data': {
          'createTime': '2024-01-01T12:00:00Z',
          'payload': {
            'issue': {
              'id': 'issue-123',
              'title': 'Crash',
              'subtitle': 'Error',
              'appVersion': '1.0.0',
            },
          },
        },
      };

      final event = AlertEvent<NewFatalIssuePayload>.fromJson(
        json,
        NewFatalIssuePayload.fromJson,
      );

      expect(event.alertType, 'crashlytics.newFatalIssue');
      expect(event.appId, '1:123456789:ios:abcdef');
    });

    test('handles camelCase alertType and appId', () {
      final json = {
        'specversion': '1.0',
        'id': 'event-789',
        'source': '//firebasealerts.googleapis.com/projects/my-project',
        'type': 'google.firebase.firebasealerts.alerts.v1.published',
        'time': '2024-01-01T12:00:00Z',
        'alertType': 'performance.threshold', // camelCase
        'appId': 'app-id-123', // camelCase
        'data': {
          'createTime': '2024-01-01T12:00:00Z',
          'payload': {
            'eventName': 'trace',
            'eventType': 'custom',
            'metricType': 'duration',
            'numSamples': 100,
            'thresholdValue': 1.0,
            'thresholdUnit': 'seconds',
            'violationValue': 2.0,
            'violationUnit': 'seconds',
            'investigateUri': 'https://console.firebase.google.com',
          },
        },
      };

      final event = AlertEvent<ThresholdAlertPayload>.fromJson(
        json,
        ThresholdAlertPayload.fromJson,
      );

      expect(event.alertType, 'performance.threshold');
      expect(event.appId, 'app-id-123');
    });
  });

  group('alertEventType constant', () {
    test('has correct value', () {
      expect(
        alertEventType,
        'google.firebase.firebasealerts.alerts.v1.published',
      );
    });
  });

  group('AlertOptions', () {
    test('can be created with appId', () {
      const options = AlertOptions(appId: '1:123:ios:abc');
      expect(options.appId, '1:123:ios:abc');
    });

    test('can be created with GlobalOptions', () {
      const options = AlertOptions(
        appId: 'app-123',
        region: DeployOption(SupportedRegion.usCentral1),
        memory: Memory(MemoryOption.mb512),
        timeoutSeconds: DeployOption(60),
      );

      expect(options.appId, 'app-123');
      expect(options.region, isNotNull);
      expect(options.memory, isNotNull);
      expect(options.timeoutSeconds, isNotNull);
    });
  });
}
