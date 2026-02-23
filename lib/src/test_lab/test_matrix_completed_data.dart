/// Possible test states for a test matrix.
enum TestState {
  /// The default value. This value is used if the state is omitted.
  testStateUnspecified('TEST_STATE_UNSPECIFIED'),

  /// The test matrix is being validated.
  validating('VALIDATING'),

  /// The test matrix is waiting for resources to become available.
  pending('PENDING'),

  /// The test matrix has completed normally.
  finished('FINISHED'),

  /// The test matrix has completed because of an infrastructure failure.
  error('ERROR'),

  /// The test matrix was not run because the provided inputs are not valid.
  invalid('INVALID');

  const TestState(this.value);

  /// The string value of this state.
  final String value;

  /// Parses a [TestState] from a string value.
  static TestState fromString(String value) => TestState.values.firstWhere(
    (e) => e.value == value,
    orElse: () => TestState.testStateUnspecified,
  );
}

/// Outcome summary for a finished test matrix.
enum OutcomeSummary {
  /// The default value. This value is used if the state is omitted.
  outcomeSummaryUnspecified('OUTCOME_SUMMARY_UNSPECIFIED'),

  /// The test matrix run was successful.
  success('SUCCESS'),

  /// A run failed.
  failure('FAILURE'),

  /// Something unexpected happened.
  inconclusive('INCONCLUSIVE'),

  /// All tests were skipped.
  skipped('SKIPPED');

  const OutcomeSummary(this.value);

  /// The string value of this outcome.
  final String value;

  /// Parses an [OutcomeSummary] from a string value.
  static OutcomeSummary fromString(String value) =>
      OutcomeSummary.values.firstWhere(
        (e) => e.value == value,
        orElse: () => OutcomeSummary.outcomeSummaryUnspecified,
      );
}

/// Locations where test results are stored.
class ResultStorage {
  const ResultStorage({
    required this.toolResultsHistory,
    required this.resultsUri,
    required this.gcsPath,
    this.toolResultsExecution,
  });

  /// Parses a [ResultStorage] from JSON.
  factory ResultStorage.fromJson(Map<String, dynamic> json) {
    return ResultStorage(
      toolResultsHistory: json['toolResultsHistory'] as String? ?? '',
      toolResultsExecution: json['toolResultsExecution'] as String?,
      resultsUri: json['resultsUri'] as String? ?? '',
      gcsPath: json['gcsPath'] as String? ?? '',
    );
  }

  /// Tool Results history resource containing test results.
  /// Format is `projects/{project_id}/histories/{history_id}`.
  final String toolResultsHistory;

  /// Tool Results execution resource containing test results.
  /// Format is `projects/{project_id}/histories/{history_id}/executions/{execution_id}`.
  /// Optional, can be omitted in erroneous test states.
  final String? toolResultsExecution;

  /// URI to the test results in the Firebase Web Console.
  final String resultsUri;

  /// Location in Google Cloud Storage where test results are written to.
  /// In the form "gs://bucket/path/to/somewhere".
  final String gcsPath;
}

/// Information about the client which invoked the test.
class ClientInfo {
  const ClientInfo({required this.client, this.details = const {}});

  /// Parses a [ClientInfo] from JSON.
  factory ClientInfo.fromJson(Map<String, dynamic> json) {
    return ClientInfo(
      client: json['client'] as String? ?? '',
      details: json['details'] != null
          ? Map<String, String>.from(json['details'] as Map)
          : const {},
    );
  }

  /// Client name, such as "gcloud".
  final String client;

  /// Map of detailed information about the client.
  final Map<String, String> details;
}

/// The data within all Firebase test matrix completed events.
class TestMatrixCompletedData {
  const TestMatrixCompletedData({
    required this.testMatrixId,
    required this.state,
    required this.outcomeSummary,
    required this.resultStorage,
    required this.clientInfo,
    this.createTime,
    this.invalidMatrixDetails,
  });

  /// Parses a [TestMatrixCompletedData] from JSON.
  factory TestMatrixCompletedData.fromJson(Map<String, dynamic> json) {
    return TestMatrixCompletedData(
      testMatrixId: json['testMatrixId'] as String? ?? '',
      state: TestState.fromString(
        json['state'] as String? ?? 'TEST_STATE_UNSPECIFIED',
      ),
      outcomeSummary: OutcomeSummary.fromString(
        json['outcomeSummary'] as String? ?? 'OUTCOME_SUMMARY_UNSPECIFIED',
      ),
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'] as String)
          : null,
      invalidMatrixDetails: json['invalidMatrixDetails'] as String?,
      resultStorage: ResultStorage.fromJson(
        json['resultStorage'] as Map<String, dynamic>? ?? {},
      ),
      clientInfo: ClientInfo.fromJson(
        json['clientInfo'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// ID of the test matrix this event belongs to.
  final String testMatrixId;

  /// State of the test matrix.
  final TestState state;

  /// Outcome summary of the test matrix.
  final OutcomeSummary outcomeSummary;

  /// Time the test matrix was created.
  final DateTime? createTime;

  /// Code that describes why the test matrix is considered invalid.
  /// Only set for matrices in the INVALID state.
  final String? invalidMatrixDetails;

  /// Locations where test results are stored.
  final ResultStorage resultStorage;

  /// Information provided by the client that created the test matrix.
  final ClientInfo clientInfo;
}
