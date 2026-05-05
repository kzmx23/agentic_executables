import 'dart:convert';
import 'dart:io';

import 'package:agentic_executables_mcp/src/adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AeMcpAdapter.package', () {
    late AeMcpAdapter adapter;

    setUp(() {
      adapter = AeMcpAdapter(resourcesPath: '/tmp/nonexistent');
    });

    test('resolve returns ae.v3.package.v1 instructions', () async {
      final temp = await Directory.systemTemp.createTemp('mcp_pkg_resolve_');
      addTearDown(() => temp.delete(recursive: true));
      await File(
        p.join(temp.path, 'pubspec.yaml'),
      ).writeAsString('version: 9.9.9\n');

      final result = await adapter.package({
        'operation': 'resolve',
        'package': 'dev.xs.registry',
        'package_root': temp.path,
      });

      expect(result['success'], isTrue);
      final data = result['data'] as Map<String, dynamic>;
      final instructions = data['instructions'] as Map<String, dynamic>;
      expect(instructions['contract_version'], 'ae.v3.package.v1');
      expect(
        (instructions['package'] as Map<String, dynamic>)['version'],
        '9.9.9',
      );
    });

    test('validate accepts a typed object payload', () async {
      final result = await adapter.package({
        'operation': 'validate',
        'instructions': _validInstructions(),
      });

      expect(result['success'], isTrue);
      final data = result['data'] as Map<String, dynamic>;
      expect(data['validated'], isTrue);
      expect(data['contract_version'], 'ae.v3.package.v1');
    });

    test('validate accepts an inline JSON string payload', () async {
      final result = await adapter.package({
        'operation': 'validate',
        'instructions': jsonEncode(_validInstructions()),
      });

      expect(result['success'], isTrue);
    });

    test('validate rejects malformed JSON in instructions string', () async {
      final result = await adapter.package({
        'operation': 'validate',
        'instructions': '{not valid',
      });
      expect(result['success'], isFalse);
      expect(
        (result['error'] as Map<String, dynamic>)['code'],
        'validation_error',
      );
    });

    test('returns validation_error when operation is missing', () async {
      final result = await adapter.package(<String, dynamic>{});
      expect(result['success'], isFalse);
      expect(
        (result['error'] as Map<String, dynamic>)['code'],
        'validation_error',
      );
    });

    test('returns validation_error for unknown operation', () async {
      final result = await adapter.package({'operation': 'bogus'});
      expect(result['success'], isFalse);
      expect(
        (result['error'] as Map<String, dynamic>)['code'],
        'validation_error',
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
