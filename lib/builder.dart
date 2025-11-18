/// Build-time code generator for Firebase Functions.
///
/// This builder analyzes Dart source code to discover function declarations
/// and their configurations, then generates a functions.yaml manifest that
/// firebase-tools uses for deployment.
///
/// See BUILDER_SYSTEM.md for detailed documentation.
library builder;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

// Import types for TypeChecker
import 'firebase_functions.dart' as ff;

/// Builder factory function (called by build_runner).
Builder specBuilder(BuilderOptions options) => _SpecBuilder();

/// Type checkers for Firebase Functions types.
class _TypeCheckers {
  static final httpsNamespace = TypeChecker.fromRuntime(ff.HttpsNamespace);
  static final pubsubNamespace = TypeChecker.fromRuntime(ff.PubSubNamespace);
}

/// The main builder that generates functions.yaml.
class _SpecBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {
        r'$package$': ['.dart_tool/firebase/functions.yaml'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;

    // Find all Dart files in the package
    final assets = await buildStep.findAssets(Glob('**.dart')).toSet();

    final allParams = <String, _ParamSpec>{};
    final allEndpoints = <String, _EndpointSpec>{};

    // Process each Dart file
    for (final asset in assets) {
      // Only process files in this package
      if (asset.package != buildStep.inputId.package) continue;

      // Try to get the library (skip part files)
      LibraryElement? library;
      try {
        library = await resolver.libraryFor(asset, allowSyntaxErrors: true);
      } catch (e) {
        // Likely a part file, skip it
        continue;
      }

      // Skip if it's a part file (no defining compilation unit)
      final unit = library.definingCompilationUnit;

      // Get the AST for this library
      final ast = await resolver.astNodeFor(
        unit,
        resolve: true,
      );

      if (ast == null) continue;

      // Visit the AST to find function declarations
      final visitor = _FirebaseFunctionsVisitor(resolver);
      ast.accept(visitor);

      // Collect discovered functions and parameters
      allParams.addAll(visitor.params);
      allEndpoints.addAll(visitor.endpoints);
    }

    // Generate YAML from collected data
    final yamlContent = _generateYaml(allParams, allEndpoints);

    // Write the YAML file
    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, '.dart_tool/firebase/functions.yaml'),
      yamlContent,
    );
  }
}

/// AST visitor that discovers Firebase Functions declarations.
class _FirebaseFunctionsVisitor extends RecursiveAstVisitor<void> {
  _FirebaseFunctionsVisitor(this.resolver);
  final Resolver resolver;
  final Map<String, _ParamSpec> params = {};
  final Map<String, _EndpointSpec> endpoints = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    final methodName = node.methodName.name;

    // Check for HTTPS function declarations
    if (target != null && _isHttpsNamespace(target)) {
      if (methodName == 'onRequest' ||
          methodName == 'onCall' ||
          methodName == 'onCallWithData') {
        _extractHttpsFunction(node, methodName);
      }
    }

