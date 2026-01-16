/// Options for Identity Platform blocking functions.
library;

import '../common/options.dart';

/// Options for Identity blocking functions.
///
/// Extends [GlobalOptions] with credential-passing options specific to
/// identity platform blocking functions.
class BlockingOptions extends GlobalOptions {
  const BlockingOptions({
    this.idToken,
    this.accessToken,
    this.refreshToken,
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

  /// Pass the ID Token credential to the function.
  final bool? idToken;

  /// Pass the Access Token credential to the function.
  final bool? accessToken;

  /// Pass the Refresh Token credential to the function.
  final bool? refreshToken;
}

/// Internal options used when parsing BlockingOptions.
class InternalOptions {
  const InternalOptions({
    required this.opts,
    required this.idToken,
    required this.accessToken,
    required this.refreshToken,
  });

  /// The global options.
  final GlobalOptions opts;

  /// Whether to pass the ID token.
  final bool idToken;

  /// Whether to pass the access token.
  final bool accessToken;

  /// Whether to pass the refresh token.
  final bool refreshToken;
}

/// Extracts internal options from BlockingOptions.
InternalOptions getInternalOptions(BlockingOptions? blockingOptions) {
  final options = blockingOptions ?? const BlockingOptions();
  return InternalOptions(
    opts: GlobalOptions(
      concurrency: options.concurrency,
      cpu: options.cpu,
      ingressSettings: options.ingressSettings,
      invoker: options.invoker,
      labels: options.labels,
      minInstances: options.minInstances,
      maxInstances: options.maxInstances,
      memory: options.memory,
      omit: options.omit,
      preserveExternalChanges: options.preserveExternalChanges,
      region: options.region,
      secrets: options.secrets,
      serviceAccount: options.serviceAccount,
      timeoutSeconds: options.timeoutSeconds,
      vpcConnector: options.vpcConnector,
      vpcConnectorEgressSettings: options.vpcConnectorEgressSettings,
    ),
    idToken: options.idToken ?? false,
    accessToken: options.accessToken ?? false,
    refreshToken: options.refreshToken ?? false,
  );
}
