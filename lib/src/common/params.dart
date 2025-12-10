import 'dart:convert';
import 'dart:io';

import 'expression.dart';

// ============================================================================
// Factory functions for creating parameters (matches Node.js API)
// ============================================================================

/// Creates a secret parameter that reads from Cloud Secret Manager.
///
/// Secret values are stored in Cloud Secret Manager and are only available
/// at runtime, not during deployment. You must bind secrets to functions
/// via the `secrets` option.
///
/// Example:
/// ```dart
/// final apiKey = defineSecret('API_KEY');
///
/// firebase.https.onRequest(
///   name: 'secure',
///   options: HttpsOptions(secrets: [apiKey]),
///   (request) async {
///     final key = apiKey.value();
///     return Response.ok('Using API key');
///   },
/// );
/// ```
SecretParam defineSecret(String name) {
  final param = SecretParam(name, null);
  _registerParam(param);
  return param;
}

/// Creates a JSON secret parameter that auto-parses the value.
///
/// This is useful for managing groups of related configuration values
/// stored as a single JSON object in Cloud Secret Manager.
///
/// Example:
/// ```dart
/// final apiConfig = defineJsonSecret<Map<String, dynamic>>('API_CONFIG');
///
/// firebase.https.onRequest(
///   name: 'api',
///   options: HttpsOptions(secrets: [apiConfig]),
///   (request) async {
///     final config = apiConfig.value();
///     final apiKey = config['apiKey'] as String;
///     final webhookSecret = config['webhookSecret'] as String;
///     return Response.ok('Configured');
///   },
/// );
/// ```
///
/// The secret value in Secret Manager should be a valid JSON string like:
/// ```json
/// {"apiKey": "key_...", "webhookSecret": "secret_...", "clientId": "client_..."}
/// ```
JsonSecretParam<T> defineJsonSecret<T>(String name) {
  final param = JsonSecretParam<T>(name);
  _registerParam(param);
  return param;
}

/// Creates a boolean parameter.
///
/// Parameters are read from environment variables at runtime and can be
/// configured at deploy time via .env files or CLI prompts.
///
/// Example:
/// ```dart
/// final isProduction = defineBoolean(
///   'IS_PRODUCTION',
///   ParamOptions(
///     defaultValue: false,
///     description: 'Whether this is a production deployment',
///   ),
/// );
///
/// // Use in function options (deploy-time)
/// firebase.https.onRequest(
///   name: 'api',
///   options: HttpsOptions(
///     minInstances: isProduction.thenElse(2, 0),
///   ),
///   (request) async {
///     // Use at runtime
///     if (isProduction.value()) {
///       // Production behavior
///     }
///     return Response.ok('OK');
///   },
/// );
/// ```
BooleanParam defineBoolean(String name, [ParamOptions<bool>? options]) {
  final param = BooleanParam(name, options);
  _registerParam(param);
  return param;
}

/// Creates an integer parameter.
///
/// Example:
/// ```dart
/// final minInstances = defineInt(
///   'MIN_INSTANCES',
///   ParamOptions(
///     defaultValue: 0,
///     description: 'Minimum number of instances to keep warm',
///     input: ParamInput.select([0, 1, 2, 5, 10]),
///   ),
/// );
/// ```
IntParam defineInt(String name, [ParamOptions<int>? options]) {
  final param = IntParam(name, options);
  _registerParam(param);
  return param;
}

/// Creates a double/float parameter.
DoubleParam defineDouble(String name, [ParamOptions<double>? options]) {
  final param = DoubleParam(name, options);
  _registerParam(param);
  return param;
}

/// Creates a string parameter.
///
/// Example:
/// ```dart
/// final welcomeMessage = defineString(
///   'WELCOME_MESSAGE',
///   ParamOptions(
///     defaultValue: 'Hello!',
///     label: 'Welcome Message',
///     description: 'The greeting shown to users',
///   ),
/// );
/// ```
StringParam defineString(String name, [ParamOptions<String>? options]) {
  final param = StringParam(name, options);
  _registerParam(param);
  return param;
}

