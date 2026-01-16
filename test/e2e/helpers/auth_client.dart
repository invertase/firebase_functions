import 'dart:convert';

import 'package:http/http.dart' as http;

/// Response from creating a new user.
class SignUpResponse {
  SignUpResponse({
    required this.localId,
    required this.email,
    required this.idToken,
    required this.refreshToken,
  });

  factory SignUpResponse.fromJson(Map<String, dynamic> json) {
    return SignUpResponse(
      localId: json['localId'] as String,
      email: json['email'] as String,
      idToken: json['idToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }

  final String localId;
  final String email;
  final String idToken;
  final String refreshToken;
}

/// Response from signing in a user.
class SignInResponse {
  SignInResponse({
    required this.localId,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    required this.registered,
  });

  factory SignInResponse.fromJson(Map<String, dynamic> json) {
    return SignInResponse(
      localId: json['localId'] as String,
      email: json['email'] as String,
      idToken: json['idToken'] as String,
      refreshToken: json['refreshToken'] as String,
      registered: json['registered'] as bool? ?? true,
    );
  }

  final String localId;
  final String email;
  final String idToken;
  final String refreshToken;
  final bool registered;
}

/// Error from an auth operation.
class AuthError implements Exception {
  AuthError({
    required this.code,
    required this.message,
  });

  factory AuthError.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>;
    return AuthError(
      code: error['code'] as int? ?? 0,
      message: error['message'] as String? ?? 'Unknown error',
    );
  }

  final int code;
  final String message;

  @override
  String toString() => 'AuthError($code): $message';
}

/// Helper for making requests to the Firebase Auth Emulator.
///
/// This client uses the Identity Toolkit REST API which triggers blocking
/// functions (beforeUserCreated, beforeUserSignedIn).
///
/// Note: Admin operations (direct database access) do NOT trigger blocking
/// functions - only client SDK operations do.
class AuthClient {
  AuthClient(this.baseUrl, this.projectId) : _client = http.Client();

  final String baseUrl;
  final String projectId;
  final http.Client _client;

  /// The API key to use for requests. The emulator accepts any non-empty key.
  static const String apiKey = 'fake-api-key';

  /// Creates a new user account with email and password.
  ///
  /// This triggers the `beforeUserCreated` blocking function if configured.
  ///
  /// Throws [AuthError] if the operation fails (e.g., blocked by function).
  Future<SignUpResponse> signUp({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse(
      '$baseUrl/identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
    );

    print('AUTH signUp: $email');

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw AuthError.fromJson(json);
    }

    return SignUpResponse.fromJson(json);
  }

  /// Signs in an existing user with email and password.
  ///
  /// This triggers the `beforeUserSignedIn` blocking function if configured.
  ///
  /// Throws [AuthError] if the operation fails (e.g., blocked by function).
  Future<SignInResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse(
      '$baseUrl/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
    );

    print('AUTH signInWithPassword: $email');

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw AuthError.fromJson(json);
    }

    return SignInResponse.fromJson(json);
  }

  /// Deletes a user account by their ID token.
  ///
  /// Note: This is an admin operation and does NOT trigger blocking functions.
  Future<void> deleteAccount(String idToken) async {
    final url = Uri.parse(
      '$baseUrl/identitytoolkit.googleapis.com/v1/accounts:delete?key=$apiKey',
    );

    print('AUTH deleteAccount');

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
      }),
    );

    if (response.statusCode != 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      throw AuthError.fromJson(json);
    }
  }

  /// Clears all users from the auth emulator.
  ///
  /// This is useful for test cleanup.
  Future<void> clearAllUsers() async {
    final url = Uri.parse(
      '$baseUrl/emulator/v1/projects/$projectId/accounts',
    );

    print('AUTH clearAllUsers');

    final response = await _client.delete(url);

    if (response.statusCode != 200) {
      print('Warning: Failed to clear users: ${response.body}');
    }
  }

  /// Closes the HTTP client.
  void close() {
    _client.close();
  }
}
