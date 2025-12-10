import 'dart:io';

import 'package:firebase_functions/src/common/params.dart';
import 'package:firebase_functions/src/common/on_init.dart';
import 'package:test/test.dart';

void main() {
  group('Parameter Factory Functions', () {
    setUp(() {
      clearParams();
    });

    test('defineString registers a StringParam', () {
      final param = defineString('TEST_STRING');
      expect(param, isA<StringParam>());
      expect(param.name, 'TEST_STRING');
      expect(declaredParams, contains(param));
    });

    test('defineInt registers an IntParam', () {
      final param = defineInt('TEST_INT');
      expect(param, isA<IntParam>());
      expect(param.name, 'TEST_INT');
      expect(declaredParams, contains(param));
    });

    test('defineDouble registers a DoubleParam', () {
      final param = defineDouble('TEST_DOUBLE');
      expect(param, isA<DoubleParam>());
      expect(param.name, 'TEST_DOUBLE');
      expect(declaredParams, contains(param));
    });

    test('defineBoolean registers a BooleanParam', () {
      final param = defineBoolean('TEST_BOOL');
      expect(param, isA<BooleanParam>());
      expect(param.name, 'TEST_BOOL');
      expect(declaredParams, contains(param));
    });

    test('defineList registers a ListParam', () {
      final param = defineList('TEST_LIST');
      expect(param, isA<ListParam>());
      expect(param.name, 'TEST_LIST');
      expect(declaredParams, contains(param));
    });

    test('defineSecret registers a SecretParam', () {
      final param = defineSecret('TEST_SECRET');
      expect(param, isA<SecretParam>());
      expect(param.name, 'TEST_SECRET');
      expect(declaredParams, contains(param));
    });

    test('defineJsonSecret registers a JsonSecretParam', () {
      final param = defineJsonSecret<Map<String, dynamic>>('TEST_JSON_SECRET');
      expect(param, isA<JsonSecretParam>());
      expect(param.name, 'TEST_JSON_SECRET');
      expect(declaredParams, contains(param));
    });

    test('redefining a parameter replaces the old one', () {
      final param1 = defineString('SAME_NAME');
      expect(declaredParams.length, 1);

      final param2 = defineInt('SAME_NAME');
      expect(declaredParams.length, 1);
      expect(declaredParams.first, param2);
      expect(declaredParams.first, isNot(param1));
    });

    test('clearParams removes all registered params', () {
      defineString('A');
      defineInt('B');
      defineBoolean('C');
      expect(declaredParams.length, 3);

      clearParams();
      expect(declaredParams, isEmpty);
    });
  });

  group('ParamOptions', () {
    test('can be created with all options', () {
      final options = ParamOptions<String>(
        defaultValue: 'default',
        label: 'Test Label',
        description: 'Test Description',
        input: ParamInput.select(['a', 'b', 'c']),
      );

      expect(options.defaultValue, 'default');
      expect(options.label, 'Test Label');
      expect(options.description, 'Test Description');
      expect(options.input, isA<SelectParamInput>());
    });

    test('all fields are optional', () {
      const options = ParamOptions<String>();
      expect(options.defaultValue, isNull);
      expect(options.label, isNull);
      expect(options.description, isNull);
      expect(options.input, isNull);
    });
  });

  group('Param.toSpec()', () {
    setUp(() => clearParams());

    test('StringParam generates correct spec', () {
      final param = defineString(
        'MY_STRING',
        ParamOptions(
          defaultValue: 'hello',
          label: 'My String',
          description: 'A test string',
        ),
      );

      final spec = param.toSpec();
      expect(spec.name, 'MY_STRING');
      expect(spec.type, 'string');
      expect(spec.defaultValue, 'hello');
      expect(spec.label, 'My String');
      expect(spec.description, 'A test string');
    });

    test('IntParam generates correct spec', () {
      final param = defineInt(
        'MY_INT',
        ParamOptions(defaultValue: 42),
      );

      final spec = param.toSpec();
      expect(spec.name, 'MY_INT');
      expect(spec.type, 'int');
      expect(spec.defaultValue, 42);
    });

    test('BooleanParam generates correct spec', () {
      final param = defineBoolean(
        'MY_BOOL',
        ParamOptions(defaultValue: true),
      );

      final spec = param.toSpec();
      expect(spec.name, 'MY_BOOL');
      expect(spec.type, 'boolean');
      expect(spec.defaultValue, true);
    });

    test('SecretParam generates correct spec', () {
      final param = defineSecret('MY_SECRET');

      final spec = param.toSpec();
      expect(spec.name, 'MY_SECRET');
      expect(spec.type, 'secret');
    });
  });

  group('JsonSecretParam.toSpec()', () {
    setUp(() => clearParams());

    test('generates spec with json format', () {
      final param = defineJsonSecret<Map<String, dynamic>>('API_CONFIG');

      final spec = param.toSpec();
      expect(spec['name'], 'API_CONFIG');
      expect(spec['type'], 'secret');
      expect(spec['format'], 'json');
    });
  });

  group('BooleanParam.thenElse()', () {
    setUp(() => clearParams());

    test('creates conditional expression', () {
      final isProduction = defineBoolean('IS_PRODUCTION');
      final conditional = isProduction.thenElse(2048, 512);

      expect(conditional, isNotNull);
      // The conditional is an If expression
      expect(conditional.toString(), contains('params.IS_PRODUCTION'));
    });
  });

  group('ParamInput', () {
    test('select creates SelectParamInput', () {
      final input = ParamInput.select([1, 2, 3]);
      expect(input, isA<SelectParamInput<int>>());
      expect((input as SelectParamInput<int>).options.length, 3);
    });

    test('selectWithLabels creates SelectParamInput with labels', () {
      final input = ParamInput.selectWithLabels({
        'Small': 256,
        'Medium': 512,
        'Large': 1024,
      });
      expect(input, isA<SelectParamInput<int>>());
      expect((input as SelectParamInput<int>).options.length, 3);
      expect(input.options[0].label, 'Small');
      expect(input.options[0].value, 256);
    });

    test('multiSelect creates MultiSelectParamInput', () {
      final input = ParamInput.multiSelect(['a', 'b', 'c']);
      expect(input, isA<MultiSelectParamInput>());
      expect(input.options.length, 3);
    });

    test('bucketPicker is a ResourceInput', () {
      expect(ParamInput.bucketPicker, isA<ResourceInput>());
    });
  });

  group('Built-in Parameters', () {
    test('projectId is an InternalExpression', () {
      expect(ParamInput.projectId, isA<InternalExpression>());
      expect(ParamInput.projectId.name, 'PROJECT_ID');
    });

    test('databaseURL is an InternalExpression', () {
      expect(ParamInput.databaseURL, isA<InternalExpression>());
      expect(ParamInput.databaseURL.name, 'DATABASE_URL');
    });

    test('storageBucket is an InternalExpression', () {
      expect(ParamInput.storageBucket, isA<InternalExpression>());
      expect(ParamInput.storageBucket.name, 'STORAGE_BUCKET');
    });

    test('gcloudProject is an InternalExpression', () {
      expect(ParamInput.gcloudProject, isA<InternalExpression>());
      expect(ParamInput.gcloudProject.name, 'GCLOUD_PROJECT');
    });
  });

  group('Param.toString()', () {
    setUp(() => clearParams());

    test('returns params.NAME format', () {
      final param = defineString('MY_PARAM');
      expect(param.toString(), 'params.MY_PARAM');
    });
  });
}
