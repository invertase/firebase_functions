// Copyright 2026, the Firebase project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT-style license that can be found in the LICENSE file.

/// Identity Platform namespace for Cloud Functions.
///
/// Provides auth blocking functions that run before user creation,
/// sign-in, email sending, and SMS sending.
library;

export 'auth_blocking_event.dart';
export 'auth_user_record.dart';
export 'identity_namespace.dart';
export 'options.dart';
export 'responses.dart';
