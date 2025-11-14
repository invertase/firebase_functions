/**
 * Reference Node.js implementation matching the Dart example.
 * This is used for snapshot testing to ensure the Dart builder
 * generates compatible functions.yaml output.
 */

const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");

// HTTPS onRequest example
exports.helloWorld = onRequest((request, response) => {
  response.send("Hello from Dart Functions!");
});

// HTTPS onCall example (untyped)
exports.greet = onCall((request) => {
  const name = request.data?.name || "World";
  return { message: `Hello ${name}!` };
});

// HTTPS onCall with streaming example
exports.streamNumbers = onCall((request) => {
  // Note: Streaming in Node.js SDK works differently than our Dart implementation
  // This is just the basic callable version for comparison
  return { message: "Done streaming" };
});

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
