#!/bin/bash
#
# Local validation script to test CI workflows before committing.
# This simulates the GitHub Actions environment locally.
#
# Usage: .github/workflows/validate-local.sh

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "========================================="
echo "Firebase Functions Dart - Local CI Check"
echo "========================================="
echo ""

cd "$ROOT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if commands exist
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}✗${NC} $1 not found. Please install it."
        exit 1
    fi
    echo -e "${GREEN}✓${NC} $1 found"
}

echo "Checking prerequisites..."
check_command dart
check_command node
check_command npm
check_command curl
echo ""

# 1. Dart Analysis
echo "========================================="
echo "1. Running Dart Analysis"
echo "========================================="
echo ""

echo "Installing dependencies..."
dart pub get

echo "Checking formatting..."
if dart format --output=none --set-exit-if-changed .; then
    echo -e "${GREEN}✓${NC} Code is formatted correctly"
else
    echo -e "${RED}✗${NC} Code formatting issues found"
    echo "Run: dart format ."
    exit 1
fi

echo "Running analyzer..."
if dart analyze --fatal-infos; then
    echo -e "${GREEN}✓${NC} No analysis issues"
else
    echo -e "${RED}✗${NC} Analysis failed"
    exit 1
fi

echo ""

# 2. Unit Tests
echo "========================================="
echo "2. Running Unit Tests"
echo "========================================="
echo ""

if dart test --exclude-tags=snapshot,integration; then
    echo -e "${GREEN}✓${NC} Unit tests passed"
else
    echo -e "${RED}✗${NC} Unit tests failed"
    exit 1
fi

echo ""

# 3. Builder Tests
echo "========================================="
echo "3. Running Builder Tests"
echo "========================================="
echo ""

echo "Installing example dependencies..."
cd example/basic
dart pub get

echo "Running build_runner..."
if dart run build_runner build --delete-conflicting-outputs; then
    echo -e "${GREEN}✓${NC} Build completed"
else
    echo -e "${RED}✗${NC} Build failed"
    exit 1
fi

echo "Checking generated manifest..."
if [ ! -f ".dart_tool/firebase/functions.yaml" ]; then
    echo -e "${RED}✗${NC} functions.yaml not generated"
    exit 1
fi

echo -e "${GREEN}✓${NC} Manifest generated successfully"
echo ""
echo "Generated manifest:"
cat .dart_tool/firebase/functions.yaml

cd "$ROOT_DIR"
echo ""

# 4. Snapshot Tests
echo "========================================="
echo "4. Running Snapshot Tests"
echo "========================================="
echo ""

echo "Installing Node.js dependencies..."
cd example/nodejs_reference
npm ci

echo "Starting firebase-functions server..."
GCLOUD_PROJECT="test-project" \
PORT="8080" \
FUNCTIONS_CONTROL_API="true" \
npx firebase-functions > /tmp/ff-local.log 2>&1 &

FF_PID=$!
echo "Server PID: $FF_PID"

echo "Waiting for server to start..."
for i in {1..30}; do
    if curl -s http://localhost:8080/__/functions.yaml > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Server ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗${NC} Server failed to start"
        cat /tmp/ff-local.log
        exit 1
    fi
    sleep 1
done

echo "Fetching Node.js manifest..."
if curl -s http://localhost:8080/__/functions.yaml | python3 -m json.tool > nodejs_manifest.json; then
    echo -e "${GREEN}✓${NC} Node.js manifest generated"
else
    echo -e "${RED}✗${NC} Failed to fetch manifest"
    kill $FF_PID 2>/dev/null || true
    exit 1
fi

echo "Stopping server..."
kill $FF_PID 2>/dev/null || true
sleep 1

cd "$ROOT_DIR"

echo "Running snapshot comparison tests..."
if dart test test/snapshots/manifest_snapshot_test.dart; then
    echo -e "${GREEN}✓${NC} Snapshot tests passed"
else
    echo -e "${RED}✗${NC} Snapshot tests failed"
    echo ""
    echo "Dart manifest:"
    cat example/basic/.dart_tool/firebase/functions.yaml
    echo ""
    echo "Node.js manifest:"
    cat example/nodejs_reference/nodejs_manifest.json
    exit 1
fi

echo ""

# Summary
echo "========================================="
echo "✅ All Checks Passed!"
echo "========================================="
echo ""
echo "Your changes are ready to push:"
echo "  1. Format:  ✓"
echo "  2. Analyze: ✓"
echo "  3. Tests:   ✓"
echo "  4. Builder: ✓"
echo "  5. Snapshots: ✓"
echo ""
echo "GitHub Actions should pass! 🚀"
