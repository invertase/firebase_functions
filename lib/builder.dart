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
  static final firestoreNamespace =
      TypeChecker.fromRuntime(ff.FirestoreNamespace);
  static final databaseNamespace =
      TypeChecker.fromRuntime(ff.DatabaseNamespace);
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

  /// Maps variable names to their actual parameter names.
  /// e.g., 'minInstances' -> 'MIN_INSTANCES'
  final Map<String, String> _variableToParamName = {};

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

    // Check for Firestore function declarations
    if (target != null && _isFirestoreNamespace(target)) {
      if (methodName == 'onDocumentCreated' ||
          methodName == 'onDocumentUpdated' ||
          methodName == 'onDocumentDeleted' ||
          methodName == 'onDocumentWritten') {
        _extractFirestoreFunction(node, methodName);
      }
    }

    // Check for Database function declarations
    if (target != null && _isDatabaseNamespace(target)) {
      if (methodName == 'onValueCreated' ||
          methodName == 'onValueUpdated' ||
          methodName == 'onValueDeleted' ||
          methodName == 'onValueWritten') {
        _extractDatabaseFunction(node, methodName);
      }
    }

    // Check for parameter definitions (top-level function calls with no target)
    if (target == null && _isParamDefinition(methodName)) {
      _extractParameterFromMethod(node, methodName);
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

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    // Track variable declarations for param definitions
    for (final variable in node.variables.variables) {
      final initializer = variable.initializer;

      // Handle top-level function calls like defineInt(...), defineString(...)
      // These can be either FunctionExpressionInvocation or MethodInvocation
      String? functionName;
      ArgumentList? argList;

      if (initializer is FunctionExpressionInvocation) {
        final function = initializer.function;
        if (function is SimpleIdentifier) {
          functionName = function.name;
          argList = initializer.argumentList;
        }
      } else if (initializer is MethodInvocation &&
          initializer.target == null) {
        // Top-level function call (no target)
        functionName = initializer.methodName.name;
        argList = initializer.argumentList;
      }

      if (functionName != null &&
          argList != null &&
          _isParamDefinition(functionName)) {
        // Extract the param name from the first argument
        final args = argList.arguments;
        if (args.isNotEmpty) {
          // Handle defineEnumList differently - it derives name from enum type
          if (functionName == 'defineEnumList') {
            final valuesArg = args.first;
            String? paramName;
            if (valuesArg is PrefixedIdentifier) {
              final enumTypeName = valuesArg.prefix.name;
              paramName = '${_toUpperSnakeCase(enumTypeName)}_LIST';
            } else if (valuesArg is PropertyAccess) {
              final target = valuesArg.target;
              if (target is SimpleIdentifier) {
                paramName = '${_toUpperSnakeCase(target.name)}_LIST';
              }
            }
            if (paramName != null) {
              _variableToParamName[variable.name.lexeme] = paramName;
            }
          } else {
            final nameArg = args.first;
            final paramName = _extractStringLiteral(nameArg);
            if (paramName != null) {
              // Map variable name to actual param name
              _variableToParamName[variable.name.lexeme] = paramName;
            }
          }
        }
      }
    }
    super.visitTopLevelVariableDeclaration(node);
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

  /// Checks if the target is firebase.firestore.
  bool _isFirestoreNamespace(Expression target) {
    final staticType = target.staticType;
    if (staticType == null) return false;
    return _TypeCheckers.firestoreNamespace.isExactlyType(staticType);
  }

  /// Checks if the target is firebase.database.
  bool _isDatabaseNamespace(Expression target) {
    final staticType = target.staticType;
    if (staticType == null) return false;
    return _TypeCheckers.databaseNamespace.isExactlyType(staticType);
  }

  /// Checks if this is a parameter definition function.
  bool _isParamDefinition(String name) =>
      name == 'defineString' ||
      name == 'defineInt' ||
      name == 'defineDouble' ||
      name == 'defineFloat' ||
      name == 'defineBoolean' ||
      name == 'defineList' ||
      name == 'defineEnumList' ||
      name == 'defineSecret' ||
      name == 'defineJsonSecret';

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
      options: optionsArg is InstanceCreationExpression ? optionsArg : null,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a Pub/Sub function declaration.
  void _extractPubSubFunction(MethodInvocation node) {
    // Extract topic name from named argument
    final topicArg = _findNamedArg(node, 'topic');
    if (topicArg == null) return;

    final topicName = _extractStringLiteral(topicArg);
    if (topicName == null) return;

    // Generate function name from topic (remove hyphens to match Node.js behavior)
    final sanitizedTopic = topicName.replaceAll('-', '');
    final functionName = 'onMessagePublished_$sanitizedTopic';

    // Extract options if present
    final optionsArg = _findNamedArg(node, 'options');

    endpoints[functionName] = _EndpointSpec(
      name: functionName,
      type: 'pubsub',
      topic: topicName, // Keep original topic name for eventFilters
      options: optionsArg is InstanceCreationExpression ? optionsArg : null,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a Firestore function declaration.
  void _extractFirestoreFunction(MethodInvocation node, String methodName) {
    // Extract document path from named argument
    final documentArg = _findNamedArg(node, 'document');
    if (documentArg == null) return;

    final documentPath = _extractStringLiteral(documentArg);
    if (documentPath == null) return;

    // Extract options if present (for database and namespace)
    final optionsArg = _findNamedArg(node, 'options');
    String? database;
    String? namespace;

    if (optionsArg is InstanceCreationExpression) {
      database = _extractStringField(optionsArg, 'database');
      namespace = _extractStringField(optionsArg, 'namespace');
    }

    // Generate function name from document path and event type
    // Similar to how we do it in firestore_namespace.dart
    final sanitizedPath = documentPath
        .replaceAll('/', '_')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('-', '');
    final functionName = '${methodName}_$sanitizedPath';

    endpoints[functionName] = _EndpointSpec(
      name: functionName,
      type: 'firestore',
      firestoreEventType: methodName,
      documentPath: documentPath,
      database: database ?? '(default)',
      namespace: namespace ?? '(default)',
      options: optionsArg is InstanceCreationExpression ? optionsArg : null,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a Database function declaration.
  void _extractDatabaseFunction(MethodInvocation node, String methodName) {
    // Extract ref path from named argument
    final refArg = _findNamedArg(node, 'ref');
    if (refArg == null) return;

    final refPath = _extractStringLiteral(refArg);
    if (refPath == null) return;

    // Extract options if present (for instance)
    final optionsArg = _findNamedArg(node, 'options');
    String? instance;

    if (optionsArg is InstanceCreationExpression) {
      instance = _extractStringField(optionsArg, 'instance');
    }

    // Generate function name from ref path and event type
    // Similar to how we do it in database_namespace.dart
    final sanitizedPath = refPath
        .replaceAll(RegExp(r'^/+|/+$'), '') // Remove leading/trailing slashes
        .replaceAll('/', '_')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('-', '');
    final functionName = '${methodName}_$sanitizedPath';

    endpoints[functionName] = _EndpointSpec(
      name: functionName,
      type: 'database',
      databaseEventType: methodName,
      refPath: refPath,
      instance: instance ?? '*',
      options: optionsArg is InstanceCreationExpression ? optionsArg : null,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a parameter definition from FunctionExpressionInvocation.
  void _extractParameter(
    FunctionExpressionInvocation node,
    String functionName,
  ) {
    _extractParamFromArgs(node.argumentList.arguments, functionName);
  }

  /// Extracts a parameter definition from MethodInvocation.
  void _extractParameterFromMethod(
    MethodInvocation node,
    String functionName,
  ) {
    _extractParamFromArgs(node.argumentList.arguments, functionName);
  }

  /// Common logic for extracting parameter definitions from arguments.
  void _extractParamFromArgs(NodeList<Expression> args, String functionName) {
    if (args.isEmpty) return;

    String? paramName;
    _ParamOptions? paramOptions;

    // Handle defineEnumList which has a different signature:
    // defineEnumList(EnumType.values, [ParamOptions])
    if (functionName == 'defineEnumList') {
      // First argument is the enum values (e.g., Region.values)
      final valuesArg = args.first;
      if (valuesArg is PrefixedIdentifier) {
        // Extract the enum type name from "EnumType.values"
        final enumTypeName = valuesArg.prefix.name;
        paramName = '${_toUpperSnakeCase(enumTypeName)}_LIST';
      } else if (valuesArg is PropertyAccess) {
        // Handle qualified access like mypackage.Region.values
        final target = valuesArg.target;
        if (target is PrefixedIdentifier) {
          paramName = '${_toUpperSnakeCase(target.identifier.name)}_LIST';
        } else if (target is SimpleIdentifier) {
          paramName = '${_toUpperSnakeCase(target.name)}_LIST';
        }
      }

      // Second argument is optional ParamOptions
      if (args.length > 1 && args[1] is InstanceCreationExpression) {
        paramOptions = _extractParamOptions(
          args[1] as InstanceCreationExpression,
        );
      }
    } else {
      // Standard parameter definitions: defineXxx('NAME', [ParamOptions])
      final nameArg = args.first;
      paramName = _extractStringLiteral(nameArg);

      // Second argument is optional ParamOptions (not used for secrets)
      if (args.length > 1 && args[1] is InstanceCreationExpression) {
        paramOptions = _extractParamOptions(
          args[1] as InstanceCreationExpression,
        );
      }
    }

    if (paramName == null) return;

    final paramType = _getParamType(functionName);
    final isJsonSecret = _isJsonSecret(functionName);

    params[paramName] = _ParamSpec(
      name: paramName,
      type: paramType,
      options: paramOptions,
      format: isJsonSecret ? 'json' : null,
    );
  }

  /// Converts a camelCase or PascalCase string to UPPER_SNAKE_CASE.
  String _toUpperSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)}',
        )
        .toUpperCase()
        .replaceFirst('_', '');
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
        'defineString' => 'string',
        'defineSecret' || 'defineJsonSecret' => 'secret',
        'defineInt' => 'int',
        'defineDouble' || 'defineFloat' => 'float',
        'defineBoolean' => 'boolean',
        'defineList' || 'defineEnumList' => 'list',
        _ => 'string',
      };

  /// Checks if the parameter is a JSON secret.
  bool _isJsonSecret(String functionName) => functionName == 'defineJsonSecret';

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
  _ParamSpec({
    required this.name,
    required this.type,
    this.options,
    this.format,
  });
  final String name;
  final String type;
  final _ParamOptions? options;
  final String? format; // 'json' for JSON secrets
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
    this.firestoreEventType,
    this.documentPath,
    this.database,
    this.namespace,
    this.databaseEventType,
    this.refPath,
    this.instance,
    this.options,
    this.variableToParamName = const {},
  });
  final String name;
  final String type; // 'https', 'callable', 'pubsub', 'firestore', 'database'
  final String? topic; // For Pub/Sub functions
  final String? firestoreEventType; // For Firestore: onDocumentCreated, etc.
  final String? documentPath; // For Firestore: users/{userId}
  final String? database; // For Firestore: (default) or database name
  final String? namespace; // For Firestore: (default) or namespace
  final String? databaseEventType; // For Database: onValueCreated, etc.
  final String? refPath; // For Database: /users/{userId}
  final String? instance; // For Database: database instance or '*'
  final InstanceCreationExpression? options;
  final Map<String, String> variableToParamName;

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

        case 'omit':
          final value = _extractBool(expression);
          if (value != null) result['omit'] = value;
          break;

        // Runtime-only options (not exported to manifest):
        // - cors: Handled by Functions Framework at runtime
        // - enforceAppCheck: Runtime App Check validation
        // - consumeAppCheckToken: Runtime App Check replay protection
        // - heartBeatIntervalSeconds: Runtime streaming keepalive
        // - preserveExternalChanges: Deployment behavior, not function config
        case 'cors':
        case 'enforceAppCheck':
        case 'preserveExternalChanges':
        case 'consumeAppCheckToken':
        case 'heartBeatIntervalSeconds':
          // Intentionally skip these - they're not in the manifest
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

    // Check if it's Memory.expression() - generate CEL from expression
    if (expression.constructorName.name?.name == 'expression') {
      final args = expression.argumentList.arguments;
      if (args.isNotEmpty) {
        return _extractCelExpression(args.first);
      }
      return null;
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
      final regionString = _regionEnumToString(propertyName);
      return regionString != null ? [regionString] : null;
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
          .whereType<String>() // Filter out nulls
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

  /// Extracts parameter reference and generates CEL expression.
  String _extractParamReference(InstanceCreationExpression expression) {
    final args = expression.argumentList.arguments;
    if (args.isEmpty) return '{{ params.UNKNOWN }}';

    final firstArg = args.first;
    if (firstArg is SimpleIdentifier) {
      // Look up the actual param name from the mapping
      final variableName = firstArg.name;
      final paramName =
          variableToParamName[variableName] ?? _toUpperSnakeCase(variableName);
      return '{{ params.$paramName }}';
    }

    return '{{ params.UNKNOWN }}';
  }

  /// Extracts a CEL expression from an expression argument.
  /// Handles thenElse (ternary) expressions on boolean params.
  String? _extractCelExpression(Expression expression) {
    // Handle method invocation like: isProduction.thenElse(2048, 512)
    if (expression is MethodInvocation) {
      final target = expression.target;
      final methodName = expression.methodName.name;

      if (methodName == 'thenElse' && target is SimpleIdentifier) {
        // Get the param name from the variable
        final variableName = target.name;
        final paramName = variableToParamName[variableName] ??
            _toUpperSnakeCase(variableName);

        // Extract the two arguments
        final args = expression.argumentList.arguments;
        if (args.length >= 2) {
          final trueValue = _extractLiteralValue(args[0]);
          final falseValue = _extractLiteralValue(args[1]);
          if (trueValue != null && falseValue != null) {
            return '{{ params.$paramName ? $trueValue : $falseValue }}';
          }
        }
      }
    }

    return null;
  }

  /// Extracts a literal value from an expression.
  dynamic _extractLiteralValue(Expression expression) {
    if (expression is IntegerLiteral) return expression.value;
    if (expression is DoubleLiteral) return expression.value;
    if (expression is StringLiteral) return '"${expression.stringValue}"';
    if (expression is BooleanLiteral) return expression.value;
    return null;
  }

  /// Converts a variable name to UPPER_SNAKE_CASE format.
  static String _toUpperSnakeCase(String variableName) {
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
      if (param.format != null) {
        buffer.writeln('    format: "${param.format}"');
      }
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
        buffer.writeln(
          '    availableMemoryMb: ${_formatOptionValue(options['availableMemoryMb'])}',
        );
      }

      // Add CPU if specified
      if (options.containsKey('cpu')) {
        buffer.writeln('    cpu: ${_formatOptionValue(options['cpu'])}');
      }

      // Add timeout if specified
      if (options.containsKey('timeoutSeconds')) {
        buffer.writeln(
          '    timeoutSeconds: ${_formatOptionValue(options['timeoutSeconds'])}',
        );
      }

      // Add concurrency if specified
      if (options.containsKey('concurrency')) {
        buffer.writeln(
          '    concurrency: ${_formatOptionValue(options['concurrency'])}',
        );
      }

      // Add min/max instances
      if (options.containsKey('minInstances')) {
        buffer.writeln(
          '    minInstances: ${_formatOptionValue(options['minInstances'])}',
        );
      }
      if (options.containsKey('maxInstances')) {
        buffer.writeln(
          '    maxInstances: ${_formatOptionValue(options['maxInstances'])}',
        );
      }

      // Add service account if specified (Node.js uses serviceAccountEmail)
      if (options.containsKey('serviceAccount')) {
        buffer
            .writeln('    serviceAccountEmail: "${options['serviceAccount']}"');
      }

      // Add VPC configuration if specified (nested structure like Node.js)
      if (options.containsKey('vpcConnector') ||
          options.containsKey('vpcConnectorEgressSettings')) {
        buffer.writeln('    vpc:');
        if (options.containsKey('vpcConnector')) {
          buffer.writeln('      connector: "${options['vpcConnector']}"');
        }
        if (options.containsKey('vpcConnectorEgressSettings')) {
          buffer.writeln(
            '      egressSettings: "${options['vpcConnectorEgressSettings']}"',
          );
        }
      }

      // Add ingress settings if specified
      if (options.containsKey('ingressSettings')) {
        buffer.writeln('    ingressSettings: "${options['ingressSettings']}"');
      }

      // Add omit if specified
      if (options.containsKey('omit')) {
        buffer.writeln('    omit: ${options['omit']}');
      }

      // Note: preserveExternalChanges is runtime-only, not in manifest

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

        // Note: CORS is runtime-only, not in manifest
      } else if (endpoint.type == 'callable') {
        buffer.writeln('    callableTrigger: {}');

        // Note: enforceAppCheck, consumeAppCheckToken, heartbeatSeconds are runtime-only, not in manifest
      } else if (endpoint.type == 'pubsub' && endpoint.topic != null) {
        buffer.writeln('    eventTrigger:');
        buffer.writeln(
          '      eventType: "google.cloud.pubsub.topic.v1.messagePublished"',
        );
        buffer.writeln('      eventFilters:');
        buffer.writeln('        topic: "${endpoint.topic}"');
        buffer.writeln('      retry: false');
      } else if (endpoint.type == 'firestore' &&
          endpoint.firestoreEventType != null &&
          endpoint.documentPath != null) {
        // Map Dart method name to Firestore CloudEvent type
        final eventType = _mapFirestoreEventType(endpoint.firestoreEventType!);

        buffer.writeln('    eventTrigger:');
        buffer.writeln('      eventType: "$eventType"');
        buffer.writeln('      eventFilters:');
        buffer
            .writeln('        database: "${endpoint.database ?? '(default)'}"');
        buffer.writeln(
          '        namespace: "${endpoint.namespace ?? '(default)'}"',
        );

        // Check if document path has wildcards
        final hasWildcards = endpoint.documentPath!.contains('{');
        if (hasWildcards) {
          buffer.writeln('      eventFilterPathPatterns:');
          buffer.writeln('        document: "${endpoint.documentPath}"');
        } else {
          buffer.writeln('        document: "${endpoint.documentPath}"');
        }

        buffer.writeln('      retry: false');
      } else if (endpoint.type == 'database' &&
          endpoint.databaseEventType != null &&
          endpoint.refPath != null) {
        // Map Dart method name to Database CloudEvent type
        final eventType = _mapDatabaseEventType(endpoint.databaseEventType!);

        buffer.writeln('    eventTrigger:');
        buffer.writeln('      eventType: "$eventType"');
        // Database triggers use empty eventFilters
        buffer.writeln('      eventFilters: {}');

        // Both ref and instance go in eventFilterPathPatterns
        // The ref path should not have a leading slash to match Node.js format
        final normalizedRef = endpoint.refPath!.startsWith('/')
            ? endpoint.refPath!.substring(1)
            : endpoint.refPath!;
        buffer.writeln('      eventFilterPathPatterns:');
        buffer.writeln('        ref: "$normalizedRef"');
        buffer.writeln('        instance: "${endpoint.instance ?? '*'}"');

        buffer.writeln('      retry: false');
      }
    }
  }

  return buffer.toString();
}

