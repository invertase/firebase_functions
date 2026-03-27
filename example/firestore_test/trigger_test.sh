#!/bin/bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


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
