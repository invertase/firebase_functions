/**
 * Script to extract the functions manifest from the Node.js SDK.
 * This mimics what firebase-tools does when discovering functions,
 * and produces a JSON manifest compatible with the Dart builder output.
 *
 * Usage: node extract-manifest.js
 * Output: nodejs_manifest.json
 */

const fs = require("fs");
const path = require("path");

// Load the functions module (this registers params and defines exports)
const functionsModule = require("./index.js");

// Access the internal params registry
const params = require("firebase-functions/params");

// =============================================================================
// Param extraction
// =============================================================================

function extractParams() {
  const declaredParams = params.declaredParams;
  if (!Array.isArray(declaredParams) || declaredParams.length === 0) {
    return [];
  }

  return declaredParams.map((p) => {
    const typeMap = {
      StringParam: "string",
      IntParam: "int",
      BooleanParam: "boolean",
      FloatParam: "float",
      ListParam: "list",
    };

    const result = { name: p.name };

    const paramType = typeMap[p.constructor.name];
    if (paramType) result.type = paramType;

    if (p.options) {
      if (p.options.default !== undefined) result.default = p.options.default;
      if (p.options.label) result.label = p.options.label;
      if (p.options.description) result.description = p.options.description;
    }

    return result;
  });
}

// =============================================================================
// Endpoint extraction
// =============================================================================

function extractEndpoints(mod) {
  const endpoints = {};

  for (const [key, value] of Object.entries(mod)) {
    if (typeof value === "function" && value.__endpoint) {
      endpoints[key] = normalizeEndpoint(key, value.__endpoint);
    }
  }

  return endpoints;
}

function normalizeEndpoint(name, endpoint) {
  const result = { entryPoint: name };

  result.platform = endpoint.platform || "gcfv2";

  const region = wireValue(endpoint.region);
  if (region && Array.isArray(region) && region.length > 0) {
    result.region = region;
  } else {
    result.region = ["us-central1"];
  }

  copyIfNonNull(result, endpoint, "availableMemoryMb");
  copyIfNonNull(result, endpoint, "timeoutSeconds");
  copyIfNonNull(result, endpoint, "minInstances");
  copyIfNonNull(result, endpoint, "maxInstances");
  copyIfNonNull(result, endpoint, "concurrency");
  copyIfNonNull(result, endpoint, "serviceAccountEmail");
  copyIfNonNull(result, endpoint, "ingressSettings");
  copyIfNonNull(result, endpoint, "cpu");

  if (endpoint.omit === true || endpoint.omit === false) {
    result.omit = endpoint.omit;
  }

  if (endpoint.labels && Object.keys(endpoint.labels).length > 0) {
    result.labels = endpoint.labels;
  }

  if (endpoint.vpc && typeof endpoint.vpc === "object") {
    const vpc = {};
    if (endpoint.vpc.connector) vpc.connector = endpoint.vpc.connector;
    if (endpoint.vpc.egressSettings) vpc.egressSettings = endpoint.vpc.egressSettings;
    if (Object.keys(vpc).length > 0) {
      result.vpc = vpc;
    }
  }

  if (endpoint.callableTrigger !== undefined) {
    result.callableTrigger = endpoint.callableTrigger || {};
  } else if (endpoint.httpsTrigger !== undefined) {
    result.httpsTrigger = normalizeHttpsTrigger(endpoint.httpsTrigger);
  } else if (endpoint.eventTrigger) {
    result.eventTrigger = normalizeEventTrigger(endpoint.eventTrigger);
  } else if (endpoint.blockingTrigger) {
    result.blockingTrigger = normalizeBlockingTrigger(endpoint.blockingTrigger);
  } else if (endpoint.scheduleTrigger) {
    result.scheduleTrigger = normalizeScheduleTrigger(endpoint.scheduleTrigger);
  }

  return result;
}

function normalizeHttpsTrigger(trigger) {
  if (!trigger || typeof trigger !== "object") return {};
  const result = {};
  if (trigger.invoker && Array.isArray(trigger.invoker) && trigger.invoker.length > 0) {
    result.invoker = trigger.invoker;
  }
  return result;
}

function normalizeEventTrigger(trigger) {
  const result = {};
  if (trigger.eventType) result.eventType = trigger.eventType;
  if (trigger.eventFilters) result.eventFilters = trigger.eventFilters;
  if (trigger.eventFilterPathPatterns) result.eventFilterPathPatterns = trigger.eventFilterPathPatterns;
  result.retry = trigger.retry === true ? true : false;
  return result;
}

function normalizeBlockingTrigger(trigger) {
  const result = {};
  if (trigger.eventType) result.eventType = trigger.eventType;
  const options = {};
  if (trigger.options) {
    for (const [key, value] of Object.entries(trigger.options)) {
      if (value === true) options[key] = true;
    }
  }
  result.options = options;
  return result;
}

function normalizeScheduleTrigger(trigger) {
  const result = {};
  if (trigger.schedule) result.schedule = trigger.schedule;
  const tz = wireValue(trigger.timeZone);
  if (tz) result.timeZone = tz;
  if (trigger.retryConfig && typeof trigger.retryConfig === "object") {
    const rc = {};
    for (const [key, value] of Object.entries(trigger.retryConfig)) {
      const wired = wireValue(value);
      if (wired !== undefined && wired !== null) rc[key] = wired;
    }
    if (Object.keys(rc).length > 0) result.retryConfig = rc;
  }
  return result;
}

function copyIfNonNull(target, source, key) {
  const value = wireValue(source[key]);
  if (value !== null && value !== undefined) {
    target[key] = value;
  }
}

function wireValue(value) {
  if (value === null || value === undefined) return value;

  if (value && typeof value === "object" && !Array.isArray(value)) {
    if (value.constructor?.name === "ResetValue") return null;

    const str = value.toString();
    if (str && str.startsWith("params.")) {
      return `{{ ${str} }}`;
    }
  }

  if (Array.isArray(value)) return value.map(wireValue);

  return value;
}

// =============================================================================
// RequiredAPIs extraction
// =============================================================================

function extractRequiredAPIs(mod) {
  const apiMap = new Map();
  apiMap.set("cloudfunctions.googleapis.com", "Required for Cloud Functions");

  for (const [, value] of Object.entries(mod)) {
    if (typeof value === "function" && Array.isArray(value.__requiredAPIs)) {
      for (const api of value.__requiredAPIs) {
        if (api.api && !apiMap.has(api.api)) {
          const reason = (api.reason || "").replace(/\.$/, "");
          apiMap.set(api.api, reason);
        }
      }
    }
  }

  return Array.from(apiMap.entries()).map(([api, reason]) => ({ api, reason }));
}

// =============================================================================
// Main
// =============================================================================

const paramsList = extractParams();
const endpoints = extractEndpoints(functionsModule);
const requiredAPIs = extractRequiredAPIs(functionsModule);

const manifest = {
  specVersion: "v1alpha1",
  params: paramsList.length > 0 ? paramsList : undefined,
  requiredAPIs,
  endpoints,
};

const outputPath = path.join(__dirname, "nodejs_manifest.json");
const json = JSON.stringify(manifest, null, 4) + "\n";
fs.writeFileSync(outputPath, json, "utf8");

console.log(`Manifest written to ${outputPath}`);
console.log(`  Params: ${paramsList.length}`);
console.log(`  RequiredAPIs: ${requiredAPIs.length}`);
console.log(`  Endpoints: ${Object.keys(endpoints).length}`);
