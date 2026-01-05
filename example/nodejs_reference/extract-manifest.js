/**
 * Script to extract the functions manifest from the Node.js SDK.
 * This mimics what firebase-tools does when discovering functions.
 */

const yaml = require("js-yaml");
const fs = require("fs");
const path = require("path");

// Load the functions module
const functionsModule = require("./index.js");

/**
 * Extract __endpoint metadata from all exported functions.
 */
function extractEndpoints(mod, prefix = "") {
  const endpoints = {};

  for (const [key, value] of Object.entries(mod)) {
    const name = prefix ? `${prefix}.${key}` : key;

    if (typeof value === "function" && value.__endpoint) {
      // Found a function with __endpoint metadata
      endpoints[name] = wireEndpoint(value.__endpoint);
    } else if (typeof value === "object" && value !== null && !Array.isArray(value)) {
      // Recursively search in nested objects
      Object.assign(endpoints, extractEndpoints(value, name));
    }
  }

  return endpoints;
}

/**
 * Convert endpoint metadata to wire format (for YAML).
 * This handles Expression objects and ResetValue.
 */
function wireEndpoint(endpoint) {
  const result = {};

  for (const [key, value] of Object.entries(endpoint)) {
    result[key] = wireValue(value);
  }

  return result;
}

/**
 * Convert a value to wire format.
 */
function wireValue(value) {
  if (value === null || value === undefined) {
    return value;
  }

  // Handle Expression objects (params)
  if (value && typeof value === "object" && value.value !== undefined) {
    // This is a Params.Expression
    if (value.value && value.value.name) {
      return `{{ params.${value.value.name} }}`;
    }
    return value.value;
  }

  // Handle ResetValue
  if (value && typeof value === "object" && value.constructor?.name === "ResetValue") {
    return null;
  }

  // Handle arrays
  if (Array.isArray(value)) {
    return value.map(wireValue);
  }

  // Handle nested objects
  if (typeof value === "object") {
    const result = {};
    for (const [k, v] of Object.entries(value)) {
      result[k] = wireValue(v);
    }
    return result;
  }

  return value;
}

// Extract endpoints
const endpoints = extractEndpoints(functionsModule);

// Build the manifest
const manifest = {
  specVersion: "v1alpha1",
  requiredAPIs: [
    {
      api: "cloudfunctions.googleapis.com",
      reason: "Required for Cloud Functions"
    }
  ],
  endpoints: endpoints
};

// Convert to YAML and write to file
const yamlContent = yaml.dump(manifest, {
  indent: 2,
  lineWidth: -1,
  noRefs: true,
  sortKeys: false
});

const outputPath = path.join(__dirname, "functions.yaml");
fs.writeFileSync(outputPath, yamlContent, "utf8");

console.log(`Manifest written to ${outputPath}`);
console.log("\nGenerated manifest:");
console.log(yamlContent);
