/// Identity Platform namespace for Cloud Functions.
///
/// Provides auth blocking functions that run before user creation,
/// sign-in, email sending, and SMS sending.
library identity;

export 'auth_blocking_event.dart';
export 'auth_user_record.dart';
export 'identity_namespace.dart';
export 'options.dart';
export 'responses.dart';
