import '../common/options.dart';

/// Options for task queue functions.
///
/// Extends [GlobalOptions] with task queue-specific configuration
/// for retry behavior, rate limiting, and access control.
class TaskQueueOptions extends GlobalOptions {
  /// Creates task queue options.
  const TaskQueueOptions({
    this.retryConfig,
    this.rateLimits,
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

  /// How a task should be retried in the event of a non-2xx return.
  final TaskQueueRetryConfig? retryConfig;

  /// How congestion control should be applied to the function.
  final TaskQueueRateLimits? rateLimits;
}

/// Retry configuration for task queue functions.
///
/// Configures how Cloud Tasks retries failed task invocations.
class TaskQueueRetryConfig {
  /// Creates a retry configuration.
  const TaskQueueRetryConfig({
    this.maxAttempts,
    this.maxRetrySeconds,
    this.maxBackoffSeconds,
    this.maxDoublings,
    this.minBackoffSeconds,
  });

  /// Maximum number of times a request should be attempted.
  ///
  /// If left unspecified, will default to 3.
  final MaxAttempts? maxAttempts;

  /// Maximum amount of time for retrying failed task, in seconds.
  ///
  /// If left unspecified will retry indefinitely.
  final TaskMaxRetrySeconds? maxRetrySeconds;

  /// The maximum amount of time to wait between attempts, in seconds.
  ///
  /// If left unspecified will default to 1hr.
  final TaskMaxBackoffSeconds? maxBackoffSeconds;

  /// The maximum number of times to double the backoff between retries.
  ///
  /// If left unspecified will default to 16.
  final TaskMaxDoublings? maxDoublings;

  /// The minimum time to wait between attempts, in seconds.
  ///
  /// If left unspecified will default to 100ms.
  final TaskMinBackoffSeconds? minBackoffSeconds;
}

/// Rate limiting configuration for task queue functions.
///
/// Controls how congestion is managed for the task queue.
class TaskQueueRateLimits {
  /// Creates rate limits configuration.
  const TaskQueueRateLimits({
    this.maxConcurrentDispatches,
    this.maxDispatchesPerSecond,
  });

  /// The maximum number of requests that can be processed at a time.
  ///
  /// If left unspecified, will default to 1000.
  final MaxConcurrentDispatches? maxConcurrentDispatches;

  /// The maximum number of requests that can be invoked per second.
  ///
  /// If left unspecified, will default to 500.
  final MaxDispatchesPerSecond? maxDispatchesPerSecond;
}

// Type aliases for task queue-specific options

/// The max attempts option type.
typedef MaxAttempts = DeployOption<int>;

/// The max retry seconds option type (for task queues).
typedef TaskMaxRetrySeconds = DeployOption<int>;

/// The max backoff seconds option type (for task queues).
typedef TaskMaxBackoffSeconds = DeployOption<int>;

/// The max doublings option type (for task queues).
typedef TaskMaxDoublings = DeployOption<int>;

/// The min backoff seconds option type (for task queues).
typedef TaskMinBackoffSeconds = DeployOption<int>;

/// The max concurrent dispatches option type.
typedef MaxConcurrentDispatches = DeployOption<int>;

/// The max dispatches per second option type.
typedef MaxDispatchesPerSecond = DeployOption<int>;
