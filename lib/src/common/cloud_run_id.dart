/// Converts a function name to a valid Cloud Run service ID.
///
/// Cloud Run service IDs must:
/// - Only contain lowercase letters, digits, and hyphens
/// - Begin with a letter
/// - Not end with a hyphen
/// - Be less than 50 characters
///
/// CamelCase is properly transformed to kebab-case:
/// - `onDocumentCreated` → `on-document-created`
/// - `helloWorld` → `hello-world`
///
/// Underscores and other separators become hyphens:
/// - `onDocumentCreated_users_userId` → `on-document-created-users-user-id`
///
/// This function is used by both the build-time manifest generator and the
/// runtime function registration to ensure consistent naming.
String toCloudRunId(String name) {
  // Step 1: Convert camelCase to kebab-case
  // Insert hyphen before uppercase letters that follow a lowercase letter/digit
  var id = name.replaceAllMapped(
    RegExp(r'(?<=[a-z0-9])([A-Z])'),
    (m) => '-${m.group(1)}',
  );
  // Handle consecutive uppercase followed by lowercase (e.g., HTTPSServer → HTTPS-Server)
  id = id.replaceAllMapped(
    RegExp(r'(?<=[A-Z])([A-Z][a-z])'),
    (m) => '-${m.group(1)}',
  );

  // Step 2: Lowercase
  id = id.toLowerCase();

  // Step 3: Replace non-alphanumeric chars with hyphens
  id = id.replaceAll(RegExp(r'[^a-z0-9]'), '-');

  // Step 4: Collapse consecutive hyphens
  id = id.replaceAll(RegExp(r'-{2,}'), '-');

  // Step 5: Remove leading hyphens/digits (must start with a letter)
  id = id.replaceAll(RegExp(r'^[^a-z]+'), '');

  // Step 6: Remove trailing hyphens
  id = id.replaceAll(RegExp(r'-+$'), '');

  // Step 7: Handle 50-char limit
  if (id.length >= 50) {
    // Use a deterministic hash suffix to avoid collisions
    final hash = _simpleHash(name);
    final suffix = hash.substring(0, 6);
    // Reserve space for: truncated part + '-' + 6-char hash = max 49
    var prefix = id.substring(0, 42);
    // Don't end the prefix on a hyphen
    prefix = prefix.replaceAll(RegExp(r'-+$'), '');
    id = '$prefix-$suffix';
  }

  return id;
}

/// Simple deterministic hash that returns a lowercase alphanumeric string.
String _simpleHash(String input) {
  // DJB2 hash — deterministic across all Dart runtimes
  var hash = 5381;
  for (var i = 0; i < input.length; i++) {
    hash = ((hash << 5) + hash) + input.codeUnitAt(i);
    hash &= 0x7FFFFFFF; // Keep it positive 31-bit
  }
  // Convert to base-36 (lowercase alphanumeric)
  return hash.toRadixString(36).padLeft(6, '0');
}
