#!/bin/bash

# This script runs the firebase-functions server, waits for it, fetches functions.yaml, and kills the server.
# It assumes it is run from the root of the repository.

cd test/fixtures/nodejs_reference || exit 1

echo "Starting firebase-functions server..."
GCLOUD_PROJECT="test-project" \
PORT="8080" \
FUNCTIONS_CONTROL_API="true" \
npx firebase-functions > /tmp/ff.log 2>&1 &

FF_PID=$!
echo "Server PID: $FF_PID"

# Wait for server to be ready
echo "Waiting for server to start..."
for i in {1..30}; do
  if curl -s http://localhost:8080/__/functions.yaml > /dev/null 2>&1; then
    echo "✓ Server is ready"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "Error: Server failed to start"
    cat /tmp/ff.log
    exit 1
  fi
  sleep 1
done

# Fetch manifest
echo "Fetching manifest..."
curl -s http://localhost:8080/__/functions.yaml | python3 -m json.tool > nodejs_manifest.json

# Stop server
kill $FF_PID 2>/dev/null || true

echo "Node.js manifest generated:"
cat nodejs_manifest.json
