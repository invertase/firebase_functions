import '../common/options.dart';

/// Options for Firebase Alerts handlers.
class AlertOptions extends GlobalOptions {
  const AlertOptions({
    this.appId,
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

  /// Scope the function to trigger on a specific application.
  final String? appId;
}