    // Check for Pub/Sub function declarations
    if (target != null && _isPubSubNamespace(target)) {
      if (methodName == 'onMessagePublished') {
        _extractPubSubFunction(node);
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final function = node.function;
    if (function is SimpleIdentifier) {
      final functionName = function.name;

      // Check for parameter definitions
      if (_isParamDefinition(functionName)) {
        _extractParameter(node, functionName);
      }
    }

    super.visitFunctionExpressionInvocation(node);
  }

  /// Checks if the target is firebase.https.
  bool _isHttpsNamespace(Expression target) {
    final staticType = target.staticType;
    if (staticType == null) return false;
    return _TypeCheckers.httpsNamespace.isExactlyType(staticType);
  }

  /// Checks if the target is firebase.pubsub.
  bool _isPubSubNamespace(Expression target) {
    final staticType = target.staticType;
    if (staticType == null) return false;
    return _TypeCheckers.pubsubNamespace.isExactlyType(staticType);
  }

  /// Checks if this is a parameter definition function.
  bool _isParamDefinition(String name) =>
      name == 'defineString' ||
      name == 'defineInt' ||
      name == 'defineDouble' ||
      name == 'defineBoolean' ||
      name == 'defineList' ||
      name == 'defineSecret';

  /// Extracts an HTTPS function declaration.
  void _extractHttpsFunction(MethodInvocation node, String methodName) {
    // Extract function name from named argument
    final nameArg = _findNamedArg(node, 'name');
    if (nameArg == null) return;

    final functionName = _extractStringLiteral(nameArg);
    if (functionName == null) return;

    // Extract options if present
    final optionsArg = _findNamedArg(node, 'options');

    // Determine trigger type
    final triggerType = methodName == 'onRequest' ? 'https' : 'callable';

    endpoints[functionName] = _EndpointSpec(
      name: functionName,
      type: triggerType,
      options: optionsArg as InstanceCreationExpression?,
    );
  }

  /// Extracts a Pub/Sub function declaration.
  void _extractPubSubFunction(MethodInvocation node) {
    // Extract topic name from named argument
    final topicArg = _findNamedArg(node, 'topic');
    if (topicArg == null) return;

    final topicName = _extractStringLiteral(topicArg);
    if (topicName == null) return;

    // Generate function name from topic (replace hyphens with underscores)
    final sanitizedTopic = topicName.replaceAll('-', '_');
    final functionName = 'onMessagePublished_$sanitizedTopic';

    // Extract options if present
    final optionsArg = _findNamedArg(node, 'options');

    endpoints[functionName] = _EndpointSpec(
      name: functionName,
      type: 'pubsub',
      topic: topicName, // Keep original topic name for eventFilters
      options: optionsArg as InstanceCreationExpression?,
    );
  }

  /// Extracts a parameter definition.
  void _extractParameter(
    FunctionExpressionInvocation node,
    String functionName,
  ) {
    final args = node.argumentList.arguments;
    if (args.isEmpty) return;

    // First argument is the parameter name
    final nameArg = args.first;
    final paramName = _extractStringLiteral(nameArg);
    if (paramName == null) return;

    // Second argument is optional ParamOptions
    _ParamOptions? paramOptions;
    if (args.length > 1 && args[1] is InstanceCreationExpression) {
      paramOptions = _extractParamOptions(
        args[1] as InstanceCreationExpression,
      );
    }

    final paramType = _getParamType(functionName);
    params[paramName] = _ParamSpec(
      name: paramName,
      type: paramType,
      options: paramOptions,
    );
  }

  /// Finds a named argument in a method invocation.
  Expression? _findNamedArg(MethodInvocation node, String name) =>
      node.argumentList.arguments
          .whereType<NamedExpression>()
          .where((e) => e.name.label.name == name)
          .map((e) => e.expression)
          .firstOrNull;

  /// Extracts a string literal value.
  String? _extractStringLiteral(Expression expression) {
    if (expression is StringLiteral) {
      return expression.stringValue;
    }
    return null;
  }

  /// Gets the parameter type name for YAML.
  String _getParamType(String functionName) => switch (functionName) {
        'defineString' || 'defineSecret' => 'string',
        'defineInt' => 'int',
        'defineDouble' => 'float',
        'defineBoolean' => 'boolean',
        'defineList' => 'list',
        _ => 'string',
      };

  /// Extracts ParamOptions from an InstanceCreationExpression.
  _ParamOptions? _extractParamOptions(InstanceCreationExpression node) =>
      _ParamOptions(
        defaultValue: _extractDefaultValue(node),
        label: _extractStringField(node, 'label'),
        description: _extractStringField(node, 'description'),
      );

  /// Extracts the defaultValue field.
  dynamic _extractDefaultValue(InstanceCreationExpression node) {
    final defaultValueArg = node.argumentList.arguments
        .whereType<NamedExpression>()
        .where((e) => e.name.label.name == 'defaultValue')
        .map((e) => e.expression)
        .firstOrNull;

    if (defaultValueArg == null) return null;

    return _extractConstValue(defaultValueArg);
  }

  /// Extracts a string field from options.
  String? _extractStringField(
    InstanceCreationExpression node,
    String fieldName,
  ) =>
      node.argumentList.arguments
          .whereType<NamedExpression>()
          .where((e) => e.name.label.name == fieldName)
          .map((e) => e.expression)
          .whereType<StringLiteral>()
          .map((e) => e.stringValue!)
          .firstOrNull;

  /// Extracts a constant value from an expression.
  dynamic _extractConstValue(Expression expression) {
    if (expression is StringLiteral) {
      return expression.stringValue;
    } else if (expression is IntegerLiteral) {
      return expression.value;
    } else if (expression is DoubleLiteral) {
      return expression.value;
    } else if (expression is BooleanLiteral) {
      return expression.value;
    } else if (expression is ListLiteral) {
      return expression.elements
          .whereType<Expression>()
          .map(_extractConstValue)
          .whereType<dynamic>()
          .toList();
    }
    return null;
  }
}

/// Specification for a parameter.
class _ParamSpec {
  _ParamSpec({required this.name, required this.type, this.options});
  final String name;
  final String type;
  final _ParamOptions? options;
}

/// Options for a parameter.
class _ParamOptions {
  _ParamOptions({this.defaultValue, this.label, this.description});
  final dynamic defaultValue;
  final String? label;
  final String? description;
}

/// Specification for an endpoint (function).
class _EndpointSpec {
  _EndpointSpec({
    required this.name,
    required this.type,
    this.topic,
    this.options,
  });
  final String name;
  final String type; // 'https', 'callable', 'pubsub'
  final String? topic; // For Pub/Sub functions
  final InstanceCreationExpression? options;

