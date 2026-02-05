/// YAML manifest generation for Firebase Functions.
///
/// Generates the functions.yaml manifest that firebase-tools reads
/// for deployment. Uses a map-first approach: builds a structured
/// `Map<String, dynamic>` then converts to YAML.
library;

import 'package:yaml_edit/yaml_edit.dart';

import 'spec.dart';

/// Generates the YAML manifest string from discovered params and endpoints.
String generateManifestYaml(
  Map<String, ParamSpec> params,
  Map<String, EndpointSpec> endpoints,
) {
  final map = _buildManifestMap(params, endpoints);
  final editor = YamlEditor('');
  editor.update([], map);
  return editor.toString();
}

/// Builds the full manifest as a structured map.
Map<String, dynamic> _buildManifestMap(
  Map<String, ParamSpec> params,
  Map<String, EndpointSpec> endpoints,
) {
  final manifest = <String, dynamic>{'specVersion': 'v1alpha1'};

  // Params section
  if (params.isNotEmpty) {
    manifest['params'] = [
      for (final param in params.values) _buildParamMap(param),
    ];
  }

  // Required APIs section
  manifest['requiredAPIs'] = _buildRequiredAPIs(endpoints);

  // Endpoints section
  if (endpoints.isNotEmpty) {
    manifest['endpoints'] = {
      for (final endpoint in endpoints.values)
        endpoint.name: _buildEndpointMap(endpoint),
    };
  }

  return manifest;
}

/// Builds a single param entry as a map.
Map<String, dynamic> _buildParamMap(ParamSpec param) {
  final map = <String, dynamic>{'name': param.name, 'type': param.type};

  if (param.format case final String format) {
    map['format'] = format;
  }
  if (param.options?.defaultValue case final Object defaultValue) {
    map['default'] = defaultValue;
  }
  if (param.options?.label case final String label) {
    map['label'] = label;
  }
  if (param.options?.description case final String description) {
    map['description'] = description;
  }

  return map;
}

/// Builds the requiredAPIs list.
List<Map<String, String>> _buildRequiredAPIs(
  Map<String, EndpointSpec> endpoints,
) {
  final apis = <Map<String, String>>[
    {
      'api': 'cloudfunctions.googleapis.com',
      'reason': 'Required for Cloud Functions',
    },
  ];

  if (endpoints.values.any((e) => e.type == 'blocking')) {
    apis.add({
      'api': 'identitytoolkit.googleapis.com',
      'reason': 'Needed for auth blocking functions',
    });
  }

  if (endpoints.values.any((e) => e.type == 'scheduler')) {
    apis.add({
      'api': 'cloudscheduler.googleapis.com',
      'reason': 'Needed for scheduled functions',
    });
  }

  return apis;
}

/// Builds a single endpoint entry as a map.
Map<String, dynamic> _buildEndpointMap(EndpointSpec endpoint) {
  final map = <String, dynamic>{
    'entryPoint': endpoint.name,
    'platform': 'gcfv2',
  };

  final options = endpoint.extractOptions();

  // Region
  if (options['region'] case final List<String> regions) {
    map['region'] = regions;
  } else {
    map['region'] = ['us-central1'];
  }

  // Scalar options
  if (options['availableMemoryMb'] case final Object v) {
    map['availableMemoryMb'] = v;
  }
  if (options['cpu'] case final Object v) {
    map['cpu'] = v;
  }
  if (options['timeoutSeconds'] case final Object v) {
    map['timeoutSeconds'] = v;
  }
  if (options['concurrency'] case final Object v) {
    map['concurrency'] = v;
  }
  if (options['minInstances'] case final Object v) {
    map['minInstances'] = v;
  }
  if (options['maxInstances'] case final Object v) {
    map['maxInstances'] = v;
  }
  if (options['serviceAccount'] case final Object v) {
    map['serviceAccountEmail'] = v;
  }

  // VPC (nested structure)
  if (options.containsKey('vpcConnector') ||
      options.containsKey('vpcConnectorEgressSettings')) {
    final vpc = <String, dynamic>{};
    if (options['vpcConnector'] case final Object v) {
      vpc['connector'] = v;
    }
    if (options['vpcConnectorEgressSettings'] case final Object v) {
      vpc['egressSettings'] = v;
    }
    map['vpc'] = vpc;
  }

  if (options['ingressSettings'] case final Object v) {
    map['ingressSettings'] = v;
  }
  if (options['omit'] case final Object v) {
    map['omit'] = v;
  }

  // Labels
  if (options['labels'] case final Map<String, String> labels) {
    map['labels'] = labels;
  }

  // Secrets
  if (options['secretEnvironmentVariables'] case final List<String> secrets) {
    map['secretEnvironmentVariables'] = [
      for (final secret in secrets) {'key': secret, 'secret': secret},
    ];
  }

  // Trigger configuration
  _addTrigger(map, endpoint, options);

  return map;
}

