import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('package resolve emits raw Lythe instruction JSON', () async {
    final temp = await Directory.systemTemp.createTemp('ae_package_resolve_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    await File(
      p.join(temp.path, 'pubspec.yaml'),
    ).writeAsString('version: 1.2.3\n');
    await File(
      p.join(temp.path, 'run-gateway.sh'),
    ).writeAsString('#!/bin/sh\n');
    await File(p.join(temp.path, 'gateway.env')).writeAsString('PORT=8080\n');

    final previous = Directory.current;
    Directory.current = temp;
    addTearDown(() {
      Directory.current = previous;
    });

    final result = await runCli([
      'package',
      'resolve',
      '--package',
      'dev.xs.registry',
      '--target',
      'linux',
      '--format',
      'json',
    ]);

    expect(result.exitCode, 0);
    final payload = jsonDecode(result.stdout.trim()) as Map<String, dynamic>;
    expect(payload['contract_version'], 'ae.v3.package.v1');
    expect(
      (payload['package'] as Map<String, dynamic>)['id'],
      'dev.xs.registry',
    );
    expect((payload['package'] as Map<String, dynamic>)['version'], '1.2.3');
  });

  test('package validate succeeds for Lythe-compatible instructions', () async {
    final temp = await Directory.systemTemp.createTemp('ae_package_validate_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    final instructions = _validInstructions();
    final file = File(p.join(temp.path, 'instructions.json'));
    await file.writeAsString(jsonEncode(instructions));

    final result = await runCli([
      'package',
      'validate',
      '--instructions',
      file.path,
    ]);

    expect(result.exitCode, 0);
    expect(result.stdout.trim(), 'ok');
  });

  test('package validate fails on wrong contract version', () async {
    final instructions = _validInstructions();
    instructions['contract_version'] = 'nope';

    final result = await runCli([
      'package',
      'validate',
      '--instructions',
      jsonEncode(instructions),
    ]);

    expect(result.exitCode, 1);
    expect(
      result.stderr,
      contains('contract_version must equal ae.v3.package.v1'),
    );
  });

  test('package validate requires integer profile.major >= 1', () async {
    final instructions = _validInstructions();
    (instructions['profile'] as Map<String, dynamic>)['major'] = 1.5;

    final result = await runCli([
      'package',
      'validate',
      '--instructions',
      jsonEncode(instructions),
    ]);

    expect(result.exitCode, 1);
    expect(
        result.stderr, contains('profile.id and profile.major are required'));
  });

  test('package validate enforces deploy plugin version shape', () async {
    final instructions = _validInstructions();
    ((instructions['deploy'] as Map<String, dynamic>)['plugins'] as List)
        .first['version'] = 0;

    final result = await runCli([
      'package',
      'validate',
      '--instructions',
      jsonEncode(instructions),
    ]);

    expect(result.exitCode, 1);
    expect(
      result.stderr,
      contains('deploy.plugins[0].version must be an integer >= 1'),
    );
  });

  test('package validate rejects malformed build steps', () async {
    final instructions = _validInstructions();
    ((instructions['build'] as Map<String, dynamic>)['steps'] as List)
        .first['config'] = 'not-an-object';

    final result = await runCli([
      'package',
      'validate',
      '--instructions',
      jsonEncode(instructions),
    ]);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('build.steps[0].config must be an object'));
  });

  test('package validate blocks runtime forbidden actions case-insensitively',
      () async {
    final instructions = _validInstructions();
    ((instructions['safety'] as Map<String, dynamic>)['constraints']
        as Map<String, dynamic>)['forbidden_actions'] = <String>['SHELL'];

    final result = await runCli([
      'package',
      'validate',
      '--instructions',
      jsonEncode(instructions),
    ]);

    expect(result.exitCode, 1);
    expect(
      result.stderr,
      contains(
        'safety.constraints.forbidden_actions contains a forbidden runtime action',
      ),
    );
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