  /// Extracts options configuration from the AST.
  Map<String, dynamic> extractOptions() {
    if (options == null) return {};

    final result = <String, dynamic>{};

    // Iterate through all named constructor arguments
    for (final arg in options!.argumentList.arguments) {
      if (arg is! NamedExpression) continue;

      final fieldName = arg.name.label.name;
      final expression = arg.expression;

      // Map Dart field names to YAML keys and extract values
      switch (fieldName) {
        case 'memory':
          final value = _extractMemory(expression);
          if (value != null) result['availableMemoryMb'] = value;
          break;

        case 'cpu':
          final value = _extractCpu(expression);
          if (value != null) result['cpu'] = value;
          break;

        case 'region':
          final value = _extractRegion(expression);
          if (value != null) result['region'] = value;
          break;

        case 'timeoutSeconds':
          final value = _extractTimeoutSeconds(expression);
          if (value != null) result['timeoutSeconds'] = value;
          break;

        case 'minInstances':
          final value = _extractInt(expression);
          if (value != null) result['minInstances'] = value;
          break;

        case 'maxInstances':
          final value = _extractInt(expression);
          if (value != null) result['maxInstances'] = value;
          break;

        case 'concurrency':
          final value = _extractInt(expression);
          if (value != null) result['concurrency'] = value;
          break;

        case 'serviceAccount':
          final value = _extractString(expression);
          if (value != null) result['serviceAccount'] = value;
          break;

        case 'vpcConnector':
          final value = _extractString(expression);
          if (value != null) result['vpcConnector'] = value;
          break;

        case 'vpcConnectorEgressSettings':
          final value = _extractVpcEgressSettings(expression);
          if (value != null) result['vpcConnectorEgressSettings'] = value;
          break;

        case 'ingressSettings':
          final value = _extractIngressSettings(expression);
          if (value != null) result['ingressSettings'] = value;
          break;

        case 'invoker':
          final value = _extractInvoker(expression);
          if (value != null) result['invoker'] = value;
          break;

        case 'secrets':
          final value = _extractSecrets(expression);
          if (value != null) result['secretEnvironmentVariables'] = value;
          break;

        case 'labels':
          final value = _extractLabels(expression);
          if (value != null) result['labels'] = value;
          break;

        case 'cors':
          final value = _extractCors(expression);
          if (value != null) result['cors'] = value;
          break;

        case 'enforceAppCheck':
          final value = _extractBool(expression);
          if (value != null) result['enforceAppCheck'] = value;
          break;
      }
    }

    return result;
  }

