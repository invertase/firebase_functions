import '../common/options.dart';

/// DocumentOptions extend GlobalOptions with provided document and optional database and namespace.
class DocumentOptions extends GlobalOptions {
  const DocumentOptions({
    required this.document,
    this.database,
    this.namespace,
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

  /// The document path (e.g., "users/{userId}" or "users/user123").
  /// Supports path patterns with wildcards.
  final String document;

  /// The Firestore database (default: "(default)").
  final String? database;

  /// The Firestore namespace (default: "(default)").
  final String? namespace;
}
