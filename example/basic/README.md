# Basic Firebase Functions Example

This example demonstrates the core functionality of Firebase Functions for Dart.

## Features Demonstrated

### HTTPS Functions

1. **onRequest** - Raw HTTP handler
   - Endpoint: `/helloWorld`
   - Returns plain text response

2. **onCall** - Callable function (untyped)
   - Endpoint: `/greet`
   - Accepts JSON: `{"data": {"name": "Alice"}}`
   - Returns: `{"result": {"message": "Hello Alice!"}}`

3. **onCall with Streaming** - Server-Sent Events
   - Endpoint: `/streamNumbers`
   - Streams 5 numbers with delays
   - Set `Accept: text/event-stream` header

### Pub/Sub Triggers

4. **onMessagePublished** - Pub/Sub message handler
   - Triggered by messages to `my-topic`
   - Logs message details to console

## Running

### Install Dependencies

```bash
dart pub get
```

### Run Locally

```bash
dart run lib/main.dart
```

The server will start on `http://localhost:8080`.

### Test HTTPS Functions

```bash
# onRequest
curl http://localhost:8080/helloWorld

# onCall
curl -X POST http://localhost:8080/greet \
  -H "Content-Type: application/json" \
  -d '{"data": {"name": "Alice"}}'

# onCall with streaming
curl -X POST http://localhost:8080/streamNumbers \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{"data": {}}'
```

### Test Pub/Sub Trigger

Send a CloudEvent POST request:

```bash
curl -X POST http://localhost:8080/onMessagePublished_my-topic \
  -H "Content-Type: application/json" \
  -d '{
    "specversion": "1.0",
    "type": "google.cloud.pubsub.topic.v1.messagePublished",
    "source": "//pubsub.googleapis.com/projects/my-project/topics/my-topic",
    "id": "test-123",
    "time": "2024-01-01T12:00:00Z",
    "data": {
      "message": {
        "data": "SGVsbG8gV29ybGQh",
        "attributes": {"key": "value"},
        "messageId": "123456",
        "publishTime": "2024-01-01T12:00:00Z"
      },
      "subscription": "projects/my-project/subscriptions/my-sub"
    }
  }'
```

Note: The data `SGVsbG8gV29ybGQh` is base64-encoded "Hello World!"

## With Firebase Emulator

```bash
firebase emulators:start --only functions
```

The emulator will automatically detect the Dart runtime and start your functions.
