import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

import '../firebase.dart';
import 'callable.dart';
import 'error.dart';
import 'options.dart';

/// HTTPS triggers namespace.
///
/// Provides methods to define HTTP-triggered Cloud Functions.
class HttpsNamespace extends FunctionsNamespace {
  const HttpsNamespace(super.firebase);

  /// Creates an HTTPS function that handles raw HTTP requests.
  ///
  /// The handler receives a Shelf [Request] and must return a Shelf [Response].
  ///
  /// Example:
  /// ```dart
  /// firebase.https.onRequest(
  ///   name: 'hello',
  ///   (request) async {
  ///     return Response.ok('Hello World!');
  ///   },
  /// );
  /// ```
  void onRequest(
    Future<Response> Function(Request request) handler, {
    // ignore: experimental_member_use
    @mustBeConst required String name,
    // ignore: experimental_member_use
    @mustBeConst HttpsOptions? options = const HttpsOptions(),
  }) {
    firebase.registerFunction(
      name,
      (request) async {
        try {
          return await handler(request);
        } on HttpsError catch (e) {
          return Response(
            400,
            body: jsonEncode(e.toErrorResponse()),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          // Unexpected error - return internal error
          final error = HttpsError(
            FunctionsErrorCode.internal,
            e.toString(),
          );
          return Response(
            500,
            body: jsonEncode(error.toErrorResponse()),
            headers: {'Content-Type': 'application/json'},
          );
        }
      },
      external: true,
    );
  }

  /// Creates an HTTPS callable function (untyped data).
  ///
  /// Callable functions provide a simple RPC interface with automatic
  /// request/response handling and Firebase Auth integration.
  ///
  /// Example:
  /// ```dart
  /// firebase.https.onCall(
  ///   name: 'greet',
  ///   (request, response) async {
  ///     final name = request.data['name'] as String;
  ///     return CallableResult({'message': 'Hello $name!'});
  ///   },
  /// );
  /// ```
  void onCall<T extends Object>(
    Future<CallableResult<T>> Function(
      CallableRequest<Object?> request,
      CallableResponse<T> response,
    ) handler, {
    // ignore: experimental_member_use
    @mustBeConst required String name,
    // ignore: experimental_member_use
    @mustBeConst CallableOptions? options = const CallableOptions(),
  }) {
    firebase.registerFunction(
      name,
      (request) async {
        final bodyString = await request.change().readAsString();
        final body = jsonDecode(bodyString) as Map<String, dynamic>;
        final callableRequest = CallableRequest(request, body['data'], null);

        return _handleCallable<Object?, T, CallableResult<T>>(
          request,
          callableRequest,
          body,
          options,
          handler,
          (result) => result.data,
          (result) => result.toResponse(),
        );
      },
    );
  }

  /// Creates an HTTPS callable function with typed data.
  ///
  /// Provides type-safe request/response handling with custom serialization.
  ///
  /// Example:
  /// ```dart
  /// class GreetRequest {
  ///   final String name;
  ///   GreetRequest(this.name);
  ///   factory GreetRequest.fromJson(Map<String, dynamic> json) =>
  ///       GreetRequest(json['name'] as String);
  /// }
  ///
  /// firebase.https.onCallWithData<GreetRequest, String>(
  ///   name: 'greetTyped',
  ///   fromJson: GreetRequest.fromJson,
  ///   (request, response) async {
  ///     return 'Hello ${request.data.name}!';
  ///   },
  /// );
  /// ```
  void onCallWithData<Input extends Object, Output extends Object>(
    Future<Output> Function(
      CallableRequest<Input> request,
      CallableResponse<Output> response,
    ) handler, {
    required Input Function(Map<String, dynamic>) fromJson,
    // ignore: experimental_member_use
    @mustBeConst required String name,
    // ignore: experimental_member_use
    @mustBeConst CallableOptions? options = const CallableOptions(),
  }) {
    firebase.registerFunction(
      name,
      (request) async {
        final body = await request.json as Map<String, dynamic>?;
        final callableRequest = CallableRequest<Input>(
          request,
          body?['data'],
          fromJson,
        );

        return _handleCallable<Input, Output, Output>(
          request,
          callableRequest,
          body,
          options,
          handler,
          (result) => result,
          (result) => Response.ok(
              jsonEncode({'result': result}),
              headers: {'Content-Type': 'application/json'},
            ),
        );
      },
    );
  }

  /// Internal handler for callable functions.
  ///
  /// Handles both streaming and non-streaming responses, error handling,
  /// and request validation.
  Future<Response> _handleCallable<
      Req extends Object?,
      StreamType extends Object,
      Res extends Object>(
    Request request,
    CallableRequest<Req> callableRequest,
    Map<String, dynamic>? body,
    CallableOptions? options,
    Future<Res> Function(
      CallableRequest<Req> request,
      CallableResponse<StreamType> response,
    ) handler,
    dynamic Function(Res result) extractResultData,
    Response Function(Res result) createNonStreamingResponse,
  ) async {
    // Validate request
    if (!await request.isValidRequest(body)) {
      final error = HttpsError(
        FunctionsErrorCode.invalidArgument,
        'Invalid callable request',
      );
      return Response(
        400,
        body: jsonEncode(error.toErrorResponse()),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final heartbeatSeconds = options?.heartBeatIntervalSeconds?.runtimeValue();
    final callableResponse = CallableResponse<StreamType>(
      acceptsStreaming: callableRequest.acceptsStreaming,
      heartbeatSeconds: heartbeatSeconds,
    );

    try {
      // Initialize streaming if requested
      if (callableRequest.acceptsStreaming) {
        callableResponse.initializeStreaming();
      }

      // Execute handler
      final result = await handler(callableRequest, callableResponse);

      // Handle streaming response
      if (callableRequest.acceptsStreaming && !callableResponse.aborted) {
        final finalResult = {'result': extractResultData(result)};
        callableResponse.writeSSE(finalResult);
        await callableResponse.closeStream();
        return callableResponse.streamingResponse!;
      }

      // Non-streaming response
      return createNonStreamingResponse(result);
    } on HttpsError catch (e) {
      // Handle HttpsError - use SSE format if streaming
      if (callableRequest.acceptsStreaming && !callableResponse.aborted) {
        callableResponse.writeSSE(e.toErrorResponse());
        await callableResponse.closeStream();
        return callableResponse.streamingResponse!;
      }

      return Response(
        400,
        body: jsonEncode(e.toErrorResponse()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      // Unexpected error
      final error = HttpsError(
        FunctionsErrorCode.internal,
        e.toString(),
      );

      if (callableRequest.acceptsStreaming && !callableResponse.aborted) {
        callableResponse.writeSSE(error.toErrorResponse());
        await callableResponse.closeStream();
        return callableResponse.streamingResponse!;
      }

      return Response(
        500,
        body: jsonEncode(error.toErrorResponse()),
        headers: {'Content-Type': 'application/json'},
      );
    } finally {
      callableResponse.clearHeartbeat();
    }
  }
}
