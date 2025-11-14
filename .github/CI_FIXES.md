# CI/CD Fixes Applied

This document tracks fixes applied to make the CI/CD pipeline work correctly.

## Fix 1: Removed Non-Existent YAML Validation Package

**Date**: 2024-11-14
**Issue**: Builder tests were failing because `yaml_tools` package doesn't exist on pub.dev
**Error**: `Could not find package yaml_tools at https://pub.dev`

**Fix**: Removed unnecessary YAML validation step from `test.yml`:
```yaml
# REMOVED:
- name: Validate YAML syntax
  run: |
    dart pub global activate yaml_tools
    dart pub global run yaml_tools:validate example/basic/.dart_tool/firebase/functions.yaml || true
```

**Justification**:
- Builder generates valid YAML (we control the generation)
- File existence is verified in previous step
- Snapshot tests validate actual content structure
- YAML syntax errors would cause parse failures in tests

## Fix 2: NPM Cache Missing package-lock.json

**Date**: 2024-11-14
**Issue**: Snapshot tests failing with NPM cache error
**Error**: `Some specified paths were not resolved, unable to cache dependencies.`

**Root Cause**:
- `.gitignore` had pattern `example/*/package-lock.json` ignoring all example lock files
- GitHub Actions `setup-node@v4` with `cache: 'npm'` requires `package-lock.json` to exist
- Lock file was generated locally but not committed to git

**Fix**: Updated `.gitignore` to keep nodejs_reference package-lock.json:
```gitignore
# BEFORE:
# Package manager locks (keep package.json, ignore locks for examples)
example/*/package-lock.json

# AFTER:
# Package manager locks
# Keep nodejs_reference/package-lock.json for CI NPM caching
# Ignore other example package-lock.json files
example/basic/package-lock.json
```

**Justification**:
- `nodejs_reference/package-lock.json` is required for CI NPM caching
- Lock file ensures consistent Node.js dependency versions across CI runs
- Prevents cache misses and speeds up CI
- Other example lock files (like `basic/`) are not needed

**Files Modified**:
1. `.github/workflows/test.yml` - Removed yaml_tools validation
2. `.gitignore` - Changed package-lock.json ignore pattern

**Testing**:
```bash
# Verify package-lock.json is tracked
git check-ignore -v example/nodejs_reference/package-lock.json
# Should output: "File is NOT ignored (will be tracked)"

# Verify it exists
ls -la example/nodejs_reference/package-lock.json
```

## Verification Checklist

- [x] Builder tests pass locally
- [x] package-lock.json exists
- [x] package-lock.json is NOT ignored by git
- [ ] Builder tests pass in CI
- [ ] Snapshot tests pass in CI
- [ ] NPM cache works correctly

## Related Documentation

- [CI/CD Setup](.github/CI_SETUP.md)
- [Workflow README](.github/workflows/README.md)
- [.gitignore Guide](../.gitignore.md)
