import '../common/options.dart';

/// Options for Eventarc event handlers.
///
/// Extends [GlobalOptions] with Eventarc-specific fields.
class EventarcTriggerOptions extends GlobalOptions {
  const EventarcTriggerOptions({
    this.channel,
    this.filters,
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

  /// ID of the channel. Can be either:
  ///   * fully qualified channel resource name:
  ///     `projects/{project}/locations/{location}/channels/{channel-id}`
  ///   * partial resource name with location and channel ID:
  ///     `locations/{location}/channels/{channel-id}`
  ///   * partial channel ID: `{channel-id}`
  ///
  /// If not specified, the default Firebase channel will be used:
  /// `locations/us-central1/channels/firebase`
  final String? channel;

  /// Eventarc event exact match filter.
  final Map<String, String>? filters;
}
