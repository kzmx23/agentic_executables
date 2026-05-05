import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test(
      'skill install is idempotent and requires --upgrade for divergent content',
      () async {
    final temp = await Directory.systemTemp.createTemp('ae_skill_test_');
    addTearDown(() => temp.delete(recursive: true));

    final env = {...Platform.environment, 'CODEX_HOME': temp.path};

    final firstInstall = await runCli(
      ['skill', 'install'],
      environment: env,
    );

    expect(firstInstall.exitCode, 0);
    expect(firstInstall.json['data']['installed'], isTrue);
    expect(firstInstall.json['data']['no_op'], isFalse);

    final secondInstall = await runCli(
      ['skill', 'install'],
      environment: env,
    );

    expect(secondInstall.exitCode, 0);
    expect(secondInstall.json['data']['no_op'], isTrue);

    final skillFile = File(p.join(temp.path, 'skills', 'ae-cli', 'SKILL.md'));
    expect(skillFile.existsSync(), isTrue);
    await skillFile.writeAsString('outdated skill');

    final upgradeRequired = await runCli(
      ['skill', 'install'],
      environment: env,
    );

    expect(upgradeRequired.exitCode, 1);
    expect(upgradeRequired.json['error']['code'], 'skill_upgrade_required');

    final upgraded = await runCli(
      ['skill', 'install', '--upgrade'],
      environment: env,
    );

    expect(upgraded.exitCode, 0);
    expect(upgraded.json['data']['upgraded'], isTrue);
    final backupPath = upgraded.json['data']['backup_path'] as String;
    expect(Directory(backupPath).existsSync(), isTrue);
  });

  test('skill install --force is removed', () async {
    final temp = await Directory.systemTemp.createTemp('ae_skill_force_test_');
    addTearDown(() => temp.delete(recursive: true));

    final env = {...Platform.environment, 'CODEX_HOME': temp.path};

    final result = await runCli(
      ['skill', 'install', '--force'],
      environment: env,
    );

    expect(result.exitCode, 64);
    expect(result.json['error']['code'], 'invalid_arguments');
  });
}
