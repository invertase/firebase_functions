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

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:firebase_functions/src/builder/spec.dart';
import 'package:test/test.dart';

void main() {
  group('EndpointSpec.extractOptions', () {
    test('extracts region from DeployOption dot shorthand', () {
      final options = _parseHttpsOptions('''
void main() {
  const options = const HttpsOptions(
    region: DeployOption(.asiaEast1),
  );
}
''');

      final endpoint = EndpointSpec(
        name: 'helloWorld',
        type: 'https',
        options: options,
      );

      expect(endpoint.extractOptions(), containsPair('region', ['asia-east1']));
    });
  });
}

InstanceCreationExpression _parseHttpsOptions(String content) {
  final result = parseString(content: content);
  final visitor = _InstanceCreationVisitor('HttpsOptions');

  result.unit.accept(visitor);

  final node = visitor.node;
  expect(node, isNotNull);
  return node!;
}

final class _InstanceCreationVisitor extends RecursiveAstVisitor<void> {
  _InstanceCreationVisitor(this.typeName);

  final String typeName;
  InstanceCreationExpression? node;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.toSource() == typeName) {
      this.node = node;
      return;
    }

    super.visitInstanceCreationExpression(node);
  }
}
