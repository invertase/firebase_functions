import 'dart:convert';
import 'package:http/http.dart' as http;

/// Helper for making HTTP requests to Firebase Functions in the emulator.
class FunctionsHttpClient {
  FunctionsHttpClient(this.baseUrl) : _client = http.Client();
  final String baseUrl;
  final http.Client _client;

  /// Calls an onRequest function with GET method.
  Future<http.Response> get(String functionName) async {
    final url = Uri.parse('$baseUrl/$functionName');
    print('GET $url');
    return await _client.get(url);
  }

  /// Calls an onRequest function with POST method.
  Future<http.Response> post(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl/$functionName');
    print('POST $url');

    return await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// Calls a callable function (onCall).
  Future<http.Response> call(
    String functionName, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl/$functionName');
    print('CALL $url with data: $data');

    final body = jsonEncode({'data': data});

    return await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: body,
    );
  }

  /// Parses a callable function response.
  dynamic parseCallableResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception(
        'Callable function failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // Check for error in response
    if (json.containsKey('error')) {
      final error = json['error'] as Map<String, dynamic>;
      throw Exception('Function error: ${error['message']}');
    }

    return json['result'];
  }

  /// Closes the HTTP client.
  void close() {
    _client.close();
  }
}