  /// Extracts Memory option value.
  dynamic _extractMemory(Expression expression) {
    if (expression is! InstanceCreationExpression) return null;

    // Check if it's Memory.param() - generate CEL
    if (expression.constructorName.name?.name == 'param') {
      return _extractParamReference(expression);
    }

    // Check if it's Memory.reset()
    if (expression.constructorName.name?.name == 'reset') {
      return null; // Reset means use default
    }

    // Extract literal value: Memory(MemoryOption.mb256)
    final args = expression.argumentList.arguments;
    if (args.isEmpty) return null;

    final firstArg = args.first;
    if (firstArg is PrefixedIdentifier) {
      // Handle MemoryOption.mb256
      final propertyName = firstArg.identifier.name;
      return _memoryOptionToInt(propertyName);
    }

    return null;
  }

  /// Converts MemoryOption enum to integer value.
  int? _memoryOptionToInt(String optionName) => switch (optionName) {
        'mb128' => 128,
        'mb256' => 256,
        'mb512' => 512,
        'gb1' => 1024,
        'gb2' => 2048,
        'gb4' => 4096,
        'gb8' => 8192,
        'gb16' => 16384,
        'gb32' => 32768,
        _ => null,
      };

  /// Extracts CPU option value.
  dynamic _extractCpu(Expression expression) {
    if (expression is! InstanceCreationExpression) return null;

    // Check if it's Cpu.gcfGen1()
    if (expression.constructorName.name?.name == 'gcfGen1') {
      return 'gcf_gen1';
    }

    // Check if it's Cpu.param() - generate CEL
    if (expression.constructorName.name?.name == 'param') {
      return _extractParamReference(expression);
    }

    // Check if it's Cpu.reset()
    if (expression.constructorName.name?.name == 'reset') {
      return null;
    }

    // Extract literal double value: Cpu(1.0)
    final args = expression.argumentList.arguments;
    if (args.isEmpty) return null;

    final firstArg = args.first;
    if (firstArg is DoubleLiteral) {
      return firstArg.value;
    } else if (firstArg is IntegerLiteral) {
      return firstArg.value;
    }

    return null;
  }

  /// Extracts Region option value.
  dynamic _extractRegion(Expression expression) {
    if (expression is! InstanceCreationExpression) return null;

    // Check if it's Region.param() - generate CEL
    if (expression.constructorName.name?.name == 'param') {
      return _extractParamReference(expression);
    }

    // Extract literal value: Region(SupportedRegion.usCentral1)
    final args = expression.argumentList.arguments;
    if (args.isEmpty) return null;

    final firstArg = args.first;
    if (firstArg is PrefixedIdentifier) {
      // Handle SupportedRegion.usCentral1
      final propertyName = firstArg.identifier.name;
      return [_regionEnumToString(propertyName)];
    }

    return null;
  }

  /// Converts SupportedRegion enum to string value.
  String? _regionEnumToString(String enumName) {
    // Convert camelCase to kebab-case
    return switch (enumName) {
      'asiaEast1' => 'asia-east1',
      'asiaEast2' => 'asia-east2',
      'asiaNortheast1' => 'asia-northeast1',
      'asiaNortheast2' => 'asia-northeast2',
      'asiaNortheast3' => 'asia-northeast3',
      'asiaSouth1' => 'asia-south1',
      'asiaSoutheast1' => 'asia-southeast1',
      'asiaSoutheast2' => 'asia-southeast2',
      'australiaSoutheast1' => 'australia-southeast1',
      'europeCentral2' => 'europe-central2',
      'europeNorth1' => 'europe-north1',
      'europeWest1' => 'europe-west1',
      'europeWest2' => 'europe-west2',
      'europeWest3' => 'europe-west3',
      'europeWest4' => 'europe-west4',
      'europeWest6' => 'europe-west6',
      'northAmericaNortheast1' => 'northamerica-northeast1',
      'southAmericaEast1' => 'southamerica-east1',
      'usCentral1' => 'us-central1',
      'usEast1' => 'us-east1',
      'usEast4' => 'us-east4',
      'usWest1' => 'us-west1',
      'usWest2' => 'us-west2',
      'usWest3' => 'us-west3',
      'usWest4' => 'us-west4',
      _ => null,
    };
  }

  /// Extracts timeout seconds.
  dynamic _extractTimeoutSeconds(Expression expression) =>
      _extractInt(expression);

