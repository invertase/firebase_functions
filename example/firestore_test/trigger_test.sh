#!/bin/bash

# Test script to create a Firestore document and trigger the function

echo "Creating a test user document..."

curl -X PATCH "http://127.0.0.1:8080/v1/projects/demo-test/databases/(default)/documents/users/test-user-$(date +%s)" \
  -H "Content-Type: application/json" \
  -d '{
    "fields": {
      "name": {"stringValue": "Test User"},
      "email": {"stringValue": "test@example.com"},
      "timestamp": {"timestampValue": "2025-11-28T00:00:00Z"}
    }
  }'

echo ""
echo "Document created! Check the functions logs for output."
