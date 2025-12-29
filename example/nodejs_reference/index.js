/**
 * Reference Node.js implementation matching the Dart example.
 * This is used for snapshot testing to ensure the Dart builder
 * generates compatible functions.yaml output.
 */

const { onRequest } = require("firebase-functions/v2/https");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const { defineString, defineInt, defineBoolean } = require("firebase-functions/params");

// =============================================================================
// Parameterized Configuration Examples
// =============================================================================

// Define parameters - these are read from environment variables at runtime
// and can be configured at deploy time via .env files or CLI prompts.
const welcomeMessage = defineString("WELCOME_MESSAGE", {
  default: "Hello from Dart Functions!",
  label: "Welcome Message",
  description: "The greeting message returned by the helloWorld function",
});

const minInstances = defineInt("MIN_INSTANCES", {
  default: 0,
  label: "Minimum Instances",
  description: "Minimum number of instances to keep warm",
});

const isProduction = defineBoolean("IS_PRODUCTION", {
  default: false,
  description: "Whether this is a production deployment",
});

// HTTPS onRequest example - using parameterized configuration
exports.helloWorld = onRequest(
  {
    // Use parameters in options - evaluated at deploy time
    minInstances: minInstances,
  },
  (request, response) => {
    // Access parameter value at runtime
    response.send(welcomeMessage.value());
  }
);

// Conditional configuration based on boolean parameter
exports.configuredEndpoint = onRequest(
  {
    // Use thenElse for conditional configuration at deploy time
    // isProduction.thenElse(trueValue, falseValue) returns an expression
    memory: isProduction.thenElse(2048, 512),
  },
  (request, response) => {
    // Access parameter value at runtime
    const env = isProduction.value() ? "production" : "development";
    response.send(`Running in ${env} mode`);
  }
);

// Pub/Sub trigger example
exports.onMessagePublished_mytopic = onMessagePublished(
  "my-topic",
  (event) => {
    const message = event.data.message;
    console.log("Received Pub/Sub message:");
    console.log("  ID:", message.messageId);
    console.log("  Published:", message.publishTime);
    console.log("  Data:", message.data ? Buffer.from(message.data, "base64").toString() : "");
    console.log("  Attributes:", message.attributes);
  }
);