/// Adds the appropriate trigger configuration to the endpoint map.
void _addTrigger(
  Map<String, dynamic> map,
  EndpointSpec endpoint,
  Map<String, dynamic> options,
) {
  switch (endpoint.type) {
    case 'https':
      final httpsTrigger = <String, dynamic>{};
      if (options['invoker'] case final List<String>? invokers) {
        httpsTrigger['invoker'] = invokers ?? <String>[];
      }
      map['httpsTrigger'] = httpsTrigger;

    case 'callable':
      map['callableTrigger'] = <String, dynamic>{};

    case 'pubsub' when endpoint.topic != null:
      map['eventTrigger'] = <String, dynamic>{
        'eventType': 'google.cloud.pubsub.topic.v1.messagePublished',
        'eventFilters': {'topic': endpoint.topic},
        'retry': false,
      };

    case 'firestore'
        when endpoint.firestoreEventType != null &&
            endpoint.documentPath != null:
      final eventType = _mapFirestoreEventType(endpoint.firestoreEventType!);
      final trigger = <String, dynamic>{
        'eventType': eventType,
        'eventFilters': {
          'database': endpoint.database ?? '(default)',
          'namespace': endpoint.namespace ?? '(default)',
        },
      };

      final hasWildcards = endpoint.documentPath!.contains('{');
      if (hasWildcards) {
        trigger['eventFilterPathPatterns'] = {
          'document': endpoint.documentPath,
        };
      } else {
        (trigger['eventFilters'] as Map<String, dynamic>)['document'] =
            endpoint.documentPath;
      }

      trigger['retry'] = false;
      map['eventTrigger'] = trigger;

    case 'database'
        when endpoint.databaseEventType != null && endpoint.refPath != null:
      final eventType = _mapDatabaseEventType(endpoint.databaseEventType!);
      final normalizedRef = endpoint.refPath!.startsWith('/')
          ? endpoint.refPath!.substring(1)
          : endpoint.refPath!;

      map['eventTrigger'] = <String, dynamic>{
        'eventType': eventType,
        'eventFilters': <String, dynamic>{},
        'eventFilterPathPatterns': {
          'ref': normalizedRef,
          'instance': endpoint.instance ?? '*',
        },
        'retry': false,
      };

    case 'alert' when endpoint.alertType != null:
      final filters = <String, dynamic>{'alerttype': endpoint.alertType};
      if (endpoint.appId != null) {
        filters['appid'] = endpoint.appId;
      }
      map['eventTrigger'] = <String, dynamic>{
        'eventType': 'google.firebase.firebasealerts.alerts.v1.published',
        'eventFilters': filters,
        'retry': false,
      };

    case 'blocking' when endpoint.blockingEventType != null:
      final triggerOptions = <String, dynamic>{};
      final isAuthEvent =
          endpoint.blockingEventType == 'beforeCreate' ||
          endpoint.blockingEventType == 'beforeSignIn';

      if (isAuthEvent) {
        if (endpoint.idToken ?? false) {
          triggerOptions['idToken'] = true;
        }
        if (endpoint.accessToken ?? false) {
          triggerOptions['accessToken'] = true;
        }
        if (endpoint.refreshToken ?? false) {
          triggerOptions['refreshToken'] = true;
        }
      }

      map['blockingTrigger'] = <String, dynamic>{
        'eventType':
            'providers/cloud.auth/eventTypes/user.${endpoint.blockingEventType}',
        'options': triggerOptions,
      };

    case 'scheduler' when endpoint.schedule != null:
      final trigger = <String, dynamic>{'schedule': endpoint.schedule};
      if (endpoint.timeZone != null) {
        trigger['timeZone'] = endpoint.timeZone;
      }
      if (endpoint.retryConfig != null && endpoint.retryConfig!.isNotEmpty) {
        final rc = <String, dynamic>{};
        final config = endpoint.retryConfig!;
        if (config['retryCount'] case final Object v) rc['retryCount'] = v;
        if (config['maxRetrySeconds'] case final Object v) {
          rc['maxRetrySeconds'] = v;
        }
        if (config['minBackoffSeconds'] case final Object v) {
          rc['minBackoffSeconds'] = v;
        }
        if (config['maxBackoffSeconds'] case final Object v) {
          rc['maxBackoffSeconds'] = v;
        }
        if (config['maxDoublings'] case final Object v) {
          rc['maxDoublings'] = v;
        }
        trigger['retryConfig'] = rc;
      }
      map['scheduleTrigger'] = trigger;
  }
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
