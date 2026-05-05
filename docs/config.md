## Parameters & Configuration

### Defining Parameters

```dart
final welcomeMessage = defineString(
  'WELCOME_MESSAGE',
  ParamOptions(
    defaultValue: 'Hello from Dart!',
    label: 'Welcome Message',
    description: 'The greeting message returned by the function',
  ),
);

final minInstances = defineInt(
  'MIN_INSTANCES',
  ParamOptions(defaultValue: 0),
);

final isProduction = defineBoolean(
  'IS_PRODUCTION',
  ParamOptions(defaultValue: false),
);
```

### Using Parameters at Runtime

```dart
firebase.https.onRequest(
  name: 'hello',
  (request) async {
    return Response.ok(welcomeMessage.value());
  },
);
```

### Using Parameters in Options (Deploy-time)

```dart
firebase.https.onRequest(
  name: 'configured',
  options: HttpsOptions(
    minInstances: DeployOption.param(minInstances),
  ),
  handler,
);
```

### Conditional Configuration

```dart
firebase.https.onRequest(
  name: 'api',
  options: HttpsOptions(
    // 2GB in production, 512MB in development
    memory: Memory.expression(isProduction.thenElse(2048, 512)),
  ),
  (request) async {
    final env = isProduction.value() ? 'production' : 'development';
    return Response.ok('Running in $env mode');
  },
);
```

