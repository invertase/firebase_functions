/// Build-time code generator for Firebase Functions.
///
/// This builder analyzes Dart source code to discover function declarations
/// and their configurations, then generates a functions.yaml manifest that
/// firebase-tools uses for deployment.
///
/// See BUILDER_SYSTEM.md for detailed documentation.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

/// Builder factory function (called by build_runner).
Builder specBuilder(BuilderOptions options) => _SpecBuilder();

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
      LibraryElement library;
      try {
        library = await resolver.libraryFor(asset, allowSyntaxErrors: true);
      } catch (e) {
        // Likely a part file, skip it
        continue;
      }

      // Get the resolved AST for this library using the first fragment
      // We need resolved types for TypeChecker to work properly
      final fragment = library.firstFragment;
      final ast = await resolver.astNodeFor(fragment, resolve: true);
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

const _pkg = 'package:firebase_functions';

class _Namespace {
  const _Namespace(this.extractor, this.typeChecker, this.methodNames);

  final String typeChecker;
  final void Function(MethodInvocation, String) extractor;
  final List<String> methodNames;

  bool isNamespace(Expression target) {
    final staticType = target.staticType;
    if (staticType == null) return false;
    return TypeChecker.fromUrl(typeChecker).isExactlyType(staticType);
  }

  bool matches(String methodName) => methodNames.contains(methodName);
}

/// AST visitor that discovers Firebase Functions declarations.
class _FirebaseFunctionsVisitor extends RecursiveAstVisitor<void> {
  _FirebaseFunctionsVisitor(this.resolver) {
    namespaces = <_Namespace>[
      _Namespace(
        _extractHttpsFunction,
        '$_pkg/src/https/https_namespace.dart#HttpsNamespace',
        ['onRequest', 'onCall', 'onCallWithData'],
      ),
      _Namespace(
        _extractPubSubFunction,
        '$_pkg/src/pubsub/pubsub_namespace.dart#PubSubNamespace',
        ['onMessagePublished'],
      ),
      _Namespace(
        _extractFirestoreFunction,
        '$_pkg/src/firestore/firestore_namespace.dart#FirestoreNamespace',
        [
          'onDocumentCreated',
          'onDocumentUpdated',
          'onDocumentDeleted',
          'onDocumentWritten',
        ],
      ),
      _Namespace(
        _extractDatabaseFunction,
        '$_pkg/src/database/database_namespace.dart#DatabaseNamespace',
        [
          'onValueCreated',
          'onValueUpdated',
          'onValueDeleted',
          'onValueWritten',
        ],
      ),
      _Namespace(
        _extractGenericAlertFunction,
        '$_pkg/src/alerts/alerts_namespace.dart#AlertsNamespace',
        ['onAlertPublished'],
      ),
      _Namespace(
        _extractCrashlyticsAlertFunction,
        '$_pkg/src/alerts/crashlytics_namespace.dart#CrashlyticsNamespace',
        [
          'onNewFatalIssuePublished',
          'onNewNonfatalIssuePublished',
          'onRegressionAlertPublished',
          'onStabilityDigestPublished',
          'onVelocityAlertPublished',
          'onNewAnrIssuePublished',
        ],
      ),
      _Namespace(
        _extractBillingAlertFunction,
        '$_pkg/src/alerts/billing_namespace.dart#BillingNamespace',
        ['onPlanUpdatePublished', 'onPlanAutomatedUpdatePublished'],
      ),
      _Namespace(
        _extractAppDistributionAlertFunction,
        '$_pkg/src/alerts/app_distribution_namespace.dart#AppDistributionNamespace',
        ['onNewTesterIosDevicePublished', 'onInAppFeedbackPublished'],
      ),
      _Namespace(
        _extractPerformanceAlertFunction,
        '$_pkg/src/alerts/performance_namespace.dart#PerformanceNamespace',
        ['onThresholdAlertPublished'],
      ),
      _Namespace(
        _extractIdentityFunction,
        '$_pkg/src/identity/identity_namespace.dart#IdentityNamespace',
        [
          'beforeUserCreated',
          'beforeUserSignedIn',
          'beforeEmailSent',
          'beforeSmsSent',
        ],
      ),
      _Namespace(
        // Adapter: _extractSchedulerFunction only takes node, not the second String arg
        (node, _) => _extractSchedulerFunction(node),
        '$_pkg/src/scheduler/scheduler_namespace.dart#SchedulerNamespace',
        ['onSchedule'],
      ),
    ];
  }
  final Resolver resolver;
  final Map<String, _ParamSpec> params = {};
  final Map<String, _EndpointSpec> endpoints = {};
  late final List<_Namespace> namespaces;

