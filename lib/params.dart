/// Firebase Functions parameter system.
///
/// Provides strongly-typed configuration that works at both deploy time
/// and runtime. Parameters can be defined using factory functions and
/// their values are read from environment variables.
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:firebase_functions/params.dart';
///
/// // Define parameters
/// final welcomeMessage = defineString(
///   'WELCOME_MESSAGE',
///   ParamOptions(defaultValue: 'Hello!'),
/// );
///
/// final minInstances = defineInt(
///   'MIN_INSTANCES',
///   ParamOptions(defaultValue: 0),
/// );
///
/// // Use at runtime
/// firebase.https.onRequest(
///   name: 'greet',
///   (request) async {
///     return Response.ok(welcomeMessage.value());
///   },
/// );
/// ```
///
/// ## Secrets
///
/// For sensitive values, use secrets stored in Cloud Secret Manager:
///
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
///
/// ## Built-in Parameters
///
/// Several parameters are built-in and always available:
///
/// - [projectID] - The Cloud project ID
/// - [databaseURL] - The Realtime Database URL (if configured)
/// - [storageBucket] - The Cloud Storage bucket (if configured)
/// - [gcloudProject] - Alias for projectID
///
/// ## Conditional Configuration
///
/// Use boolean parameters for conditional deployment configuration:
///
/// ```dart
/// final isProduction = defineBoolean('IS_PRODUCTION');
///
/// firebase.https.onRequest(
///   name: 'api',
///   options: HttpsOptions(
///     minInstances: isProduction.thenElse(2, 0),
///   ),
///   handler,
/// );
/// ```
library params;

import 'src/common/params.dart' as internal;

// Re-export expression types
export 'src/common/expression.dart'
    show Equals, Expression, If, LiteralExpression, NotEquals;
// Re-export onInit
export 'src/common/on_init.dart' show onInit;
// Re-export factory functions
export 'src/common/params.dart'
    show
        // Classes
        BooleanParam,
        DoubleParam,
        IntParam,
        JsonSecretParam,
        ListParam,
        // Input types
        MultiSelectParamInput,
        Param,
        ParamInput,
        ParamOptions,
        ResourceInput,
        SecretParam,
        SelectOption,
        SelectParamInput,
        StringParam,
        TextParamInput,
        WireParamSpec,
        // Registry
        clearParams,
        declaredParams,
        // Factory functions
        defineBoolean,
        defineDouble,
        defineInt,
        defineJsonSecret,
        defineList,
        defineSecret,
        defineString,
        // Internal expression (for built-in params)
        InternalExpression;

// ============================================================================
// Built-in Parameters
// ============================================================================

/// Built-in parameter that resolves to the Cloud project ID.
///
/// This parameter is always available and does not need to be defined.
/// The value is read from the `FIREBASE_CONFIG` environment variable.
///
/// Example:
/// ```dart
/// firebase.https.onRequest(
///   name: 'info',
///   (request) async {
///     return Response.ok('Project: ${projectID.value()}');
///   },
/// );
/// ```
final internal.Param<String> projectID = internal.ParamInput.projectId;

/// Built-in parameter that resolves to the Realtime Database URL.
///
/// Returns an empty string if Realtime Database is not configured for the project.
final internal.Param<String> databaseURL = internal.ParamInput.databaseURL;

/// Built-in parameter that resolves to the Cloud Storage bucket.
///
/// Returns an empty string if Cloud Storage is not configured for the project.
final internal.Param<String> storageBucket = internal.ParamInput.storageBucket;

/// Built-in parameter that resolves to the GCloud project ID.
///
/// This is an alias for [projectID] for compatibility.
final internal.Param<String> gcloudProject = internal.ParamInput.gcloudProject;

/// Resource input for selecting a Cloud Storage bucket.
///
/// Use this with [ParamInput.select] or as the `input` option for a string
/// parameter to let users select from available buckets at deploy time.
const bucketPicker = internal.ParamInput.bucketPicker;
