# Testing

Run all tests:
```bash
dart test
```

Run specific test suites:
```bash
# Unit tests only
dart test --exclude-tags=snapshot,integration

# Builder tests
dart run build_runner build --delete-conflicting-outputs
dart test test/builder/

# Snapshot tests (compare with Node.js SDK)
dart test test/snapshots/
```

See [Testing Guide](snapshots/README.md) for more details.