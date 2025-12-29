import '../common/options.dart';

/// ReferenceOptions extend GlobalOptions with provided ref and optional instance.
///
/// Used to configure Realtime Database event triggers.
class ReferenceOptions extends GlobalOptions {
  const ReferenceOptions({
    this.instance,
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

  /// Specify the handler to trigger on a database instance(s).
  ///
  /// If present, this value can either be a single instance or a pattern.
  /// Examples: 'my-instance-1', 'my-instance-*'
  ///
  /// Note: The capture syntax cannot be used for 'instance'.
  /// If not specified, defaults to '*' (all instances).
  final String? instance;
}
