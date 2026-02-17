/**
 * Reference Node.js implementation matching the Dart example.
 * This is used for snapshot testing to ensure the Dart builder
 * generates compatible functions.yaml output.
 */

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onValueCreated, onValueUpdated, onValueDeleted, onValueWritten } = require("firebase-functions/v2/database");
const { onNewFatalIssuePublished } = require("firebase-functions/v2/alerts/crashlytics");
const { onPlanUpdatePublished } = require("firebase-functions/v2/alerts/billing");
const { onThresholdAlertPublished } = require("firebase-functions/v2/alerts/performance");
const { beforeUserCreated, beforeUserSignedIn, beforeOperation } = require("firebase-functions/v2/identity");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onConfigUpdated } = require("firebase-functions/v2/remoteConfig");
const { onObjectFinalized, onObjectArchived, onObjectDeleted, onObjectMetadataUpdated } = require("firebase-functions/v2/storage");
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

// =============================================================================
// HTTPS Callable Functions (onCall)
// =============================================================================

// Basic callable function - untyped data
exports.greet = onCall((request) => {
  const name = request.data?.name ?? "World";
  return { message: `Hello, ${name}!` };
});

// Callable function with typed data (same manifest structure as untyped)
exports.greetTyped = onCall((request) => {
  const name = request.data?.name ?? "World";
  return { message: `Hello, ${name}!` };
});

// Callable function demonstrating error handling
exports.divide = onCall((request) => {
  const a = request.data?.a;
  const b = request.data?.b;

  if (a === undefined || b === undefined) {
    throw new HttpsError("invalid-argument", 'Both "a" and "b" are required');
  }

  if (b === 0) {
    throw new HttpsError("failed-precondition", "Cannot divide by zero");
  }

  return { result: a / b };
});

// Callable function with streaming support
exports.countdown = onCall(
  {
    // heartbeatSeconds is a runtime option, not in manifest
  },
  (request) => {
    // Streaming is handled at runtime, not in manifest
    return { message: "Countdown complete!" };
  }
);

// Callable function demonstrating auth data extraction
exports.getAuthInfo = onCall((request) => {
  const auth = request.auth;

  if (!auth) {
    // User is not authenticated
    return {
      authenticated: false,
      message: "No authentication provided",
    };
  }

  // User is authenticated - return auth info
  return {
    authenticated: true,
    uid: auth.uid,
    token: auth.token, // Decoded JWT claims (email, name, etc.)
  };
});

// =============================================================================
// HTTPS onRequest Functions
// =============================================================================

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

// =============================================================================
// Firestore trigger examples
// =============================================================================

exports.onDocumentCreated_users_userId = onDocumentCreated(
  "users/{userId}",
  (event) => {
    const data = event.data?.data();
    console.log("Document created: users/" + event.params.userId);
    console.log("  Name:", data?.name);
    console.log("  Email:", data?.email);
  }
);

exports.onDocumentUpdated_users_userId = onDocumentUpdated(
  "users/{userId}",
  (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    console.log("Document updated: users/" + event.params.userId);
    console.log("  Before:", before);
    console.log("  After:", after);
  }
);

exports.onDocumentDeleted_users_userId = onDocumentDeleted(
  "users/{userId}",
  (event) => {
    const data = event.data?.data();
    console.log("Document deleted: users/" + event.params.userId);
    console.log("  Final data:", data);
  }
);

exports.onDocumentWritten_users_userId = onDocumentWritten(
  "users/{userId}",
  (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    console.log("Document written: users/" + event.params.userId);
    if (!before && after) {
      console.log("  Operation: CREATE");
    } else if (before && after) {
      console.log("  Operation: UPDATE");
    } else if (before && !after) {
      console.log("  Operation: DELETE");
    }
  }
);

exports.onDocumentCreated_posts_postId_comments_commentId = onDocumentCreated(
  "posts/{postId}/comments/{commentId}",
  (event) => {
    const data = event.data?.data();
    console.log("Comment created: posts/" + event.params.postId + "/comments/" + event.params.commentId);
    console.log("  Text:", data?.text);
    console.log("  Author:", data?.author);
  }
);

// =============================================================================
// Realtime Database trigger examples
// =============================================================================

exports.onValueCreated_messages_messageId = onValueCreated(
  "/messages/{messageId}",
  (event) => {
    const data = event.data?.val();
    console.log("Database value created: messages/" + event.params.messageId);
    console.log("  Data:", data);
    console.log("  Instance:", event.instance);
    console.log("  Ref:", event.ref);
  }
);

exports.onValueUpdated_messages_messageId = onValueUpdated(
  "/messages/{messageId}",
  (event) => {
    const before = event.data?.before?.val();
    const after = event.data?.after?.val();
    console.log("Database value updated: messages/" + event.params.messageId);
    console.log("  Before:", before);
    console.log("  After:", after);
  }
);

exports.onValueDeleted_messages_messageId = onValueDeleted(
  "/messages/{messageId}",
  (event) => {
    const data = event.data?.val();
    console.log("Database value deleted: messages/" + event.params.messageId);
    console.log("  Final data:", data);
  }
);

