# Firebase Functions Client Demo

A simple web client demonstrating how to call Firebase Functions (both `onRequest` and `onCall`) using the Firebase JavaScript SDK.

## Prerequisites

1. Start the Firebase emulator with the Dart functions:

```bash
cd ../basic
dart pub get
dart run build_runner build --delete-conflicting-outputs
firebase emulators:start --only functions
```

2. Note the Functions URL from the emulator output (usually `http://127.0.0.1:5001/demo-test/us-central1`).

## Running the Client

You can open `index.html` directly in a browser, or serve it with a local server:

```bash
# Using Python
python3 -m http.server 8000

# Using Node.js (npx)
npx serve .

# Using PHP
php -S localhost:8000
```

Then open `http://localhost:8000` in your browser.

## Demos Included

### 1. onRequest - Simple HTTP Endpoint

Calls the `helloWorld` function using a simple `fetch()` request. This demonstrates how `onRequest` functions work like regular HTTP endpoints.

```javascript
const response = await fetch(`${baseUrl}/helloWorld?name=World`);
const text = await response.text();
```

### 2. onCall - Callable Function

Calls the `greet` function using the Firebase SDK's `httpsCallable()`. This handles authentication, CORS, and request/response formatting automatically.

```javascript
import { getFunctions, httpsCallable } from 'firebase/functions';

const functions = getFunctions(app, 'us-central1');
const greet = httpsCallable(functions, 'greet');
const result = await greet({ name: 'Dart Developer' });
// result.data = { message: 'Hello, Dart Developer!' }
```

### 3. onCall - Error Handling

Demonstrates how callable functions handle errors. The `divide` function throws structured errors for invalid input or division by zero.

### 4. onCallWithData - Typed Callable

Calls the `greetTyped` function which uses typed request/response classes on the server side.

### 5. Raw POST to Callable

Shows how to call a callable function without the Firebase SDK using the callable protocol:

```javascript
const response = await fetch(`${baseUrl}/greet`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ data: { name: 'Raw Caller' } })
});
const json = await response.json();
// json = { result: { message: 'Hello, Raw Caller!' } }
```

## Callable Protocol

The Firebase callable protocol wraps data in a specific format:

**Request:**
```json
{
  "data": { /* your input */ }
}
```

**Response:**
```json
{
  "result": { /* function return value */ }
}
```

**Error:**
```json
{
  "error": {
    "status": "INVALID_ARGUMENT",
    "message": "Error description"
  }
}
```

## Troubleshooting

- **CORS errors**: Make sure you're running the Firebase emulator and the Functions URL is correct.
- **Connection refused**: Ensure the emulator is running on the expected port.
- **Function not found**: Verify the function names match between client and server.
