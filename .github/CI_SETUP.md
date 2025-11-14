# CI/CD Setup Guide

This document explains the complete CI/CD infrastructure for Firebase Functions Dart.

## Overview

We have two main workflows:
1. **`test.yml`** - Comprehensive test suite for main/develop branches
2. **`pr-checks.yml`** - Fast validation for pull requests

Both workflows ensure code quality, builder functionality, and compatibility with the Node.js SDK.

## Workflow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Actions                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  On Push/PR to main/develop:                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ test.yml - Comprehensive Test Suite                │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │                                                     │   │
│  │  1. dart-tests (matrix: stable, beta)              │   │
│  │     - Format check                                 │   │
│  │     - Static analysis                              │   │
│  │     - Unit tests                                   │   │
│  │                                                     │   │
│  │  2. builder-tests                                  │   │
│  │     - Run build_runner                             │   │
│  │     - Verify functions.yaml exists                 │   │
│  │     - Validate YAML syntax                         │   │
│  │     - Upload artifact                              │   │
│  │                                                     │   │
│  │  3. snapshot-tests (needs: builder-tests)          │   │
│  │     - Generate Dart manifest                       │   │
│  │     - Generate Node.js manifest (via HTTP API)     │   │
│  │     - Run comparison tests                         │   │
│  │     - Upload artifacts on failure                  │   │
│  │                                                     │   │
│  │  4. test-summary                                   │   │
│  │     - Aggregate results                            │   │
│  │     - Report overall status                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  On PR opened/updated:                                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ pr-checks.yml - Fast PR Validation                 │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │                                                     │   │
│  │  1. quick-checks                                   │   │
│  │     - Format check                                 │   │
│  │     - Static analysis                              │   │
│  │     - Unit tests (GitHub reporter)                 │   │
│  │                                                     │   │
│  │  2. builder-validation                             │   │
│  │     - Generate manifest                            │   │
│  │     - Basic structure validation                   │   │
│  │                                                     │   │
│  │  3. snapshot-check (if base = main)                │   │
│  │     - Full snapshot tests                          │   │
│  │                                                     │   │
│  │  4. pr-status                                      │   │
│  │     - Aggregated status                            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Concurrency: Cancel in-progress on new push              │
└─────────────────────────────────────────────────────────────┘
```

## Snapshot Testing Flow

The snapshot tests ensure our Dart builder generates manifests compatible with the Node.js SDK:

```
┌─────────────────────┐
│ Dart Example        │
│ example/basic/      │
└──────┬──────────────┘
       │
       │ dart run build_runner build
       ▼
┌─────────────────────────────────────┐
│ Generated Manifest                  │
│ .dart_tool/firebase/functions.yaml  │
└──────┬──────────────────────────────┘
       │
       │ Parse YAML → JSON
       ▼
┌─────────────────────┐         ┌────────────────────────┐
│ Dart Manifest JSON  │ ◄─────► │ Node.js Manifest JSON  │
└─────────────────────┘ Compare └──────┬─────────────────┘
                                       │
                                       │ Fetch from HTTP
                                       ▼
                         ┌──────────────────────────────┐
                         │ firebase-functions Server    │
                         │ localhost:8080               │
                         │ /__/functions.yaml           │
                         └──────┬───────────────────────┘
                                │
                                │ npx firebase-functions
                                ▼
                         ┌──────────────────────────────┐
                         │ Node.js Example              │
                         │ example/nodejs_reference/    │
                         └──────────────────────────────┘
```

### Snapshot Test Assertions

1. **Spec Version**: Both use `v1alpha1`
2. **Endpoint Count**: Same number of functions discovered
3. **Function Names**: Match (with topic sanitization)
4. **Trigger Types**: Correct trigger for each function type
5. **Event Structure**: CloudEvent v2 format for Pub/Sub
6. **Platform**: Both use `gcfv2`

## Local Validation

Before pushing, run the local validation script:

```bash
.github/workflows/validate-local.sh
```

This simulates the CI environment and runs:
- Formatting checks
- Static analysis
- Unit tests
- Builder generation
- Snapshot tests

**Expected output:**
```
=========================================
✅ All Checks Passed!
=========================================

Your changes are ready to push:
  1. Format:  ✓
  2. Analyze: ✓
  3. Tests:   ✓
  4. Builder: ✓
  5. Snapshots: ✓

