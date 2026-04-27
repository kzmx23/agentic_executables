import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('DefaultAePackageService.resolve', () {
    test('produces a valid ae.v3.package.v1 envelope from package metadata',
        () async {
      final temp = await Directory.systemTemp.createTemp('pkg_resolve_');
      addTearDown(() => temp.delete(recursive: true));

      await File(
        p.join(temp.path, 'pubspec.yaml'),
      ).writeAsString('version: 2.3.4\n');

      final result = await const DefaultAePackageService().resolve(
        PackageResolveInput(
          packageId: 'dev.xs.registry',
          packageRoot: temp.path,
        ),
      );

      expect(result.success, isTrue);
      final data = result.data!;
      expect(data['package'], 'dev.xs.registry');
      final instructions = data['instructions'] as Map<String, dynamic>;
      expect(instructions['contract_version'], 'ae.v3.package.v1');
      expect(
        (instructions['package'] as Map<String, dynamic>)['version'],
        '2.3.4',
      );
    });

    test('falls back to 1.0.0 when no manifest is found', () async {
      final temp = await Directory.systemTemp.createTemp('pkg_resolve_no_v_');
      addTearDown(() => temp.delete(recursive: true));

      final result = await const DefaultAePackageService().resolve(
        PackageResolveInput(
          packageId: 'foo',
          packageRoot: temp.path,
        ),
      );

      expect(result.success, isTrue);
      final instructions =
          (result.data!['instructions'] as Map<String, dynamic>);
      expect(
        (instructions['package'] as Map<String, dynamic>)['version'],
        '1.0.0',
      );
    });

    test('rejects an unsupported target', () async {
      final result = await const DefaultAePackageService().resolve(
        const PackageResolveInput(packageId: 'foo', target: 'darwin'),
      );
      expect(result.success, isFalse);
      expect(result.error?.code, 'validation_error');
      expect(result.error?.message, contains('Unsupported target "darwin"'));
    });

    test('rejects an empty package id', () async {
      final result = await const DefaultAePackageService().resolve(
        const PackageResolveInput(packageId: ''),
      );
      expect(result.success, isFalse);
      expect(result.error?.code, 'validation_error');
    });
  });

  group('DefaultAePackageService.validate', () {
    test('accepts a well-formed Lythe payload', () async {
      final result = await const DefaultAePackageService().validate(
        PackageValidateInput(instructions: _validInstructions()),
      );
      expect(result.success, isTrue);
      expect(result.data!['validated'], isTrue);
      expect(result.data!['contract_version'], 'ae.v3.package.v1');
    });

    test('rejects a wrong contract version', () async {
      final payload = _validInstructions();
      payload['contract_version'] = 'wrong';
      final result = await const DefaultAePackageService().validate(
        PackageValidateInput(instructions: payload),
      );
      expect(result.success, isFalse);
      expect(result.error?.message, contains('contract_version'));
    });

    test('rejects forbidden runtime actions case-insensitively', () async {
      final payload = _validInstructions();
      ((payload['safety'] as Map<String, dynamic>)['constraints']
          as Map<String, dynamic>)['forbidden_actions'] = <String>['SHELL'];
      final result = await const DefaultAePackageService().validate(
        PackageValidateInput(instructions: payload),
      );
      expect(result.success, isFalse);
      expect(
        result.error?.message,
        contains('forbidden_actions contains a forbidden runtime action'),
      );
    });
  });
}

Map<String, dynamic> _validInstructions() => <String, dynamic>{
      'contract_version': 'ae.v3.package.v1',
      'package': <String, dynamic>{'id': 'dev.xs.registry', 'version': '1.0.0'},
      'profile': <String, dynamic>{'id': 'direct', 'major': 1},
      'build': <String, dynamic>{
        'steps': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'copy',
            'config': <String, dynamic>{'src': '.'},
          },
        ],
      },
      'deploy': <String, dynamic>{
        'plugins': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'systemd_service',
            'version': 1,
            'config': <String, dynamic>{
              'unit_name': 'lythe-dev-xs-registry.service',
            },
          },
        ],
        'inputs': <String, dynamic>{'required': const <String>[]},
      },
      'domain': <String, dynamic>{
        'capabilities': <String, dynamic>{'wildcard_support_mode': 'none'},
      },
      'safety': <String, dynamic>{
        'constraints': <String, dynamic>{
          'allowed_executors': const <String>['lythe'],
          'forbidden_actions': const <String>[],
        },
      },
    };
