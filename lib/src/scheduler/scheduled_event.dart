/// Event data for scheduled functions.
///
/// Contains metadata about the Cloud Scheduler job invocation.
class ScheduledEvent {
  /// Creates a ScheduledEvent.
  const ScheduledEvent({
    this.jobName,
    required this.scheduleTime,
  });

  /// Creates a ScheduledEvent from HTTP request headers.
  ///
  /// Extracts job metadata from Cloud Scheduler headers:
  /// - `X-CloudScheduler-JobName`: The Cloud Scheduler job name
  /// - `X-CloudScheduler-ScheduleTime`: The scheduled execution time
  factory ScheduledEvent.fromHeaders(Map<String, String> headers) {
    // Cloud Scheduler sends these headers
    final jobName = headers['x-cloudscheduler-jobname'];
    final scheduleTimeHeader = headers['x-cloudscheduler-scheduletime'];

    // If scheduleTime header is missing (e.g., manual invocation),
    // use current time
    final scheduleTime =
        scheduleTimeHeader ?? DateTime.now().toUtc().toIso8601String();

    return ScheduledEvent(
      jobName: jobName,
      scheduleTime: scheduleTime,
    );
  }

  /// The Cloud Scheduler job name.
  ///
  /// Populated via the `X-CloudScheduler-JobName` header.
  /// Will be `null` if the function is invoked manually.
  ///
  /// Format: `projects/{project}/locations/{location}/jobs/{job}`
  final String? jobName;

  /// The scheduled execution time in RFC3339 UTC "Zulu" format.
  ///
  /// For Cloud Scheduler jobs, this is populated via the
  /// `X-CloudScheduler-ScheduleTime` header.
  ///
  /// If the function is manually triggered, this will be the
  /// function execution time.
  ///
  /// Example: `2024-01-01T00:00:00Z`
  final String scheduleTime;

  /// Returns the schedule time as a [DateTime] object.
  DateTime get scheduleDateTime => DateTime.parse(scheduleTime);

  @override
  String toString() =>
      'ScheduledEvent(jobName: $jobName, scheduleTime: $scheduleTime)';
}
