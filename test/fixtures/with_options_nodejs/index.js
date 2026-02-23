/**
 * Node.js reference with ALL HTTP function options.
 * Used to verify Dart builder generates identical YAML output.
 */

const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");

// Test 1: HTTPS onRequest with ALL options
exports.httpsFull = onRequest(
  {
    memory: "512MiB",
    cpu: 1,
    region: "us-central1",
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 80,
    serviceAccount: "test@example.com",
    vpcConnector: "projects/test/locations/us-central1/connectors/vpc",
    vpcConnectorEgressSettings: "PRIVATE_RANGES_ONLY",
    ingressSettings: "ALLOW_ALL",
    invoker: "public",
    labels: {
      environment: "test",
      team: "backend"
    },
    omit: false,
    // Runtime-only (NOT in manifest)
    preserveExternalChanges: true,
    cors: ["https://example.com", "https://app.example.com"]
  },
  (request, response) => {
    response.send("HTTPS with all options");
  }
);

// Test 2: Callable with ALL options
exports.callableFull = onCall(
  {
    memory: "1GiB",
    cpu: 2,
    region: "us-east1",
    timeoutSeconds: 300,
    minInstances: 1,
    maxInstances: 100,
    concurrency: 80,
    invoker: "private",
    labels: {
      type: "callable"
    },
    // Runtime-only (NOT in manifest)
    enforceAppCheck: true,
    consumeAppCheckToken: true,
    heartbeatSeconds: 30,
    cors: true
  },
  (request) => {
    return { message: "Callable with all options" };
  }
);

// Test 3: GCF Gen1 CPU
exports.httpsGen1 = onRequest(
  {
    cpu: "gcf_gen1"
  },
  (request, response) => {
    response.send("GCF Gen1 CPU");
  }
);

// Test 4: Custom invoker list
exports.httpsCustomInvoker = onRequest(
  {
    invoker: ["user1@example.com", "user2@example.com"]
  },
  (request, response) => {
    response.send("Custom invoker");
  }
);

// Test 5: Pub/Sub with options
exports.onMessagePublished_optionstopic = onMessagePublished(
  {
    topic: "options-topic",
    memory: "256MiB",
    timeoutSeconds: 120,
    region: "us-west1"
  },
  (event) => {
    console.log("Pub/Sub with options");
  }
);
