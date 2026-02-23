# GitHub Actions Workflows

This directory contains CI/CD workflows for the Firebase Functions Dart runtime.

## Workflows

### `test.yml` - Comprehensive Test Suite

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual workflow dispatch

**Jobs:**

#### 1. `dart-tests`
Runs Dart package analysis and unit tests on multiple SDK versions.

- **Matrix**: Dart stable and beta SDKs
- **Steps**:
  - Verify code formatting (stable only)
  - Run `dart analyze` with fatal infos
  - Run unit tests (excluding snapshot and integration tests)

#### 2. `builder-tests`
Validates the build_runner code generation system.

- **Steps**:
  - Run build_runner on example project
  - Verify `functions.yaml` is generated
  - Validate YAML syntax
  - Upload generated manifest as artifact

#### 3. `snapshot-tests`
Compares Dart-generated manifest with Node.js reference.

- **Dependencies**: Requires `builder-tests` to complete
- **Steps**:
  - Generate Dart manifest via build_runner
  - Install Node.js dependencies
  - Start firebase-functions HTTP server
  - Fetch Node.js manifest from `/__/functions.yaml` endpoint
  - Run snapshot comparison tests
  - Upload manifests on failure for debugging

#### 4. `test-summary`
Aggregates results from all test jobs.

- **Dependencies**: Runs after all test jobs
- **Purpose**: Single source of truth for overall test status

### `pr-checks.yml` - Fast PR Validation

**Triggers:**
- Pull request opened, synchronized, or reopened

**Features:**
- **Concurrency control**: Cancels in-progress runs when new commits are pushed
- **Fast feedback**: Optimized for quick iteration

**Jobs:**

#### 1. `quick-checks`
Essential code quality checks.

- Formatting verification
- Static analysis
- Unit tests with GitHub reporter

#### 2. `builder-validation`
Ensures builder generates valid manifests.

- Runs build_runner
- Verifies manifest file exists
- Validates basic manifest structure (specVersion, endpoints)

#### 3. `snapshot-check`
Full snapshot tests (only for PRs to `main`).

- Conditional execution based on base branch
- Generates both Dart and Node.js manifests
- Runs compatibility tests

#### 4. `pr-status`
Aggregated PR status check.

## Artifacts

### Dart Manifest
**Name**: `dart-manifest`
**Retention**: 7 days
**Contains**: Generated `functions.yaml` from builder

### Manifests Comparison (on failure)
**Name**: `manifests-comparison`
**Retention**: 30 days
**Contains**: Both Dart and Node.js manifests for debugging

## Environment Variables

### Node.js Manifest Generation

```bash
GCLOUD_PROJECT="test-project"
PORT="8080"
FUNCTIONS_CONTROL_API="true"
```

These enable the firebase-functions HTTP endpoint for manifest extraction.

## Caching

- **Dart packages**: Automatic via `dart-lang/setup-dart`
- **Node.js packages**: Via `setup-node` with npm cache

## Status Badges

Add to README.md:

```markdown
[![Tests](https://github.com/invertase/firebase-functions-dart/actions/workflows/test.yml/badge.svg)](https://github.com/invertase/firebase-functions-dart/actions/workflows/test.yml)
[![PR Checks](https://github.com/invertase/firebase-functions-dart/actions/workflows/pr-checks.yml/badge.svg)](https://github.com/invertase/firebase-functions-dart/actions/workflows/pr-checks.yml)
```

## Debugging Failed Workflows

### Builder Tests Failed

1. Download the `dart-manifest` artifact
2. Check the generated YAML for syntax errors
3. Verify all functions were discovered
4. Compare with expected structure in `CLAUDE.md`

### Snapshot Tests Failed

1. Download the `manifests-comparison` artifact
2. Compare the two manifests side-by-side
3. Check for structural differences:
   - Function naming (hyphens vs underscores)
   - Trigger formats (eventFilters vs resource)
   - Missing fields (retry, platform, etc.)
4. Review `example/MANIFEST_COMPARISON.md` for known differences

### Common Issues

#### Node.js Server Timeout
If "Server failed to start" error occurs:

- Check Node.js version (should be 18+)
- Verify firebase-functions package is installed
- Look for port conflicts (8080)

#### YAML Validation Failed
If YAML syntax errors:

- Check for unquoted special characters
- Verify indentation is consistent
- Ensure all strings are properly quoted

#### Manifest Not Generated
If `functions.yaml` doesn't exist:

- Check build_runner output for errors
- Verify example code has no syntax errors
- Ensure builder is registered in `build.yaml`

## Local Testing

Reproduce CI environment locally:

```bash
# Run formatting check
dart format --output=none --set-exit-if-changed .

# Run analyzer
dart analyze --fatal-infos

# Run unit tests
dart test --exclude-tags=snapshot,integration

# Generate Dart manifest
cd example/basic
dart run build_runner build --delete-conflicting-outputs
cd ../..

# Generate Node.js manifest
cd test/fixtures/nodejs_reference
GCLOUD_PROJECT="test-project" \
PORT="8080" \
FUNCTIONS_CONTROL_API="true" \
npx firebase-functions &

sleep 3
curl -s http://localhost:8080/__/functions.yaml | python3 -m json.tool > nodejs_manifest.json
pkill -f firebase-functions
cd ../..

# Run snapshot tests
dart test test/snapshots/manifest_snapshot_test.dart
```

## Future Enhancements

- [ ] Add code coverage reporting
- [ ] Integration tests with Firebase Emulator Suite
- [ ] Performance benchmarks (cold start, memory usage)
- [ ] E2E deployment tests
- [ ] Nightly builds against Node.js SDK latest
- [ ] Auto-update Node.js reference on upstream releases
- [ ] Publish to pub.dev on release tags
