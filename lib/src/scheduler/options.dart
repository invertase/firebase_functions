import '../common/options.dart';

/// Options for scheduled functions.
///
/// Extends [GlobalOptions] with scheduler-specific configuration.
class ScheduleOptions extends GlobalOptions {
  /// Creates schedule options.
  const ScheduleOptions({
    this.timeZone,
    this.retryConfig,
    super.concurrency,
    super.cpu,
    super.ingressSettings,
    super.invoker,
    super.labels,
    super.minInstances,
    super.maxInstances,
    super.memory,
    super.omit,
    super.preserveExternalChanges,
    super.region,
    super.secrets,
    super.serviceAccount,
    super.timeoutSeconds,
    super.vpcConnector,
    super.vpcConnectorEgressSettings,
  });

  /// The timezone that the schedule executes in.
  ///
  /// If not specified, defaults to UTC.
  ///
  /// Example: `'America/New_York'`, `'Europe/London'`
  final TimeZone? timeZone;

  /// Retry configuration for failed function executions.
  final RetryConfig? retryConfig;
}

/// Retry configuration for scheduled functions.
///
/// Configures how Cloud Scheduler retries failed invocations.
class RetryConfig {
  /// Creates a retry configuration.
  const RetryConfig({
    this.retryCount,
    this.maxRetrySeconds,
    this.minBackoffSeconds,
    this.maxBackoffSeconds,
    this.maxDoublings,
  });

  /// The number of retry attempts for a failed run.
  ///
  /// If set to 0, the job will not be retried on failure.
  final RetryCount? retryCount;

  /// The time limit for retrying a failed job, in seconds.
  ///
  /// After this time, no more retries will be attempted.
  final MaxRetrySeconds? maxRetrySeconds;

  /// The minimum time to wait before retrying, in seconds.
  ///
  /// Must be between 0 and 3600.
  final MinBackoffSeconds? minBackoffSeconds;

  /// The maximum time to wait before retrying, in seconds.
  ///
  /// Must be between 0 and 3600.
  final MaxBackoffSeconds? maxBackoffSeconds;

  /// The maximum number of times that the backoff interval
  /// will be doubled before the interval starts increasing linearly.
  ///
  /// After this many doublings, subsequent retries will increase
  /// the interval linearly according to the formula:
  /// `delay = maxBackoffSeconds + (attempt - maxDoublings) * maxBackoffSeconds`
  final MaxDoublings? maxDoublings;
}

// Type aliases for scheduler-specific options

/// The timezone option type.
typedef TimeZone = Option<String>;

/// The retry count option type.
typedef RetryCount = DeployOption<int>;

/// The max retry seconds option type.
typedef MaxRetrySeconds = DeployOption<int>;

/// The min backoff seconds option type.
typedef MinBackoffSeconds = DeployOption<int>;

/// The max backoff seconds option type.
typedef MaxBackoffSeconds = DeployOption<int>;

/// The max doublings option type.
typedef MaxDoublings = DeployOption<int>;