exports.onValueWritten_messages_messageId = onValueWritten(
  "/messages/{messageId}",
  (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    console.log("Database value written: messages/" + event.params.messageId);
    if (!before?.exists() && after?.exists()) {
      console.log("  Operation: CREATE");
      console.log("  New data:", after.val());
    } else if (before?.exists() && !after?.exists()) {
      console.log("  Operation: DELETE");
      console.log("  Deleted data:", before.val());
    } else {
      console.log("  Operation: UPDATE");
      console.log("  Before:", before?.val());
      console.log("  After:", after?.val());
    }
  }
);

exports.onValueWritten_users_userId_status = onValueWritten(
  "/users/{userId}/status",
  (event) => {
    const after = event.data?.after?.val();
    console.log("User status changed:", event.params.userId);
    console.log("  New status:", after);
  }
);

// =============================================================================
// Firebase Alerts trigger examples
// =============================================================================

// Crashlytics new fatal issue alert
exports.onAlertPublished_crashlytics_newFatalIssue = onNewFatalIssuePublished(
  (event) => {
    console.log("New fatal issue in Crashlytics:");
    console.log("  Issue ID:", event.data?.payload?.issue?.id);
    console.log("  App ID:", event.appId);
  }
);

// Billing plan update alert
exports.onAlertPublished_billing_planUpdate = onPlanUpdatePublished(
  (event) => {
    console.log("Billing plan updated:");
    console.log("  New Plan:", event.data?.payload?.billingPlan);
  }
);

// Performance threshold alert with app ID filter
exports.onAlertPublished_performance_threshold = onThresholdAlertPublished(
  { appId: "1:123456789:ios:abcdef" },
  (event) => {
    console.log("Performance threshold exceeded:");
    console.log("  Event:", event.data?.payload?.eventName);
  }
);

// =============================================================================
// Identity Platform (Auth Blocking) trigger examples
// =============================================================================

// Before user created - with idToken and accessToken options
exports.beforeCreate = beforeUserCreated(
  { idToken: true, accessToken: true },
  (event) => {
    console.log("Before user created:", event.data?.uid);
    return {};
  }
);

// Before user signed in - with idToken only
exports.beforeSignIn = beforeUserSignedIn(
  { idToken: true },
  (event) => {
    console.log("Before user signed in:", event.data?.uid);
    return {};
  }
);

// Before email sent - no token options
exports.beforeSendEmail = beforeOperation(
  "beforeSendEmail",
  (event) => {
    console.log("Before email sent");
    return {};
  }
);

// Before SMS sent - no token options
exports.beforeSendSms = beforeOperation(
  "beforeSendSms",
  (event) => {
    console.log("Before SMS sent");
    return {};
  }
);

// =============================================================================
// Remote Config trigger examples
// =============================================================================

// Remote Config update trigger
exports.onConfigUpdated = onConfigUpdated(
  (event) => {
    console.log("Remote Config updated:");
    console.log("  Version:", event.data?.versionNumber);
    console.log("  Description:", event.data?.description);
    console.log("  Update Origin:", event.data?.updateOrigin);
    console.log("  Update Type:", event.data?.updateType);
    console.log("  Updated By:", event.data?.updateUser?.email);
  }
);

// =============================================================================
// Cloud Storage trigger examples
// =============================================================================

// Storage onObjectFinalized - triggers when an object is created/overwritten
exports.onObjectFinalized_demotestfirebasestorageapp = onObjectFinalized(
  { bucket: "demo-test.firebasestorage.app" },
  (event) => {
    console.log("Object finalized in bucket:", event.data.bucket);
    console.log("  Name:", event.data.name);
    console.log("  Content Type:", event.data.contentType);
    console.log("  Size:", event.data.size);
  }
);

// Storage onObjectArchived - triggers when an object is archived
exports.onObjectArchived_demotestfirebasestorageapp = onObjectArchived(
  { bucket: "demo-test.firebasestorage.app" },
  (event) => {
    console.log("Object archived in bucket:", event.data.bucket);
    console.log("  Name:", event.data.name);
    console.log("  Storage Class:", event.data.storageClass);
  }
);

// Storage onObjectDeleted - triggers when an object is deleted
exports.onObjectDeleted_demotestfirebasestorageapp = onObjectDeleted(
  { bucket: "demo-test.firebasestorage.app" },
  (event) => {
    console.log("Object deleted in bucket:", event.data.bucket);
    console.log("  Name:", event.data.name);
  }
);

// Storage onObjectMetadataUpdated - triggers when object metadata changes
exports.onObjectMetadataUpdated_demotestfirebasestorageapp = onObjectMetadataUpdated(
  { bucket: "demo-test.firebasestorage.app" },
  (event) => {
    console.log("Object metadata updated in bucket:", event.data.bucket);
    console.log("  Name:", event.data.name);
    console.log("  Metadata:", event.data.metadata);
  }
);

// =============================================================================
// Scheduler trigger examples
// =============================================================================

// Basic scheduled function - runs every day at midnight
exports.onSchedule_0_0___ = onSchedule(
  "0 0 * * *",
  (event) => {
    console.log("Daily midnight function triggered");
  }
);

// Scheduled function with timezone, retry config, and memory
// Note: Node.js SDK uses flat retryConfig fields (not nested)
exports.onSchedule_0_9___15 = onSchedule(
  {
    schedule: "0 9 * * 1-5",
    timeZone: "America/New_York",
    retryCount: 3,
    maxRetrySeconds: 60,
    minBackoffSeconds: 5,
    maxBackoffSeconds: 30,
    memory: "256MiB",
  },
  (event) => {
    console.log("Weekday morning report triggered");
  }
);
