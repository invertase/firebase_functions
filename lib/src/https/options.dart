import '../common/options.dart';

/// Options for HTTPS functions (onRequest).
class HttpsOptions extends GlobalOptions {
  /// CORS configuration for the function.
  final Cors? cors;

  const HttpsOptions({
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
    this.cors,
  });
}

/// Options for callable functions (onCall).
class CallableOptions extends HttpsOptions {
  /// Whether to consume the App Check token.
  final ConsumeAppCheckToken? consumeAppCheckToken;

  /// Whether to enforce App Check.
  final EnforceAppCheck? enforceAppCheck;

  /// Heartbeat interval in seconds for streaming responses.
  final HeartBeatIntervalSeconds? heartBeatIntervalSeconds;

  const CallableOptions({
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
    super.cors,
    this.consumeAppCheckToken,
    this.enforceAppCheck,
    this.heartBeatIntervalSeconds,
  });
}

// Type aliases for HTTPS-specific options

typedef Cors = Option<List<String>>;
typedef ConsumeAppCheckToken = Option<bool>;
typedef HeartBeatIntervalSeconds = Option<int>;