  /// Extracts integer option value.
  dynamic _extractInt(Expression expression) {
    if (expression is IntegerLiteral) {
      return expression.value;
    }

    if (expression is InstanceCreationExpression) {
      // Check if it's Option.param() - generate CEL
      if (expression.constructorName.name?.name == 'param') {
        return _extractParamReference(expression);
      }

      // Extract literal: Option(123)
      final args = expression.argumentList.arguments;
      if (args.isNotEmpty && args.first is IntegerLiteral) {
        return (args.first as IntegerLiteral).value;
      }
    }

    return null;
  }

  /// Extracts string option value.
  dynamic _extractString(Expression expression) {
    if (expression is StringLiteral) {
      return expression.stringValue;
    }

    if (expression is InstanceCreationExpression) {
      // Check if it's Option.param() - generate CEL
      if (expression.constructorName.name?.name == 'param') {
        return _extractParamReference(expression);
      }

      // Extract literal: Option('value')
      final args = expression.argumentList.arguments;
      if (args.isNotEmpty && args.first is StringLiteral) {
        return (args.first as StringLiteral).stringValue;
      }
    }

    return null;
  }

  /// Extracts boolean option value.
  dynamic _extractBool(Expression expression) {
    if (expression is BooleanLiteral) {
      return expression.value;
    }

    if (expression is InstanceCreationExpression) {
      // Check if it's Option.param() - generate CEL
      if (expression.constructorName.name?.name == 'param') {
        return _extractParamReference(expression);
      }

      // Extract literal: Option(true)
      final args = expression.argumentList.arguments;
      if (args.isNotEmpty && args.first is BooleanLiteral) {
        return (args.first as BooleanLiteral).value;
      }
    }

    return null;
  }

  /// Extracts VPC egress settings.
  dynamic _extractVpcEgressSettings(Expression expression) {
    if (expression is! InstanceCreationExpression) return null;

    final args = expression.argumentList.arguments;
    if (args.isEmpty) return null;

    final firstArg = args.first;
    if (firstArg is PrefixedIdentifier) {
      // Handle VpcEgressSetting enum
      final propertyName = firstArg.identifier.name;
      return switch (propertyName) {
        'privateRangesOnly' => 'PRIVATE_RANGES_ONLY',
        'allTraffic' => 'ALL_TRAFFIC',
        _ => null,
      };
    }

    return null;
  }

  /// Extracts ingress settings.
  dynamic _extractIngressSettings(Expression expression) {
    if (expression is! InstanceCreationExpression) return null;

    final args = expression.argumentList.arguments;
    if (args.isEmpty) return null;

    final firstArg = args.first;
    if (firstArg is PrefixedIdentifier) {
      // Handle IngressSetting enum
      final propertyName = firstArg.identifier.name;
      return switch (propertyName) {
        'allowAll' => 'ALLOW_ALL',
        'allowInternalOnly' => 'ALLOW_INTERNAL_ONLY',
        'allowInternalAndGclb' => 'ALLOW_INTERNAL_AND_GCLB',
        _ => null,
      };
    }

    return null;
  }

  /// Extracts invoker list.
  dynamic _extractInvoker(Expression expression) {
    if (expression is! InstanceCreationExpression) return null;

    // Check for special factories
    if (expression.constructorName.name?.name == 'public') {
      return ['public'];
    }
    if (expression.constructorName.name?.name == 'private') {
      return ['private'];
    }

    // Extract literal list
    final args = expression.argumentList.arguments;
    if (args.isEmpty) return null;

    final firstArg = args.first;
    if (firstArg is ListLiteral) {
      return firstArg.elements
          .whereType<StringLiteral>()
          .map((e) => e.stringValue)
          .toList();
    }

    return null;
  }

  /// Extracts secrets list.
  dynamic _extractSecrets(Expression expression) {
    if (expression is! ListLiteral) return null;

    final secrets = <String>[];
    for (final element in expression.elements) {
      if (element is Expression) {
        final secretName = _extractSecretName(element);
        if (secretName != null) secrets.add(secretName);
      }
    }

    return secrets.isEmpty ? null : secrets;
  }