/// Creates a string list parameter.
///
/// Example:
/// ```dart
/// final allowedOrigins = defineList(
///   'ALLOWED_ORIGINS',
///   ParamOptions(
///     defaultValue: ['https://example.com'],
///     description: 'CORS allowed origins',
///   ),
/// );
/// ```
ListParam defineList(String name, [ParamOptions<List<String>>? options]) {
  final param = ListParam(name, options);
  _registerParam(param);
  return param;
}

// ============================================================================
// Parameter Registry
// ============================================================================

/// All declared parameters, used for manifest generation.
///
/// Parameters are registered automatically when created via defineX() functions.
final List<Object> declaredParams = [];

/// Registers a parameter, ensuring uniqueness by name.
void _registerParam(Object param) {
  final String? name = switch (param) {
    final Param<Object> p => p.name,
    final JsonSecretParam<Object> p => p.name,
    _ => null,
  };

  if (name != null) {
    // Remove any existing param with the same name
    declaredParams.removeWhere((p) {
      final String? existingName = switch (p) {
        final Param<Object> existing => existing.name,
        final JsonSecretParam<Object> existing => existing.name,
        _ => null,
      };
      return existingName == name;
    });
  }

  declaredParams.add(param);
}

/// Clears all registered parameters. For testing only.
void clearParams() {
  declaredParams.clear();
}

/// Configuration options for customizing parameter prompting behavior.
///
/// Matches the ParamOptions interface from the Node.js SDK.
class ParamOptions<T extends Object> {
  const ParamOptions({
    this.defaultValue,
    this.label,
    this.description,
    this.input,
  });

  /// Default value if parameter is not provided.
  final T? defaultValue;

  /// Short label for the parameter (shown in UI).
  final String? label;

  /// Detailed description of the parameter.
  final String? description;

  /// Input specification for how to collect the parameter value.
  final ParamInput<T>? input;
}

/// Wire representation of a parameter spec for the CLI.
class WireParamSpec<T extends Object> {
  const WireParamSpec({
    required this.name,
    this.defaultValue,
    this.label,
    this.description,
    required this.type,
    this.input,
  });
  final String name;
  final T? defaultValue;
  final String? label;
  final String? description;
  final String type;
  final ParamInput<T>? input;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (defaultValue != null) 'default': defaultValue,
        if (label != null) 'label': label,
        if (description != null) 'description': description,
        'type': type,
        if (input != null) 'input': input,
      };
}

// ============================================================================
// Base Param Class
// ============================================================================

/// Abstract base class for all parameters.
///
/// Parameters are configuration values that can be set at deploy time
/// and accessed at runtime via environment variables.
///
/// **Important**: Parameters use `Platform.environment` for runtime resolution,
/// which means values are read from the process environment variables set by
/// Cloud Functions or the Firebase emulator.
abstract class Param<T extends Object> extends Expression<T> {
  const Param(this.name, this.options);

  /// The environment variable name for this parameter.
  final String name;

  /// Configuration options for this parameter.
  final ParamOptions<T>? options;

  @override
  T runtimeValue();

  /// Returns the parameter value at runtime.
  ///
  /// If called during deployment (when `FUNCTIONS_CONTROL_API` is 'true'),
  /// a warning will be logged since parameter values may not be finalized yet.
  @override
  T value() {
    if (Platform.environment['FUNCTIONS_CONTROL_API'] == 'true') {
      print(
        'Warning: ${toString()}.value() invoked during function deployment, '
        'instead of during runtime.\n'
        'This is usually a mistake. In configs, use Params directly without '
        'calling .value().\n'
        'Example: HttpsOptions(minInstances: minInstancesParam) '
        'not HttpsOptions(minInstances: Option(minInstancesParam.value()))',
      );
    }
    return runtimeValue();
  }

