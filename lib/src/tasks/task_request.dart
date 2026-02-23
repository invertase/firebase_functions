import 'package:shelf/shelf.dart';

import '../https/callable.dart';

/// The request used to call a task queue function.
///
/// Extends the underlying Shelf [Request] with task-specific context
/// and authentication data.
///
/// Example:
/// ```dart
/// firebase.tasks.onTaskDispatched(
///   name: 'processOrder',
///   (request) async {
///     final data = request.data;
///     print('Task ID: ${request.id}');
///     print('Queue: ${request.queueName}');
///     print('Retry count: ${request.retryCount}');
///   },
/// );
/// ```
class TaskRequest<T> {
  TaskRequest(
    this._delegate,
    this._body, {
    required this.queueName,
    required this.id,
    required this.retryCount,
    required this.executionCount,
    required this.scheduledTime,
    this.auth,
    this.previousResponse,
    this.retryReason,
  });

  final Request _delegate;
  final Object? _body;

  /// The result of decoding and verifying an OIDC token.
  final TaskAuthData? auth;

  /// The parameters used by a client when calling this function.
  T get data {
    final decoded = decode(_body);
    return decoded as T;
  }

  /// The name of the queue.
  ///
  /// Populated via the `X-CloudTasks-QueueName` header.
  final String queueName;

  /// The "short" name of the task, or, if no name was specified at creation,
  /// a unique system-generated id.
  ///
  /// Populated via the `X-CloudTasks-TaskName` header.
  final String id;

  /// The number of times this task has been retried.
  ///
  /// For the first attempt, this value is 0. This number includes attempts
  /// where the task failed due to 5XX error codes and never reached the
  /// execution phase.
  ///
  /// Populated via the `X-CloudTasks-TaskRetryCount` header.
  final int retryCount;

  /// The total number of times that the task has received a response
  /// from the handler.
  ///
  /// Populated via the `X-CloudTasks-TaskExecutionCount` header.
  final int executionCount;

  /// The schedule time of the task, as an RFC 3339 string in UTC time zone.
  ///
  /// Populated via the `X-CloudTasks-TaskETA` header.
  final String scheduledTime;

  /// The HTTP response code from the previous retry.
  ///
  /// Populated via the `X-CloudTasks-TaskPreviousResponse` header.
  final int? previousResponse;

  /// The reason for retrying the task.
  ///
  /// Populated via the `X-CloudTasks-TaskRetryReason` header.
  final String? retryReason;

  /// The raw Shelf request.
  Request get rawRequest => _delegate;
}

/// Metadata about the authorization used to invoke a task queue function.
class TaskAuthData {
  const TaskAuthData({required this.uid, this.token});

  /// The user's unique ID.
  final String uid;

  /// The decoded ID token.
  final DecodedIdToken? token;
}

/// Replicate of the decoded id token interface from the admin SDK.
///
/// See https://firebase.google.com/docs/reference/admin/node/firebase-admin.auth.decodedidtoken
class DecodedIdToken {
  const DecodedIdToken({
    required this.aud,
    required this.authTime,
    required this.exp,
    required this.iat,
    required this.iss,
    required this.sub,
    required this.uid,
    this.emailVerified,
    this.email,
    this.firebase,
    this.phoneNumber,
    this.picture,
  });

  /// The audience for which this token is intended.
  final String aud;

  /// Time when the user authenticated.
  final DateTime authTime;

  /// Whether the email is verified.
  final bool? emailVerified;

  /// The user's email address.
  final String? email;

  /// Expiration time of the token.
  final int exp;

  /// Information about the sign in event, including which sign in provider
  /// was used and provider-specific identity details.
  final Map<String, Object>? firebase;

  /// Issued-at time of the token.
  final int iat;

  /// Issuer of the token.
  final String iss;

  /// The user's phone number.
  final String? phoneNumber;

  /// The user's profile picture URL.
  final String? picture;

  /// Subject of the token (the user's UID).
  final String sub;

  /// The user's unique ID (same as [sub]).
  final String uid;
}