  /// Extracts secret name from SecretParam instance.
  String? _extractSecretName(Expression expression) {
    if (expression is! SimpleIdentifier) return null;

    // The identifier references a SecretParam variable
    // We need to find its definition, but for now just use the variable name
    return expression.name;
  }

  /// Extracts labels map.
  dynamic _extractLabels(Expression expression) {
    if (expression is! SetOrMapLiteral) return null;
    if (!expression.isMap) return null;

    final labels = <String, String>{};
    for (final element in expression.elements) {
      if (element is MapLiteralEntry) {
        final key = element.key;
        final value = element.value;

        if (key is StringLiteral && value is StringLiteral) {
          labels[key.stringValue!] = value.stringValue!;
        }
      }
    }

    return labels.isEmpty ? null : labels;
  }

  /// Extracts CORS configuration.
  dynamic _extractCors(Expression expression) {
    if (expression is! InstanceCreationExpression) return null;

    final args = expression.argumentList.arguments;
    if (args.isEmpty) return null;

    final firstArg = args.first;
    if (firstArg is ListLiteral) {
      final origins = firstArg.elements
          .whereType<StringLiteral>()
          .map((e) => e.stringValue)
          .toList();
      return origins.isEmpty ? null : origins;
    }

    return null;
  }

  /// Extracts parameter reference and generates CEL expression.
  String _extractParamReference(InstanceCreationExpression expression) {
    final args = expression.argumentList.arguments;
    if (args.isEmpty) return '{{ params.UNKNOWN }}';

    final firstArg = args.first;
    if (firstArg is SimpleIdentifier) {
      // Convert parameter variable name to PARAM_NAME format
      final paramName = _toParamName(firstArg.name);
      return '{{ params.$paramName }}';
    }

    return '{{ params.UNKNOWN }}';
  }

  /// Converts a variable name to PARAM_NAME format.
  String _toParamName(String variableName) {
    // Convert camelCase to UPPER_SNAKE_CASE
    return variableName
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)}',
        )
        .toUpperCase()
        .replaceFirst('_', '');
  }
}

