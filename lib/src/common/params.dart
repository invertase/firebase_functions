import 'dart:convert';
import 'dart:io';

import 'expression.dart';

// Factory functions for creating parameters (matches Node.js API)

/// Creates a secret parameter that reads from Cloud Secret Manager.
SecretParam defineSecret(String name) => SecretParam(name, null);

/// Creates a boolean parameter.
BooleanParam defineBoolean(String name, [ParamOptions<bool>? options]) =>
    BooleanParam(name, options);

/// Creates an integer parameter.
IntParam defineInt(String name, [ParamOptions<int>? options]) =>
    IntParam(name, options);

/// Creates a double parameter.
DoubleParam defineDouble(String name, [ParamOptions<double>? options]) =>
    DoubleParam(name, options);

/// Creates a string parameter.
StringParam defineString(String name, [ParamOptions<String>? options]) =>
    StringParam(name, options);

/// Creates a string list parameter.
ListParam defineList(String name, [ParamOptions<List<String>>? options]) =>
    ListParam(name, options);

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

/// Abstract base class for all parameters.
///
/// Parameters are configuration values that can be set at deploy time
/// and accessed at runtime via environment variables.
abstract class Param<T extends Object> extends Expression<T> {
  const Param(this.name, this.options);
  final String name;
  final ParamOptions<T>? options;

  @override
  T runtimeValue();

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

/// A secret parameter stored in Cloud Secret Manager.
///
/// Secret values are not stored in environment variables but accessed
/// securely via the Secret Manager API.
class SecretParam extends Param<String> {
  const SecretParam(super.name, super.options);

  @override
  String runtimeValue() {
    // In emulator mode, secrets may be provided as env vars
    return String.fromEnvironment(
      name,
      defaultValue: options?.defaultValue ?? '',
    );
  }

  @override
  String value() => runtimeValue();
}

/// A string parameter.
class StringParam extends Param<String> {
  const StringParam(super.name, super.options);

  @override
  String runtimeValue() => String.fromEnvironment(
        name,
        defaultValue: options?.defaultValue ?? '',
      );
}

/// An integer parameter.
class IntParam extends Param<int> {
  const IntParam(super.name, super.options);

  @override
  int runtimeValue() => int.fromEnvironment(
        name,
        defaultValue: options?.defaultValue ?? 0,
      );
}

/// A double parameter.
class DoubleParam extends Param<double> {
  const DoubleParam(super.name, super.options);

  @override
  double runtimeValue() {
    // Dart doesn't have double.fromEnvironment, so we parse it
    final envValue = String.fromEnvironment(name);
    if (envValue.isEmpty) {
      return options?.defaultValue ?? 0.0;
    }
    return double.tryParse(envValue) ?? options?.defaultValue ?? 0.0;
  }
}

/// A boolean parameter.
class BooleanParam extends Param<bool> {
  const BooleanParam(super.name, super.options);

  @override
  bool runtimeValue() => bool.fromEnvironment(
        name,
        defaultValue: options?.defaultValue ?? false,
      );
}

/// A string list parameter.
class ListParam extends Param<List<String>> {
  const ListParam(super.name, super.options);

  @override
  List<String> runtimeValue() {
    if (!bool.hasEnvironment(name)) {
      return options?.defaultValue ?? [];
    }

    final val = String.fromEnvironment(name);
    if (val.isEmpty) {
      return options?.defaultValue ?? [];
    }

    try {
      final parsed = jsonDecode(val);
      if (parsed is List && parsed.every((v) => v is String)) {
        return List<String>.from(parsed);
      }
    } on FormatException {
      // Invalid JSON, return default
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