/// Maps Firestore method name to CloudEvent event type.
String _mapFirestoreEventType(String methodName) => switch (methodName) {
      'onDocumentCreated' => 'google.cloud.firestore.document.v1.created',
      'onDocumentUpdated' => 'google.cloud.firestore.document.v1.updated',
      'onDocumentDeleted' => 'google.cloud.firestore.document.v1.deleted',
      'onDocumentWritten' => 'google.cloud.firestore.document.v1.written',
      _ => throw ArgumentError('Unknown Firestore event type: $methodName'),
    };

/// Maps Database method name to CloudEvent event type.
String _mapDatabaseEventType(String methodName) => switch (methodName) {
      'onValueCreated' => 'google.firebase.database.ref.v1.created',
      'onValueUpdated' => 'google.firebase.database.ref.v1.updated',
      'onValueDeleted' => 'google.firebase.database.ref.v1.deleted',
      'onValueWritten' => 'google.firebase.database.ref.v1.written',
      _ => throw ArgumentError('Unknown Database event type: $methodName'),
    };

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

/// Formats an option value for YAML output.
/// Strings (including CEL expressions) are quoted, numbers/bools are not.
String _formatOptionValue(dynamic value) {
  if (value is String) {
    return '"$value"';
  } else if (value is num || value is bool) {
    return value.toString();
  }
  return value.toString();
}