/// Generates the YAML content.
String _generateYaml(
  Map<String, _ParamSpec> params,
  Map<String, _EndpointSpec> endpoints,
) {
  final buffer = StringBuffer();

  buffer.writeln('specVersion: "v1alpha1"');
  buffer.writeln();

  // Generate params section
  if (params.isNotEmpty) {
    buffer.writeln('params:');
    for (final param in params.values) {
      buffer.writeln('  - name: "${param.name}"');
      buffer.writeln('    type: "${param.type}"');
      if (param.options?.defaultValue != null) {
        buffer.writeln(
          '    default: ${_yamlValue(param.options!.defaultValue)}',
        );
      }
      if (param.options?.label != null) {
        buffer.writeln('    label: "${param.options!.label}"');
      }
      if (param.options?.description != null) {
        buffer.writeln('    description: "${param.options!.description}"');
      }
    }
    buffer.writeln();
  }

  // Generate requiredAPIs section
  buffer.writeln('requiredAPIs:');
  buffer.writeln('  - api: "cloudfunctions.googleapis.com"');
  buffer.writeln('    reason: "Required for Cloud Functions"');
  buffer.writeln();

  // Generate endpoints section
  if (endpoints.isNotEmpty) {
    buffer.writeln('endpoints:');
    for (final endpoint in endpoints.values) {
      buffer.writeln('  ${endpoint.name}:');
      buffer.writeln('    entryPoint: "${endpoint.name}"');
      buffer.writeln('    platform: "gcfv2"');

      // Extract and add options
      final options = endpoint.extractOptions();

      // Add region (use extracted value or default)
      if (options.containsKey('region')) {
        buffer.writeln('    region:');
        final regions = options['region'] as List<String>;
        for (final region in regions) {
          buffer.writeln('      - "$region"');
        }
      } else {
        buffer.writeln('    region:');
        buffer.writeln('      - "us-central1"');
      }

      // Add memory if specified
      if (options.containsKey('availableMemoryMb')) {
        buffer
            .writeln('    availableMemoryMb: ${options['availableMemoryMb']}');
      }

      // Add CPU if specified
      if (options.containsKey('cpu')) {
        final cpu = options['cpu'];
        if (cpu is String) {
          buffer.writeln('    cpu: "$cpu"');
        } else {
          buffer.writeln('    cpu: $cpu');
        }
      }

      // Add timeout if specified
      if (options.containsKey('timeoutSeconds')) {
        buffer.writeln('    timeoutSeconds: ${options['timeoutSeconds']}');
      }

      // Add concurrency if specified
      if (options.containsKey('concurrency')) {
        buffer.writeln('    concurrency: ${options['concurrency']}');
      }

      // Add min/max instances
      if (options.containsKey('minInstances')) {
        buffer.writeln('    minInstances: ${options['minInstances']}');
      }
      if (options.containsKey('maxInstances')) {
        buffer.writeln('    maxInstances: ${options['maxInstances']}');
      }

      // Add service account if specified
      if (options.containsKey('serviceAccount')) {
        buffer.writeln('    serviceAccount: "${options['serviceAccount']}"');
      }

      // Add VPC connector if specified
      if (options.containsKey('vpcConnector')) {
        buffer.writeln('    vpcConnector: "${options['vpcConnector']}"');
      }

      // Add VPC egress settings if specified
      if (options.containsKey('vpcConnectorEgressSettings')) {
        buffer.writeln(
          '    vpcConnectorEgressSettings: "${options['vpcConnectorEgressSettings']}"',
        );
      }

      // Add ingress settings if specified
      if (options.containsKey('ingressSettings')) {
        buffer.writeln('    ingressSettings: "${options['ingressSettings']}"');
      }

      // Add labels if specified
      if (options.containsKey('labels')) {
        buffer.writeln('    labels:');
        final labels = options['labels'] as Map<String, String>;
        for (final entry in labels.entries) {
          buffer.writeln('      ${entry.key}: "${entry.value}"');
        }
      }

      // Add secrets if specified
      if (options.containsKey('secretEnvironmentVariables')) {
        buffer.writeln('    secretEnvironmentVariables:');
        final secrets = options['secretEnvironmentVariables'] as List<String>;
        for (final secret in secrets) {
          buffer.writeln('      - key: "$secret"');
          buffer.writeln('        secret: "$secret"');
        }
      }

      // Add trigger configuration
      if (endpoint.type == 'https') {
        buffer.writeln('    httpsTrigger:');

        // Add invoker
        if (options.containsKey('invoker')) {
          final invokers = options['invoker'] as List<String>;
          if (invokers.isEmpty) {
            buffer.writeln('      invoker: []');
          } else {
            buffer.writeln('      invoker:');
            for (final inv in invokers) {
              buffer.writeln('        - "$inv"');
            }
          }
        } else {
          buffer.writeln('      invoker: []');
        }

        // Add CORS if specified
        if (options.containsKey('cors')) {
          final cors = options['cors'] as List<String>;
          buffer.writeln('      cors:');
          for (final origin in cors) {
            buffer.writeln('        - "$origin"');
          }
        }
      } else if (endpoint.type == 'callable') {
        buffer.writeln('    callableTrigger: {}');

        // Add enforceAppCheck if specified
        if (options.containsKey('enforceAppCheck')) {
          buffer.writeln('    enforceAppCheck: ${options['enforceAppCheck']}');
        }
      } else if (endpoint.type == 'pubsub' && endpoint.topic != null) {
        buffer.writeln('    eventTrigger:');
        buffer.writeln(
          '      eventType: "google.cloud.pubsub.topic.v1.messagePublished"',
        );
        buffer.writeln('      eventFilters:');
        buffer.writeln('        topic: "${endpoint.topic}"');
        buffer.writeln('      retry: false');
      }
    }
  }

  return buffer.toString();
}

/// Converts a value to YAML format.
String _yamlValue(dynamic value) {
  if (value is String) {
    return '"$value"';
  } else if (value is num || value is bool) {
    return value.toString();
  } else if (value is List) {
    return '[${value.map(_yamlValue).join(", ")}]';
  }
  return value.toString();
}