  @override
  String toString() => 'params.$name';

  /// Converts this parameter to its wire specification for deployment.
  WireParamSpec<T> toSpec() => WireParamSpec<T>(
        name: name,
        label: options?.label,
        description: options?.description,
        type: _getTypeName(),
        input: options?.input,
        defaultValue: options?.defaultValue,
      );

  String _getTypeName() {
    final typeName = runtimeType.toString().replaceAll('Param', '');
    return typeName.toLowerCase();
  }
}

// ============================================================================
// Parameter Type Implementations
// ============================================================================

/// A secret parameter stored in Cloud Secret Manager.
///
/// Secret values are stored in Cloud Secret Manager and are only available
/// at runtime, not during deployment. You must bind secrets to functions
/// via the `secrets` option for them to be accessible.
///
/// Example:
/// ```dart
/// final apiKey = defineSecret('API_KEY');
///
/// firebase.https.onRequest(
///   name: 'secure',
///   options: HttpsOptions(secrets: [apiKey]),
///   (request) async {
///     final key = apiKey.value();
///     return Response.ok('Using key: ${key.substring(0, 4)}...');
///   },
/// );
/// ```
class SecretParam extends Param<String> {
  const SecretParam(super.name, super.options);

  @override
  String runtimeValue() {
    final val = Platform.environment[name];
    if (val == null) {
      print(
        'Warning: No value found for secret parameter "$name". '
        'A function can only access a secret if you include the secret '
        'in the function\'s secrets array.',
      );
      return '';
    }
    return val;
  }

  /// Returns the secret value at runtime.
  ///
  /// Throws a [StateError] if called during deployment.
  @override
  String value() {
    if (Platform.environment['FUNCTIONS_CONTROL_API'] == 'true') {
      throw StateError(
        'Cannot access the value of secret "$name" during function deployment. '
        'Secret values are only available at runtime.',
      );
    }
    return runtimeValue();
  }

  @override
  WireParamSpec<String> toSpec() => WireParamSpec<String>(
        name: name,
        type: 'secret',
      );
}

/// A JSON secret parameter that auto-parses the stored value.
///
/// This is useful for managing groups of related configuration values
/// stored as a single JSON object in Cloud Secret Manager.
///
/// Example:
/// ```dart
/// final apiConfig = defineJsonSecret<Map<String, dynamic>>('API_CONFIG');
///
/// firebase.https.onRequest(
///   name: 'api',
///   options: HttpsOptions(secrets: [apiConfig]),
///   (request) async {
///     final config = apiConfig.value();
///     final apiKey = config['apiKey'] as String;
///     return Response.ok('Configured');
///   },
/// );
/// ```
class JsonSecretParam<T> {
  const JsonSecretParam(this.name);

  /// The environment variable name for this secret.
  final String name;

  /// Returns the parsed JSON value at runtime.
  ///
  /// Throws a [StateError] if:
  /// - Called during deployment (`FUNCTIONS_CONTROL_API == 'true'`)
  /// - The secret is not bound to the function
  /// - The stored value is not valid JSON
  T value() {
    if (Platform.environment['FUNCTIONS_CONTROL_API'] == 'true') {
      throw StateError(
        'Cannot access the value of secret "$name" during function deployment. '
        'Secret values are only available at runtime.',
      );
    }
    return runtimeValue();
  }

  /// @internal
  T runtimeValue() {
    final val = Platform.environment[name];
    if (val == null) {
      throw StateError(
        'No value found for secret parameter "$name". '
        'A function can only access a secret if you include the secret '
        'in the function\'s secrets array.',
      );
    }

    try {
      return jsonDecode(val) as T;
    } on FormatException catch (e) {
      throw StateError(
        '"$name" could not be parsed as JSON. '
        'Please verify its value in Secret Manager. Details: $e',
      );
    }
  }