  /// Maps variable names to their actual parameter names.
  /// e.g., 'minInstances' -> 'MIN_INSTANCES'
  final Map<String, String> _variableToParamName = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    final methodName = node.methodName.name;
    if (target != null) {
      // Check against all namespaces
      for (final namespace in namespaces) {
        if (namespace.isNamespace(target)) {
          if (namespace.matches(methodName)) {
            namespace.extractor(node, methodName);
            // Found a match, no need to check other namespaces for this node
            return;
          }
        }
      }
    } else {
      // Check for parameter definitions (top-level function calls with no target)
      if (_isParamDefinition(methodName)) {
        _extractParameterFromMethod(node, methodName);
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (node.function case final SimpleIdentifier function) {
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

    final functionName = node.extractLiteralForArg('name');
    if (functionName == null) return;

    // Determine trigger type
    final triggerType = methodName == 'onRequest' ? 'https' : 'callable';

    endpoints[functionName] = _EndpointSpec(
      name: functionName,
      type: triggerType,
      options: node.findOptionsArg(),
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a Pub/Sub function declaration.
  void _extractPubSubFunction(MethodInvocation node, String methodName) {
    // Extract topic name from named argument
    final topicName = node.extractLiteralForArg('topic');
    if (topicName == null) return;

    // Generate function name from topic (remove hyphens to match Node.js behavior)
    final sanitizedTopic = topicName.replaceAll('-', '');
    final functionName = 'onMessagePublished_$sanitizedTopic';

    endpoints[functionName] = _EndpointSpec(
      name: functionName,
      type: 'pubsub',
      topic: topicName, // Keep original topic name for eventFilters
      options: node.findOptionsArg(),
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a Firestore function declaration.
  void _extractFirestoreFunction(MethodInvocation node, String methodName) {
    // Extract document path from named argument
    final documentPath = node.extractLiteralForArg('document');
    if (documentPath == null) return;

    // Extract options if present (for database and namespace)
    final optionsArg = node.findOptionsArg();
    String? database;
    String? namespace;

    if (optionsArg != null) {
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
      options: optionsArg,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a Database function declaration.
  void _extractDatabaseFunction(MethodInvocation node, String methodName) {
    // Extract ref path from named argument
    final refPath = node.extractLiteralForArg('ref');
    if (refPath == null) return;

    // Extract options if present (for instance)
    final optionsArg = node.findOptionsArg();
    String? instance;

    if (optionsArg != null) {
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
      options: optionsArg,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a generic alert function declaration (onAlertPublished).
  void _extractGenericAlertFunction(MethodInvocation node, String methodName) {
    // Extract alertType from named argument

    final alertTypeValue = _extractAlertTypeValue(
      node.findNamedArg('alertType'),
    );
    if (alertTypeValue == null) return;

    // Extract appId from options if present
    final optionsArg = node.findOptionsArg();
    String? appId;

    if (optionsArg != null) {
      appId = _extractStringField(optionsArg, 'appId');
    }

    // Generate function name
    final sanitizedAlertType = alertTypeValue
        .replaceAll('.', '_')
        .replaceAll('-', '');
    final functionName = 'onAlertPublished_$sanitizedAlertType';

    endpoints[functionName] = _EndpointSpec(
      name: functionName,
      type: 'alert',
      alertType: alertTypeValue,
      appId: appId,
      options: optionsArg,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts Crashlytics alert function declarations.
  void _extractCrashlyticsAlertFunction(
    MethodInvocation node,
    String methodName,
  ) {
    // Map method names to alert types
    final alertType = switch (methodName) {
      'onNewFatalIssuePublished' => 'crashlytics.newFatalIssue',
      'onNewNonfatalIssuePublished' => 'crashlytics.newNonfatalIssue',
      'onRegressionAlertPublished' => 'crashlytics.regression',
      'onStabilityDigestPublished' => 'crashlytics.stabilityDigest',
      'onVelocityAlertPublished' => 'crashlytics.velocity',
      'onNewAnrIssuePublished' => 'crashlytics.newAnrIssue',
      _ => null,
    };

    if (alertType == null) return;

    _extractAlertEndpoint(node, alertType);
  }

  /// Extracts Billing alert function declarations.
  void _extractBillingAlertFunction(MethodInvocation node, String methodName) {
    final alertType = switch (methodName) {
      'onPlanUpdatePublished' => 'billing.planUpdate',
      'onPlanAutomatedUpdatePublished' => 'billing.planAutomatedUpdate',
      _ => null,
    };

    if (alertType == null) return;

    _extractAlertEndpoint(node, alertType);
  }

  /// Extracts App Distribution alert function declarations.
  void _extractAppDistributionAlertFunction(
    MethodInvocation node,
    String methodName,
  ) {
    final alertType = switch (methodName) {
      'onNewTesterIosDevicePublished' => 'appDistribution.newTesterIosDevice',
      'onInAppFeedbackPublished' => 'appDistribution.inAppFeedback',
      _ => null,
    };

    if (alertType == null) return;

    _extractAlertEndpoint(node, alertType);
  }

  /// Extracts Performance alert function declarations.
  void _extractPerformanceAlertFunction(
    MethodInvocation node,
    String methodName,
  ) {
    final alertType = switch (methodName) {
      'onThresholdAlertPublished' => 'performance.threshold',
      _ => null,
    };

    if (alertType == null) return;

    _extractAlertEndpoint(node, alertType);
  }

  /// Helper to extract alert endpoint from a method invocation.
  void _extractAlertEndpoint(MethodInvocation node, String alertType) {
    // Extract appId from options if present
    final optionsArg = node.findOptionsArg();
    String? appId;

    if (optionsArg != null) {
      appId = _extractStringField(optionsArg, 'appId');
    }

    // Generate function name
    final sanitizedAlertType = alertType
        .replaceAll('.', '_')
        .replaceAll('-', '');
    final functionName = 'onAlertPublished_$sanitizedAlertType';

    endpoints[functionName] = _EndpointSpec(
      name: functionName,
      type: 'alert',
      alertType: alertType,
      appId: appId,
      options: optionsArg,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts an Identity function declaration.
  void _extractIdentityFunction(MethodInvocation node, String methodName) {
    // Map method names to event types
    final eventType = switch (methodName) {
      'beforeUserCreated' => 'beforeCreate',
      'beforeUserSignedIn' => 'beforeSignIn',
      'beforeEmailSent' => 'beforeSendEmail',
      'beforeSmsSent' => 'beforeSendSms',
      _ => null,
    };

    if (eventType == null) return;

    // Extract options if present
    final optionsArg = node.findOptionsArg();
    bool? idToken;
    bool? accessToken;
    bool? refreshToken;

    if (optionsArg != null) {
      idToken = _extractBoolField(optionsArg, 'idToken');
      accessToken = _extractBoolField(optionsArg, 'accessToken');
      refreshToken = _extractBoolField(optionsArg, 'refreshToken');
    }

    // Function name is the event type
    final functionName = eventType;

    endpoints[functionName] = _EndpointSpec(
      name: functionName,
      type: 'blocking',
      blockingEventType: eventType,
      idToken: idToken,
      accessToken: accessToken,
      refreshToken: refreshToken,
      options: optionsArg,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a Scheduler function declaration.
  void _extractSchedulerFunction(MethodInvocation node) {
    // Extract schedule from named argument
    final scheduleArg = node.findNamedArg('schedule');
    if (scheduleArg == null) return;

    final schedule = _extractStringLiteral(scheduleArg);
    if (schedule == null) return;

    // Generate function name from schedule (matching runtime behavior)
    final sanitized = schedule
        .replaceAll(' ', '_')
        .replaceAll('*', '')
        .replaceAll('/', '')
        .replaceAll('-', '')
        .replaceAll(',', '');
    final functionName = 'onSchedule_$sanitized';

    // Extract options if present
    final optionsArg = node.findOptionsArg();
    String? timeZone;
    Map<String, dynamic>? retryConfig;

    if (optionsArg != null) {
      timeZone = _extractSchedulerTimeZone(optionsArg);
      retryConfig = _extractRetryConfig(optionsArg);
    }

    endpoints[functionName] = _EndpointSpec(
      name: functionName,
      type: 'scheduler',
      schedule: schedule,
      timeZone: timeZone,
      retryConfig: retryConfig,
      options: optionsArg,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts timeZone from ScheduleOptions.
  String? _extractSchedulerTimeZone(InstanceCreationExpression node) {
    final timeZoneArg = node.argumentList.arguments
        .whereType<NamedExpression>()
        .where((e) => e.name.label.name == 'timeZone')
        .map((e) => e.expression)
        .firstOrNull;

    if (timeZoneArg is InstanceCreationExpression) {
      // TimeZone('America/New_York')
      final args = timeZoneArg.argumentList.arguments;
      if (args.firstOrNull case final StringLiteral firstArg) {
        return firstArg.stringValue;
      }
    }
    return null;
  }

  /// Extracts RetryConfig from ScheduleOptions.
  Map<String, dynamic>? _extractRetryConfig(InstanceCreationExpression node) {
    final retryConfigArg = node.argumentList.arguments
        .whereType<NamedExpression>()
        .where((e) => e.name.label.name == 'retryConfig')
        .map((e) => e.expression)
        .firstOrNull;

    if (retryConfigArg is! InstanceCreationExpression) return null;

    final config = <String, dynamic>{};

    for (final arg in retryConfigArg.argumentList.arguments) {
      if (arg is! NamedExpression) continue;

      final fieldName = arg.name.label.name;
      final value = _extractRetryConfigValue(arg.expression);
      if (value != null) {
        config[fieldName] = value;
      }
    }

    return config.isEmpty ? null : config;
  }

  /// Extracts a value from a retry config option.
  dynamic _extractRetryConfigValue(Expression expression) {
    if (expression is InstanceCreationExpression) {
      final args = expression.argumentList.arguments;
      if (args.isNotEmpty) {
        final first = args.first;
        if (first is IntegerLiteral) return first.value;
        if (first is DoubleLiteral) return first.value;
      }
    }
    return null;
  }

  /// Extracts a boolean field from an InstanceCreationExpression.
  bool? _extractBoolField(InstanceCreationExpression node, String fieldName) {
    final arg = node.argumentList.arguments
        .whereType<NamedExpression>()
        .where((e) => e.name.label.name == fieldName)
        .map((e) => e.expression)
        .firstOrNull;

    if (arg is BooleanLiteral) {
      return arg.value;
    }
    return null;
  }

  /// Extracts alert type value from an expression.
  String? _extractAlertTypeValue(Expression? expression) {
    if (expression is InstanceCreationExpression) {
      // Extract from constructor: const CrashlyticsNewFatalIssue()
      final typeName = expression.constructorName.type.name.lexeme;
      return switch (typeName) {
        'CrashlyticsNewFatalIssue' => 'crashlytics.newFatalIssue',
        'CrashlyticsNewNonfatalIssue' => 'crashlytics.newNonfatalIssue',
        'CrashlyticsRegression' => 'crashlytics.regression',
        'CrashlyticsStabilityDigest' => 'crashlytics.stabilityDigest',
        'CrashlyticsVelocity' => 'crashlytics.velocity',
        'CrashlyticsNewAnrIssue' => 'crashlytics.newAnrIssue',
        'BillingPlanUpdate' => 'billing.planUpdate',
        'BillingPlanAutomatedUpdate' => 'billing.planAutomatedUpdate',
        'AppDistributionNewTesterIosDevice' =>
          'appDistribution.newTesterIosDevice',
        'AppDistributionInAppFeedback' => 'appDistribution.inAppFeedback',
        'PerformanceThreshold' => 'performance.threshold',
        _ => null,
      };
    }
    return null;
  }

  /// Extracts a parameter definition from FunctionExpressionInvocation.
  void _extractParameter(
    FunctionExpressionInvocation node,
    String functionName,
  ) {
    _extractParamFromArgs(node.argumentList.arguments, functionName);
  }

  /// Extracts a parameter definition from MethodInvocation.
  void _extractParameterFromMethod(MethodInvocation node, String functionName) {
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
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)}')
        .toUpperCase()
        .replaceFirst('_', '');
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
  Object? _extractDefaultValue(InstanceCreationExpression node) {
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
  ) => node.argumentList.arguments
      .whereType<NamedExpression>()
      .where((e) => e.name.label.name == fieldName)
      .map((e) => e.expression)
      .whereType<StringLiteral>()
      .map((e) => e.stringValue!)
      .firstOrNull;

  /// Extracts a constant value from an expression.
  Object? _extractConstValue(Expression expression) {
    return switch (expression) {
      StringLiteral() => expression.stringValue,
      IntegerLiteral() => expression.value,
      DoubleLiteral() => expression.value,
      BooleanLiteral() => expression.value,
      ListLiteral() =>
        expression.elements
            .whereType<Expression>()
            .map(_extractConstValue)
            .whereType<dynamic>()
            .toList(),
      _ => null,
    };
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
  final Object? defaultValue;
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
    this.alertType,
    this.appId,
    this.blockingEventType,
    this.idToken,
    this.accessToken,
    this.refreshToken,
    this.schedule,
    this.timeZone,
    this.retryConfig,
    this.options,
    this.variableToParamName = const {},
  });
  final String name;
  // 'https', 'callable', 'pubsub', 'firestore', 'database', 'alert', 'blocking', 'scheduler'
  final String type;
  final String? topic; // For Pub/Sub functions
  final String? firestoreEventType; // For Firestore: onDocumentCreated, etc.
  final String? documentPath; // For Firestore: users/{userId}
  final String? database; // For Firestore: (default) or database name
  final String? namespace; // For Firestore: (default) or namespace
  final String? databaseEventType; // For Database: onValueCreated, etc.
  final String? refPath; // For Database: /users/{userId}
  final String? instance; // For Database: database instance or '*'
  final String? alertType; // For Alerts: crashlytics.newFatalIssue, etc.
  final String? appId; // For Alerts: optional app ID filter
  final String? blockingEventType; // For Identity: beforeCreate, etc.
  final bool? idToken; // For Identity: pass ID token
  final bool? accessToken; // For Identity: pass access token
  final bool? refreshToken; // For Identity: pass refresh token
  final String? schedule; // For Scheduler: cron expression
  final String? timeZone; // For Scheduler: timezone
  final Map<String, dynamic>? retryConfig; // For Scheduler: retry configuration
  final InstanceCreationExpression? options;
  final Map<String, String> variableToParamName;

  /// Extracts options configuration from the AST.
  Map<String, dynamic> extractOptions() {
    if (options == null) return {};

    final result = <String, dynamic>{};

    for (final arg in options!.argumentList.arguments) {
      if (arg is! NamedExpression) continue;

      final name = arg.name.label.name;
      final expr = arg.expression;

      // Helper to reduce boilerplate: only adds to map if value exists
      void add(String key, dynamic Function(Expression expr) func) {
        final value = func(expr);
        if (value != null) result[key] = value;
      }

      switch (name) {
        case 'memory':
          add('availableMemoryMb', _extractMemory);
        case 'cpu':
          add('cpu', _extractCpu);
        case 'timeoutSeconds':
          add('timeoutSeconds', _extractTimeoutSeconds);
        case 'minInstances':
          add('minInstances', _extractInt);
        case 'maxInstances':
          add('maxInstances', _extractInt);
        case 'concurrency':
          add('concurrency', _extractInt);
        case 'region':
          add('region', _extractRegion);
        case 'serviceAccount':
          add('serviceAccount', _extractString);
        case 'vpcConnector':
          add('vpcConnector', _extractString);
        case 'vpcConnectorEgressSettings':
          add('vpcConnectorEgressSettings', _extractVpcEgressSettings);
        case 'ingressSettings':
          add('ingressSettings', _extractIngressSettings);
        case 'invoker':
          add('invoker', _extractInvoker);
        case 'secrets':
          add('secretEnvironmentVariables', _extractSecrets);
        case 'labels':
          add('labels', _extractLabels);
        case 'omit':
          add('omit', _extractBool);

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
  Object? _extractMemory(Expression expression) {
    if (expression is! InstanceCreationExpression) return null;

    // Check if it's Memory.param() - generate CEL
    if (expression.constructorName.name?.name == 'param') {
      return _extractParamReference(expression);
    }

    // Check if it's Memory.expression() - generate CEL from expression
    if (expression.constructorName.name?.name == 'expression') {
      return _extractCelExpression(
        expression.argumentList.arguments.firstOrNull,
      );
    }

    // Check if it's Memory.reset()
    if (expression.constructorName.name?.name == 'reset') {
      return null; // Reset means use default
    }

    // Extract literal value: Memory(MemoryOption.mb256)
    final args = expression.argumentList.arguments;
    if (args.firstOrNull case final PrefixedIdentifier firstArg) {
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
  Object? _extractCpu(Expression expression) {
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
    return switch (args.firstOrNull) {
      final DoubleLiteral d => d.value,
      final IntegerLiteral i => i.value,
      _ => null,
    };
  }

  /// Extracts Region option value.
  Object? _extractRegion(Expression expression) {
    if (expression is! InstanceCreationExpression) return null;

    // Check if it's Region.param() - generate CEL
    if (expression.constructorName.name?.name == 'param') {
      return _extractParamReference(expression);
    }

    // Extract literal value: Region(SupportedRegion.usCentral1)
    final args = expression.argumentList.arguments;

    if (args.firstOrNull case final PrefixedIdentifier firstArg) {
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
  Object? _extractTimeoutSeconds(Expression expression) =>
      _extractInt(expression);

  /// Extracts integer option value.
  Object? _extractInt(Expression expression) {
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
      if (args.firstOrNull case final IntegerLiteral firstArg) {
        return firstArg.value;
      }
    }

    return null;
  }

  /// Extracts string option value.
  Object? _extractString(Expression expression) {
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
      if (args.firstOrNull case final StringLiteral firstArg) {
        return firstArg.stringValue;
      }
    }

    return null;
  }

  /// Extracts boolean option value.
  Object? _extractBool(Expression expression) {
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
      if (args.firstOrNull case final BooleanLiteral firstArg) {
        return firstArg.value;
      }
    }

    return null;
  }

  /// Extracts VPC egress settings.
  Object? _extractVpcEgressSettings(Expression expression) {
    if (expression is! InstanceCreationExpression) return null;

    final args = expression.argumentList.arguments;
    if (args.firstOrNull case final PrefixedIdentifier firstArg) {
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
  Object? _extractIngressSettings(Expression expression) {
    if (expression is! InstanceCreationExpression) return null;

    final args = expression.argumentList.arguments;
    if (args.firstOrNull case final PrefixedIdentifier firstArg) {
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
  Object? _extractInvoker(Expression expression) {
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
    if (args.firstOrNull case final ListLiteral firstArg) {
      return firstArg.elements
          .whereType<StringLiteral>()
          .map((e) => e.stringValue)
          .nonNulls
          .toList();
    }

    return null;
  }

  /// Extracts secrets list.
  List<String>? _extractSecrets(Expression expression) {
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
  Object? _extractLabels(Expression expression) {
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
  String? _extractCelExpression(Expression? expression) {
    // Handle method invocation like: isProduction.thenElse(2048, 512)
    if (expression is MethodInvocation) {
      final target = expression.target;
      final methodName = expression.methodName.name;

      if (methodName == 'thenElse' && target is SimpleIdentifier) {
        // Get the param name from the variable
        final variableName = target.name;
        final paramName =
            variableToParamName[variableName] ??
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
  Object? _extractLiteralValue(Expression expression) => switch (expression) {
    StringLiteral() => '"${expression.stringValue}"',
    IntegerLiteral() => expression.value,
    DoubleLiteral() => expression.value,
    BooleanLiteral() => expression.value,
    _ => null,
  };

  /// Converts a variable name to UPPER_SNAKE_CASE format.
  static String _toUpperSnakeCase(String variableName) => variableName
      .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)}')
      .toUpperCase()
      .replaceFirst('_', '');
}

/// Generates the YAML content.
String _generateYaml(
  Map<String, _ParamSpec> params,
  Map<String, _EndpointSpec> endpoints,
) {
  final buffer = StringBuffer();
  // Shorthand to improve readability
  void w([String s = '']) => buffer.writeln(s);
  w('specVersion: "v1alpha1"');
  w();

  // Generate params section
  if (params.isNotEmpty) {
    w('params:');
    for (final param in params.values) {
      w('  - name: "${param.name}"');
      w('    type: "${param.type}"');
      if (param.format case final String format) {
        w('    format: "$format"');
      }
      if (param.options?.defaultValue case final Object defaultValue) {
        w('    default: ${_yamlValue(defaultValue)}');
      }
      if (param.options?.label case final String label) {
        w('    label: "$label"');
      }
      if (param.options?.description case final String description) {
        w('    description: "$description"');
      }
    }
    w();
  }

  // Generate requiredAPIs section
  w('requiredAPIs:');
  w('  - api: "cloudfunctions.googleapis.com"');
  w('    reason: "Required for Cloud Functions"');
  // Add identitytoolkit API if there are blocking functions
  final hasBlockingFunctions = endpoints.values.any(
    (e) => e.type == 'blocking',
  );
  if (hasBlockingFunctions) {
    w('  - api: "identitytoolkit.googleapis.com"');
    w('    reason: "Needed for auth blocking functions"');
  }
  // Add cloudscheduler API if there are scheduler functions
  final hasSchedulerFunctions = endpoints.values.any(
    (e) => e.type == 'scheduler',
  );
  if (hasSchedulerFunctions) {
    w('  - api: "cloudscheduler.googleapis.com"');
    w('    reason: "Needed for scheduled functions"');
  }
  w();

  // Generate endpoints section
  if (endpoints.isNotEmpty) {
    w('endpoints:');
    for (final endpoint in endpoints.values) {
      w('  ${endpoint.name}:');
      w('    entryPoint: "${endpoint.name}"');
      w('    platform: "gcfv2"');

      // Extract and add options
      final options = endpoint.extractOptions();

      // Add region (use extracted value or default)
      if (options['region'] case final List<String> regions) {
        w('    region:');
        for (final region in regions) {
          w('      - "$region"');
        }
      } else {
        w('    region:');
        w('      - "us-central1"');
      }

      // Add memory if specified
      if (options['availableMemoryMb'] case final Object option) {
        w('    availableMemoryMb: ${_formatOption(option)}');
      }

      // Add CPU if specified
      if (options['cpu'] case final Object option) {
        w('    cpu: ${_formatOption(option)}');
      }

      // Add timeout if specified
      if (options['timeoutSeconds'] case final Object option) {
        w('    timeoutSeconds: ${_formatOption(option)}');
      }

      // Add concurrency if specified
      if (options['concurrency'] case final Object option) {
        w('    concurrency: ${_formatOption(option)}');
      }

      // Add min/max instances
      if (options['minInstances'] case final Object option) {
        w('    minInstances: ${_formatOption(option)}');
      }
      if (options['maxInstances'] case final Object option) {
        w('    maxInstances: ${_formatOption(option)}');
      }

      // Add service account if specified (Node.js uses serviceAccountEmail)
      if (options['serviceAccount'] case final Object option) {
        w('    serviceAccountEmail: "$option"');
      }

      // Add VPC configuration if specified (nested structure like Node.js)
      if (options.containsKey('vpcConnector') ||
          options.containsKey('vpcConnectorEgressSettings')) {
        w('    vpc:');
        if (options['vpcConnector'] case final Object option) {
          w('      connector: "$option"');
        }
        if (options['vpcConnectorEgressSettings'] case final Object option) {
          w('      egressSettings: "$option"');
        }
      }

      // Add ingress settings if specified
      if (options['ingressSettings'] case final Object option) {
        w('    ingressSettings: "$option"');
      }

      // Add omit if specified
      if (options['omit'] case final Object option) {
        w('    omit: $option');
      }

      // Note: preserveExternalChanges is runtime-only, not in manifest

      // Add labels if specified
      if (options['labels'] case final Map<String, String> labels) {
        w('    labels:');
        for (final entry in labels.entries) {
          w('      ${entry.key}: "${entry.value}"');
        }
      }

      // Add secrets if specified
      if (options['secretEnvironmentVariables']
          case final List<String> secrets) {
        w('    secretEnvironmentVariables:');
        for (final secret in secrets) {
          w('      - key: "$secret"');
          w('        secret: "$secret"');
        }
      }

      // Add trigger configuration
      if (endpoint.type == 'https') {
        w('    httpsTrigger:');

        // Add invoker
        if (options['invoker'] case final List<String>? invokers) {
          if (invokers?.isEmpty ?? true) {
            w('      invoker: []');
          } else {
            w('      invoker:');
            for (final inv in invokers!) {
              w('        - "$inv"');
            }
          }
        }

        // Note: CORS is runtime-only, not in manifest
      } else if (endpoint.type == 'callable') {
        w('    callableTrigger: {}');

        // Note: enforceAppCheck, consumeAppCheckToken, heartbeatSeconds are runtime-only, not in manifest
      } else if (endpoint.type == 'pubsub' && endpoint.topic != null) {
        w('    eventTrigger:');
        w('      eventType: "google.cloud.pubsub.topic.v1.messagePublished"');
        w('      eventFilters:');
        w('        topic: "${endpoint.topic}"');
        w('      retry: false');
      } else if (endpoint.type == 'firestore' &&
          endpoint.firestoreEventType != null &&
          endpoint.documentPath != null) {
        // Map Dart method name to Firestore CloudEvent type
        final eventType = _mapFirestoreEventType(endpoint.firestoreEventType!);

        w('    eventTrigger:');
        w('      eventType: "$eventType"');
        w('      eventFilters:');
        w('        database: "${endpoint.database ?? '(default)'}"');
        w('        namespace: "${endpoint.namespace ?? '(default)'}"');

        // Check if document path has wildcards
        final hasWildcards = endpoint.documentPath!.contains('{');
        if (hasWildcards) {
          w('      eventFilterPathPatterns:');
        }
        w('        document: "${endpoint.documentPath}"');

        w('      retry: false');
      } else if (endpoint.type == 'database' &&
          endpoint.databaseEventType != null &&
          endpoint.refPath != null) {
        // Map Dart method name to Database CloudEvent type
        final eventType = _mapDatabaseEventType(endpoint.databaseEventType!);

        w('    eventTrigger:');
        w('      eventType: "$eventType"');
        // Database triggers use empty eventFilters
        w('      eventFilters: {}');

        // Both ref and instance go in eventFilterPathPatterns
        // The ref path should not have a leading slash to match Node.js format
        final normalizedRef = endpoint.refPath!.startsWith('/')
            ? endpoint.refPath!.substring(1)
            : endpoint.refPath!;
        w('      eventFilterPathPatterns:');
        w('        ref: "$normalizedRef"');
        w('        instance: "${endpoint.instance ?? '*'}"');

        w('      retry: false');
      } else if (endpoint.type == 'alert' && endpoint.alertType != null) {
        w('    eventTrigger:');
        w(
          '      eventType: "google.firebase.firebasealerts.alerts.v1.published"',
        );
        w('      eventFilters:');
        w('        alerttype: "${endpoint.alertType}"');
        if (endpoint.appId != null) {
          w('        appid: "${endpoint.appId}"');
        }
        w('      retry: false');
      } else if (endpoint.type == 'blocking' &&
          endpoint.blockingEventType != null) {
        w('    blockingTrigger:');
        w(
          '      eventType: "providers/cloud.auth/eventTypes/user.${endpoint.blockingEventType}"',
        );

        // Only include token options for beforeCreate and beforeSignIn
        final isAuthEvent =
            endpoint.blockingEventType == 'beforeCreate' ||
            endpoint.blockingEventType == 'beforeSignIn';
        if (isAuthEvent) {
          w('      options:');
          if (endpoint.idToken ?? false) {
            w('        idToken: true');
          }
          if (endpoint.accessToken ?? false) {
            w('        accessToken: true');
          }
          if (endpoint.refreshToken ?? false) {
            w('        refreshToken: true');
          }
        } else {
          w('      options: {}');
        }
      } else if (endpoint.type == 'scheduler' && endpoint.schedule != null) {
        w('    scheduleTrigger:');
        w('      schedule: "${endpoint.schedule}"');
        if (endpoint.timeZone != null) {
          w('      timeZone: "${endpoint.timeZone}"');
        }
        if (endpoint.retryConfig != null && endpoint.retryConfig!.isNotEmpty) {
          w('      retryConfig:');
          final config = endpoint.retryConfig!;
          if (config['retryCount'] case final Object conf) {
            w('        retryCount: $conf');
          }
          if (config['maxRetrySeconds'] case final Object conf) {
            w('        maxRetrySeconds: $conf');
          }
          if (config['minBackoffSeconds'] case final Object conf) {
            w('        minBackoffSeconds: $conf');
          }
          if (config['maxBackoffSeconds'] case final Object conf) {
            w('        maxBackoffSeconds: $conf');
          }
          if (config['maxDoublings'] case final Object conf) {
            w('        maxDoublings: $conf');
          }
        }
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
/// Strings (including CEL expressions) are quoted, numbers/bools/... are not.
String _formatOption(dynamic value) => switch (value) {
  String() => '"$value"',
  _ => value.toString(),
};

extension on MethodInvocation {
  /// Finds a named argument in a method invocation.
  Expression? findNamedArg(String name) => argumentList.arguments
      .whereType<NamedExpression>()
      .where((e) => e.name.label.name == name)
      .map((e) => e.expression)
      .firstOrNull;

  String? extractLiteralForArg(String name) =>
      _extractStringLiteral(findNamedArg(name));

  InstanceCreationExpression? findOptionsArg() {
    final options = findNamedArg('options');
    return options is InstanceCreationExpression ? options : null;
  }
}

/// Extracts a string literal value.
String? _extractStringLiteral(Expression? expression) =>
    expression is StringLiteral ? expression.stringValue : null;
