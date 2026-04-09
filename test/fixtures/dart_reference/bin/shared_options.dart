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

import 'package:firebase_functions/firebase_functions.dart';

/// Options declared in a separate file to test cross-file variable resolution.
/// Options declared in a separate file to test cross-file variable resolution.
/// The builder now performs a pre-pass to collect these variables, allowing
/// them to be resolved when referenced in other files like server.dart.
const crossFileOpts = HttpsOptions(
  region: Region(SupportedRegion.europeWest2),
  memory: Memory(MemoryOption.mb512),
);