  /// @internal
  Map<String, dynamic> toSpec() => {
        'type': 'secret',
        'name': name,
        'format': 'json',
      };

  @override
  String toString() => 'params.$name';
}

/// A string parameter.
///
/// Reads from `Platform.environment` at runtime.
class StringParam extends Param<String> {
  const StringParam(super.name, super.options);

  @override
  String runtimeValue() {
    return Platform.environment[name] ?? options?.defaultValue ?? '';
  }
}

/// An integer parameter.
///
/// Reads from `Platform.environment` at runtime and parses as int.
class IntParam extends Param<int> {
  const IntParam(super.name, super.options);

  @override
  int runtimeValue() {
    final envValue = Platform.environment[name];
    if (envValue == null || envValue.isEmpty) {
      return options?.defaultValue ?? 0;
    }
    return int.tryParse(envValue) ?? options?.defaultValue ?? 0;
  }
}

/// A double/float parameter.
///
/// Reads from `Platform.environment` at runtime and parses as double.
class DoubleParam extends Param<double> {
  const DoubleParam(super.name, super.options);

  @override
  double runtimeValue() {
    final envValue = Platform.environment[name];
    if (envValue == null || envValue.isEmpty) {
      return options?.defaultValue ?? 0.0;
    }
    return double.tryParse(envValue) ?? options?.defaultValue ?? 0.0;
  }
}

/// A boolean parameter.
///
/// Reads from `Platform.environment` at runtime. The value is considered
/// `true` if the environment variable equals 'true' (case-sensitive).
class BooleanParam extends Param<bool> {
  const BooleanParam(super.name, super.options);

  @override
  bool runtimeValue() {
    final envValue = Platform.environment[name];
    if (envValue == null) {
      return options?.defaultValue ?? false;
    }
    return envValue == 'true';
  }

  /// Creates a conditional expression that returns different values
  /// based on this boolean parameter's value.
  ///
  /// Example:
  /// ```dart
  /// final isProduction = defineBoolean('IS_PRODUCTION');
  /// final memory = isProduction.thenElse(2048, 512);
  /// ```
  If<T> thenElse<T extends Object>(T ifTrue, T ifFalse) {
    return If<T>(
      this, // test is a positional argument
      then: LiteralExpression<T>(ifTrue),
      otherwise: LiteralExpression<T>(ifFalse),
    );
  }
}

/// A string list parameter.
///
/// Reads from `Platform.environment` at runtime and parses as JSON array.
/// The environment variable should contain a JSON array of strings,
/// e.g., `'["value1", "value2"]'`.
class ListParam extends Param<List<String>> {
  const ListParam(super.name, super.options);

  @override
  List<String> runtimeValue() {
    final val = Platform.environment[name];
    if (val == null || val.isEmpty) {
      return options?.defaultValue ?? [];
    }

    try {
      final parsed = jsonDecode(val);
      if (parsed is List && parsed.every((v) => v is String)) {
        return List<String>.from(parsed);
      }
    } on FormatException {
      // Invalid JSON, return default
      print(
        'Warning: Failed to parse list parameter "$name" as JSON array. '
        'Expected format: \'["value1", "value2"]\'. Returning default value.',
      );
    }

    return options?.defaultValue ?? [];
  }
}

/// Internal expression for Firebase-provided values.
///
/// These are special expressions that read from Firebase environment
/// variables and are always available without being defined by the user.
class InternalExpression extends Param<String> {
  const InternalExpression._(String name, this.getter) : super(name, null);
  final String Function(Map<String, String>) getter;

  @override
  String runtimeValue() => getter(Platform.environment);

  @override
  WireParamSpec<String> toSpec() {
    throw UnsupportedError(
      'InternalExpression should never be serialized for deployment',
    );
  }
}

/// Sealed class hierarchy for parameter input types.
///
/// Matches the input types from the Node.js SDK.
sealed class ParamInput<T extends Object> {
  const ParamInput();

