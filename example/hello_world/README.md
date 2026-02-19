# Hello World — Firebase Functions for Dart

A minimal example with three HTTP functions.

| Function     | Trigger     | Description                           |
| ------------ | ----------- | ------------------------------------- |
| `helloWorld` | `onRequest` | Returns `Hello, World!`               |
| `greet`      | `onCall`    | Greeting with a `name` parameter      |
| `whoAmI`     | `onCall`    | Returns caller's auth info (or 401)   |

## Setup

```bash
# From this directory
dart pub get
```

## Generate the manifest

```bash
dart run build_runner build --delete-conflicting-outputs
```

This produces `.dart_tool/firebase/functions.yaml`, which the Firebase CLI
reads to discover your functions.

## Compile the server

```bash
mkdir -p bin
dart compile exe lib/main.dart -o bin/server
```

## Run locally (dev mode)

```bash
dart run lib/main.dart
```

The server starts on `http://localhost:8080` by default.

## Test with curl

### helloWorld (onRequest — GET or POST)

```bash
curl http://localhost:8080/helloWorld
# Hello, World!
```

### greet (onCall — POST JSON)

```bash
curl -X POST http://localhost:8080/greet \
  -H 'Content-Type: application/json' \
  -d '{"data": {"name": "Alice"}}'
# {"result":{"message":"Hello, Alice!"}}
```

### whoAmI (onCall — requires auth)

Without authentication this returns a 401 error:

```bash
curl -X POST http://localhost:8080/whoAmI \
  -H 'Content-Type: application/json' \
  -d '{"data": {}}'
# {"error":{"status":"UNAUTHENTICATED","message":"You must be signed in to call this function"}}
```
