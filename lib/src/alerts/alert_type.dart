/// Alert type definitions for Firebase Alerts.
library;

import 'app_distribution_payloads.dart';
import 'billing_payloads.dart';
import 'crashlytics_payloads.dart';
import 'performance_payloads.dart';

// Re-export all payload types
export 'app_distribution_payloads.dart';
export 'billing_payloads.dart';
export 'crashlytics_payloads.dart';
export 'performance_payloads.dart';

/// Base sealed class representing all alert types.
sealed class AlertType {
  const AlertType();

  /// The string value used in Firebase Alerts.
  String get value;

  /// The payload type associated with this alert.
  Type get payloadType;
}

// =============================================================================
// Crashlytics Alert Types
// =============================================================================

/// Base class for Crashlytics alert types.
sealed class CrashlyticsAlertType extends AlertType {
  const CrashlyticsAlertType();
}

/// Alert for new fatal issues in Crashlytics.
class CrashlyticsNewFatalIssue extends CrashlyticsAlertType {
  const CrashlyticsNewFatalIssue();

  @override
  String get value => 'crashlytics.newFatalIssue';

  @override
  Type get payloadType => NewFatalIssuePayload;
}

/// Alert for new non-fatal issues in Crashlytics.
class CrashlyticsNewNonfatalIssue extends CrashlyticsAlertType {
  const CrashlyticsNewNonfatalIssue();

  @override
  String get value => 'crashlytics.newNonfatalIssue';

  @override
  Type get payloadType => NewNonfatalIssuePayload;
}

/// Alert for regression issues in Crashlytics.
class CrashlyticsRegression extends CrashlyticsAlertType {
  const CrashlyticsRegression();

  @override
  String get value => 'crashlytics.regression';

  @override
  Type get payloadType => RegressionAlertPayload;
}

/// Alert for stability digest in Crashlytics.
class CrashlyticsStabilityDigest extends CrashlyticsAlertType {
  const CrashlyticsStabilityDigest();

  @override
  String get value => 'crashlytics.stabilityDigest';

  @override
  Type get payloadType => StabilityDigestPayload;
}

/// Alert for velocity issues in Crashlytics.
class CrashlyticsVelocity extends CrashlyticsAlertType {
  const CrashlyticsVelocity();

  @override
  String get value => 'crashlytics.velocity';

  @override
  Type get payloadType => VelocityAlertPayload;
}

/// Alert for new ANR (Application Not Responding) issues in Crashlytics.
class CrashlyticsNewAnrIssue extends CrashlyticsAlertType {
  const CrashlyticsNewAnrIssue();

  @override
  String get value => 'crashlytics.newAnrIssue';

  @override
  Type get payloadType => NewAnrIssuePayload;
}

// =============================================================================
// Billing Alert Types
// =============================================================================

/// Base class for Billing alert types.
sealed class BillingAlertType extends AlertType {
  const BillingAlertType();
}

/// Alert for billing plan updates.
class BillingPlanUpdate extends BillingAlertType {
  const BillingPlanUpdate();

  @override
  String get value => 'billing.planUpdate';

  @override
  Type get payloadType => PlanUpdatePayload;
}

/// Alert for automated billing plan updates.
class BillingPlanAutomatedUpdate extends BillingAlertType {
  const BillingPlanAutomatedUpdate();

  @override
  String get value => 'billing.planAutomatedUpdate';

  @override
  Type get payloadType => PlanAutomatedUpdatePayload;
}

// =============================================================================
// App Distribution Alert Types
// =============================================================================

/// Base class for App Distribution alert types.
sealed class AppDistributionAlertType extends AlertType {
  const AppDistributionAlertType();
}

/// Alert for new tester iOS device in App Distribution.
class AppDistributionNewTesterIosDevice extends AppDistributionAlertType {
  const AppDistributionNewTesterIosDevice();

  @override
  String get value => 'appDistribution.newTesterIosDevice';

  @override
  Type get payloadType => NewTesterDevicePayload;
}

/// Alert for in-app feedback in App Distribution.
class AppDistributionInAppFeedback extends AppDistributionAlertType {
  const AppDistributionInAppFeedback();

  @override
  String get value => 'appDistribution.inAppFeedback';

  @override
  Type get payloadType => InAppFeedbackPayload;
}

// =============================================================================
// Performance Alert Types
// =============================================================================

/// Base class for Performance alert types.
sealed class PerformanceAlertType extends AlertType {
  const PerformanceAlertType();
}

/// Alert for performance threshold violations.
class PerformanceThreshold extends PerformanceAlertType {
  const PerformanceThreshold();

  @override
  String get value => 'performance.threshold';

  @override
  Type get payloadType => ThresholdAlertPayload;
}
