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

import 'src/builder/manifest.dart';
import 'src/builder/spec.dart';

/// Builder factory function (called by build_runner).
Builder specBuilder(BuilderOptions options) => _SpecBuilder();

/// The main builder that generates functions.yaml.
class _SpecBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': ['functions.yaml'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;

    // Find all Dart files in the package
    final assets = await buildStep.findAssets(Glob('**.dart')).toSet();

    final allParams = <String, ParamSpec>{};
    final allEndpoints = <String, EndpointSpec>{};

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
    final yamlContent = generateManifestYaml(allParams, allEndpoints);

    // Write the YAML file
    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, 'functions.yaml'),
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
        _extractRemoteConfigFunction,
        '$_pkg/src/remote_config/remote_config_namespace.dart#RemoteConfigNamespace',
        ['onConfigUpdated'],
      ),
      _Namespace(
        _extractStorageFunction,
        '$_pkg/src/storage/storage_namespace.dart#StorageNamespace',
        [
          'onObjectArchived',
          'onObjectFinalized',
          'onObjectDeleted',
          'onObjectMetadataUpdated',
        ],
      ),
      _Namespace(
        // Adapter: _extractSchedulerFunction only takes node, not the second String arg
        (node, _) => _extractSchedulerFunction(node),
        '$_pkg/src/scheduler/scheduler_namespace.dart#SchedulerNamespace',
        ['onSchedule'],
      ),
      _Namespace(
        _extractTaskQueueFunction,
        '$_pkg/src/tasks/tasks_namespace.dart#TasksNamespace',
        ['onTaskDispatched'],
      ),
      _Namespace(
        _extractEventarcFunction,
        '$_pkg/src/eventarc/eventarc_namespace.dart#EventarcNamespace',
        ['onCustomEventPublished'],
      ),
      _Namespace(
        _extractTestLabFunction,
        '$_pkg/src/test_lab/test_lab_namespace.dart#TestLabNamespace',
        ['onTestMatrixCompleted'],
      ),
    ];
  }
  final Resolver resolver;
  final Map<String, ParamSpec> params = {};
  final Map<String, EndpointSpec> endpoints = {};
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
              paramName = '${toUpperSnakeCase(enumTypeName)}_LIST';
            } else if (valuesArg is PropertyAccess) {
              final target = valuesArg.target;
              if (target is SimpleIdentifier) {
                paramName = '${toUpperSnakeCase(target.name)}_LIST';
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

    endpoints[functionName] = EndpointSpec(
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

    endpoints[functionName] = EndpointSpec(
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

    endpoints[functionName] = EndpointSpec(
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

    endpoints[functionName] = EndpointSpec(
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

    endpoints[functionName] = EndpointSpec(
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

  /// Extracts a Remote Config function declaration.
  void _extractRemoteConfigFunction(MethodInvocation node, String methodName) {
    // Remote Config has a single event type and no filters,
    // so the function name is always 'onConfigUpdated'.
    const functionName = 'onConfigUpdated';

    endpoints[functionName] = EndpointSpec(
      name: functionName,
      type: 'remoteConfig',
      options: node.findOptionsArg(),
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a Storage function declaration.
  void _extractStorageFunction(MethodInvocation node, String methodName) {
    // Extract bucket name from named argument
    final bucketName = node.extractLiteralForArg('bucket');
    if (bucketName == null) return;

    // Generate function name from bucket (strip non-alphanumeric chars for valid function ID)
    final sanitizedBucket = bucketName.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
    final functionName = '${methodName}_$sanitizedBucket';

    endpoints[functionName] = EndpointSpec(
      name: functionName,
      type: 'storage',
      storageBucket: bucketName,
      storageEventType: methodName,
      options: node.findOptionsArg(),
      variableToParamName: _variableToParamName,
    );
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

    endpoints[functionName] = EndpointSpec(
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

    endpoints[functionName] = EndpointSpec(
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

    endpoints[functionName] = EndpointSpec(
      name: functionName,
      type: 'scheduler',
      schedule: schedule,
      timeZone: timeZone,
      retryConfig: retryConfig,
      options: optionsArg,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a Task Queue function declaration.
  void _extractTaskQueueFunction(MethodInvocation node, String methodName) {
    // Extract function name from named argument
    final functionName = node.extractLiteralForArg('name');
    if (functionName == null) return;

    // Extract options if present
    final optionsArg = node.findOptionsArg();
    Map<String, dynamic>? retryConfig;
    Map<String, dynamic>? rateLimits;

    if (optionsArg != null) {
      retryConfig = _extractTaskQueueRetryConfig(optionsArg);
      rateLimits = _extractTaskQueueRateLimits(optionsArg);
    }

    endpoints[functionName] = EndpointSpec(
      name: functionName,
      type: 'taskQueue',
      taskQueueRetryConfig: retryConfig,
      taskQueueRateLimits: rateLimits,
      options: optionsArg,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts an Eventarc function declaration.
  void _extractEventarcFunction(MethodInvocation node, String methodName) {
    // Extract eventType from named argument
    final eventType = node.extractLiteralForArg('eventType');
    if (eventType == null) return;

    // Generate function name from event type (remove non-alphanumeric chars)
    final sanitizedType = eventType.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
    final functionName = 'onCustomEventPublished_$sanitizedType';

    // Extract options if present (for channel and filters)
    final optionsArg = node.findOptionsArg();
    String? channel;
    Map<String, String>? filters;

    if (optionsArg != null) {
      channel = _extractStringField(optionsArg, 'channel');
      filters = _extractStringMapField(optionsArg, 'filters');
    }

    endpoints[functionName] = EndpointSpec(
      name: functionName,
      type: 'eventarc',
      eventarcEventType: eventType,
      eventarcChannel: channel ?? 'locations/us-central1/channels/firebase',
      eventarcFilters: filters,
      options: optionsArg,
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a Test Lab function declaration.
  void _extractTestLabFunction(MethodInvocation node, String methodName) {
    // Test Lab has a single event type and no filters,
    // so the function name is always 'onTestMatrixCompleted'.
    const functionName = 'onTestMatrixCompleted';

    endpoints[functionName] = EndpointSpec(
      name: functionName,
      type: 'testLab',
      options: node.findOptionsArg(),
      variableToParamName: _variableToParamName,
    );
  }

  /// Extracts a `Map<String, String>` field from an [InstanceCreationExpression].
  Map<String, String>? _extractStringMapField(
    InstanceCreationExpression node,
    String fieldName,
  ) {
    final arg = node.argumentList.arguments
        .whereType<NamedExpression>()
        .where((e) => e.name.label.name == fieldName)
        .map((e) => e.expression)
        .firstOrNull;

    if (arg is! SetOrMapLiteral || !arg.isMap) return null;

    final map = <String, String>{};
    for (final element in arg.elements) {
      if (element is MapLiteralEntry) {
        final key = element.key;
        final value = element.value;
        if (key is StringLiteral && value is StringLiteral) {
          map[key.stringValue!] = value.stringValue!;
        }
      }
    }

    return map.isEmpty ? null : map;
  }

  /// Extracts TaskQueueRetryConfig from TaskQueueOptions.
  Map<String, dynamic>? _extractTaskQueueRetryConfig(
    InstanceCreationExpression node,
  ) {
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

  /// Extracts TaskQueueRateLimits from TaskQueueOptions.
  Map<String, dynamic>? _extractTaskQueueRateLimits(
    InstanceCreationExpression node,
  ) {
    final rateLimitsArg = node.argumentList.arguments
        .whereType<NamedExpression>()
        .where((e) => e.name.label.name == 'rateLimits')
        .map((e) => e.expression)
        .firstOrNull;

    if (rateLimitsArg is! InstanceCreationExpression) return null;

    final config = <String, dynamic>{};

    for (final arg in rateLimitsArg.argumentList.arguments) {
      if (arg is! NamedExpression) continue;

      final fieldName = arg.name.label.name;
      final value = _extractRetryConfigValue(arg.expression);
      if (value != null) {
        config[fieldName] = value;
      }
    }

    return config.isEmpty ? null : config;
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
    ParamOptions? paramOptions;

    // Handle defineEnumList which has a different signature:
    // defineEnumList(EnumType.values, [ParamOptions])
    if (functionName == 'defineEnumList') {
      // First argument is the enum values (e.g., Region.values)
      final valuesArg = args.first;
      if (valuesArg is PrefixedIdentifier) {
        // Extract the enum type name from "EnumType.values"
        final enumTypeName = valuesArg.prefix.name;
        paramName = '${toUpperSnakeCase(enumTypeName)}_LIST';
      } else if (valuesArg is PropertyAccess) {
        // Handle qualified access like mypackage.Region.values
        final target = valuesArg.target;
        if (target is PrefixedIdentifier) {
          paramName = '${toUpperSnakeCase(target.identifier.name)}_LIST';
        } else if (target is SimpleIdentifier) {
          paramName = '${toUpperSnakeCase(target.name)}_LIST';
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

    params[paramName] = ParamSpec(
      name: paramName,
      type: paramType,
      options: paramOptions,
      format: isJsonSecret ? 'json' : null,
    );
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
  ParamOptions? _extractParamOptions(InstanceCreationExpression node) =>
      ParamOptions(
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