GitHub Actions should pass! 🚀
```

## Status Badges

Add to your README or PR description:

```markdown
[![Tests](https://github.com/invertase/firebase-functions-dart/actions/workflows/test.yml/badge.svg)](https://github.com/invertase/firebase-functions-dart/actions/workflows/test.yml)
[![PR Checks](https://github.com/invertase/firebase-functions-dart/actions/workflows/pr-checks.yml/badge.svg)](https://github.com/invertase/firebase-functions-dart/actions/workflows/pr-checks.yml)
```

## Artifacts

### Success Artifacts

**`dart-manifest`** (always uploaded on builder-tests)
- Contains: `functions.yaml`
- Retention: 7 days
- Use: Verify builder output

### Failure Artifacts

**`manifests-comparison`** (uploaded on snapshot test failure)
- Contains: Both Dart and Node.js manifests
- Retention: 30 days
- Use: Debug compatibility issues

## Debugging Failed Workflows

### Quick Checks Failed

```bash
# Check what failed
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test --exclude-tags=snapshot,integration
```

### Builder Tests Failed

1. Download the `dart-manifest` artifact from the workflow run
2. Compare with expected structure:
   ```yaml
   specVersion: "v1alpha1"
   requiredAPIs: [...]
   endpoints:
     functionName:
       platform: "gcfv2"
       # ...
   ```
3. Check builder logs for AST parsing errors

### Snapshot Tests Failed

1. Download the `manifests-comparison` artifact
2. Use a diff tool to compare:
   ```bash
   diff -u dart-manifest.yaml nodejs-manifest.json
   ```
3. Common issues:
   - Topic name sanitization (hyphens → underscores)
   - Event trigger format (eventFilters vs resource)
   - Missing fields (retry, platform, etc.)

## Performance Optimization

### Caching Strategy

- **Dart packages**: Automatic via `dart-lang/setup-dart@v1`
- **Node.js packages**: Via `setup-node@v4` with `cache: 'npm'`
- **Build outputs**: No caching (always rebuild for accuracy)

### Concurrency Control

PR workflows use concurrency groups to cancel outdated runs:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
  cancel-in-progress: true
```

This saves CI minutes when pushing multiple commits.

### Matrix Strategy

```yaml
strategy:
  fail-fast: false
  matrix:
    sdk: [stable, beta]
```

Tests on multiple Dart versions but doesn't fail fast, so you see all results.

## Security

### Secrets Management

No secrets required for current workflows. Future enhancements may need:
- Firebase service account for deployment
- pub.dev credentials for publishing

### Permissions

Workflows use minimal permissions:
- `contents: read` (default)
- `pull-requests: write` (for comments, if added)

## Future Enhancements

- [ ] Code coverage reporting (codecov.io)
- [ ] Performance benchmarks (cold start, memory)
- [ ] Deployment tests to Firebase Emulator
- [ ] Nightly builds against latest Node.js SDK
- [ ] Auto-update snapshots on Node.js SDK releases
- [ ] Publish to pub.dev on release tags
- [ ] Slack/Discord notifications for failures

## Maintenance

### Updating Node.js Reference

When the Node.js SDK updates:

```bash
cd example/nodejs_reference
npm update firebase-functions
npm ci

# Regenerate manifest
GCLOUD_PROJECT="test-project" PORT="8080" FUNCTIONS_CONTROL_API="true" \
  npx firebase-functions &
sleep 3
curl -s http://localhost:8080/__/functions.yaml | python3 -m json.tool > nodejs_manifest.json
pkill -f firebase-functions

# Commit updated manifest
git add nodejs_manifest.json package.json package-lock.json
git commit -m "chore: update Node.js SDK reference"
```

### Updating Workflows

When modifying workflows:

1. Test locally with `validate-local.sh`
2. Push to a feature branch
3. Create a draft PR to trigger checks
4. Verify all jobs pass
5. Mark PR as ready for review

## Monitoring

Check workflow status at:
- https://github.com/invertase/firebase-functions-dart/actions

Set up notifications:
1. Go to repository Settings → Notifications
2. Enable "Failed workflows" notifications
3. Add team Slack webhook (optional)

## Support

For CI/CD issues:
1. Check [Workflow README](.github/workflows/README.md)
2. Review recent workflow runs for patterns
3. Open an issue with workflow run link
4. Tag maintainers if urgent

## Related Documentation

- [Snapshot Testing Guide](../test/snapshots/README.md)
- [Manifest Comparison](../example/MANIFEST_COMPARISON.md)
- [Builder System](../BUILDER_SYSTEM.md)
- [Project Architecture](../CLAUDE.md)