  // Predefined resource pickers

  static const bucketPicker = ResourceInput._(
    resourceType: 'storage.googleapis.com/Bucket',
  );

  // Internal Firebase expressions

  static final databaseURL = InternalExpression._(
    'DATABASE_URL',
    (env) {
      if (!env.containsKey('FIREBASE_CONFIG')) return '';
      try {
        final config = jsonDecode(env['FIREBASE_CONFIG']!);
        return config['databaseURL'] as String? ?? '';
      } on FormatException {
        return '';
      }
    },
  );

  static final projectId = InternalExpression._(
    'PROJECT_ID',
    (env) {
      if (!env.containsKey('FIREBASE_CONFIG')) return '';
      try {
        final config = jsonDecode(env['FIREBASE_CONFIG']!);
        return config['projectId'] as String? ?? '';
      } on FormatException {
        return '';
      }
    },
  );

  static final gcloudProject = InternalExpression._(
    'GCLOUD_PROJECT',
    (env) {
      if (!env.containsKey('FIREBASE_CONFIG')) return '';
      try {
        final config = jsonDecode(env['FIREBASE_CONFIG']!);
        return config['projectId'] as String? ?? '';
      } on FormatException {
        return '';
      }
    },
  );

  static final storageBucket = InternalExpression._(
    'STORAGE_BUCKET',
    (env) {
      if (!env.containsKey('FIREBASE_CONFIG')) return '';
      try {
        final config = jsonDecode(env['FIREBASE_CONFIG']!);
        return config['storageBucket'] as String? ?? '';
      } on FormatException {
        return '';
      }
    },
  );

  // Factory methods for creating input types

  /// Creates a multi-select input from a list of values.
  static MultiSelectParamInput multiSelect(List<String> options) =>
      MultiSelectParamInput(
        options: options.map((opt) => SelectOption(value: opt)).toList(),
      );

  /// Creates a multi-select input from a map of labels to values.
  static MultiSelectParamInput multiSelectWithLabels(
    Map<String, String> optionsWithLabels,
  ) =>
      MultiSelectParamInput(
        options: optionsWithLabels.entries
            .map((entry) => SelectOption(value: entry.value, label: entry.key))
            .toList(),
      );

  /// Creates a single-select input from a list of values.
  static SelectParamInput<T> select<T extends Object>(List<T> options) =>
      SelectParamInput<T>(
        options: options.map((opt) => SelectOption(value: opt)).toList(),
      );

  /// Creates a single-select input from a map of labels to values.
  static SelectParamInput<T> selectWithLabels<T extends Object>(
    Map<String, T> optionsWithLabels,
  ) =>
      SelectParamInput<T>(
        options: optionsWithLabels.entries
            .map((entry) => SelectOption(value: entry.value, label: entry.key))
            .toList(),
      );
}

/// Text input with optional validation.
class TextParamInput<T extends Object> extends ParamInput<T> {
  const TextParamInput({
    this.example,
    this.validationRegex,
    this.validationErrorMessage,
  });
  final String? example;
  final RegExp? validationRegex;
  final String? validationErrorMessage;
}

/// Resource picker input (e.g., for selecting a Cloud Storage bucket).
class ResourceInput extends ParamInput<String> {
  const ResourceInput._({required this.resourceType});
  final String resourceType;
}

/// Single-select input from a list of options.
class SelectParamInput<T extends Object> extends ParamInput<T> {
  const SelectParamInput({required this.options});
  final List<SelectOption<T>> options;
}

/// Multi-select input from a list of options.
class MultiSelectParamInput extends ParamInput<List<String>> {
  const MultiSelectParamInput({required this.options});
  final List<SelectOption<String>> options;
}

/// An option in a select or multi-select input.
class SelectOption<T extends Object> {
  const SelectOption({required this.value, this.label});
  final T value;
  final String? label;
}
