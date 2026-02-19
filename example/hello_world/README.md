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

## Run with the Firebase Emulator

This project requires a fork of `firebase-tools` with Dart runtime support.

### 1. Clone the firebase-tools fork

```bash
git clone -b @invertase/dart https://github.com/invertase/firebase-tools.git
cd firebase-tools
npm install
cd ..
```

### 2. Start the emulator

From the `example/hello_world/` directory, run:

```bash
node <path-to-firebase-tools>/lib/bin/firebase.js emulators:start \
  --only auth,functions \
  --project demo-test
```

For example, if the repo is cloned next to `firebase-functions-dart`:

```bash
node ../../../firebase-tools/lib/bin/firebase.js emulators:start \
  --only auth,functions \
  --project demo-test
```

Add `--debug` for verbose logging. The Emulator UI is available at
`http://localhost:4000`.

### 3. Test with curl

Once the emulator is running, the functions are served at
`http://localhost:5001/demo-test/us-central1/<functionName>`.

**helloWorld** (onRequest — GET or POST):

```bash
curl http://localhost:5001/demo-test/us-central1/helloWorld
# Hello, World!
```

**greet** (onCall — POST JSON):

```bash
curl -X POST http://localhost:5001/demo-test/us-central1/greet \
  -H 'Content-Type: application/json' \
  -d '{"data": {"name": "Alice"}}'
# {"result":{"message":"Hello, Alice!"}}
```

**whoAmI** (onCall — requires auth):

Without authentication this returns a 401 error:

```bash
curl -X POST http://localhost:5001/demo-test/us-central1/whoAmI \
  -H 'Content-Type: application/json' \
  -d '{"data": {}}'
# {"error":{"status":"UNAUTHENTICATED","message":"You must be signed in to call this function"}}
```
