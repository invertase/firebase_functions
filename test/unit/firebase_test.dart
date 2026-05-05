// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:firebase_functions/src/common/environment.dart';
import 'package:firebase_functions/src/firebase.dart';
import 'package:test/test.dart';

void main() {
  setUp(() async {
    FirebaseEnv.mockEnvironment = {'FIREBASE_PROJECT': 'demo-test'};
    await _deleteInitializedApps();
  });

  tearDown(() async {
    await _deleteInitializedApps();
    FirebaseEnv.mockEnvironment = null;
  });

  group('createFirebaseInternal', () {
    test('initializes a default Admin SDK app when none exists', () {
      final firebase = createFirebaseInternal();

      expect(FirebaseApp.apps, hasLength(1));
      expect(identical(firebase.adminApp, FirebaseApp.getApp()), isTrue);
      expect(firebase.adminApp.options.projectId, 'demo-test');
    });

    test('reuses an existing user-initialized default Admin SDK app', () {
      final userApp = FirebaseApp.initializeApp(
        options: AppOptions(
          credential: Credential.fromApplicationDefaultCredentials(),
          projectId: 'custom-project',
        ),
      );

      final firebase = createFirebaseInternal();

      expect(FirebaseApp.apps, hasLength(1));
      expect(identical(firebase.adminApp, userApp), isTrue);
      expect(firebase.adminApp.options.projectId, 'custom-project');
    });
  });
}

Future<void> _deleteInitializedApps() async {
  for (final app in FirebaseApp.apps) {
    await FirebaseApp.deleteApp(app);
  }
}
