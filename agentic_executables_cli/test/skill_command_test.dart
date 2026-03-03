import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('skill install and update honor CODEX_HOME target resolution', () async {
    final temp = await Directory.systemTemp.createTemp('ae_skill_test_');
    addTearDown(() => temp.delete(recursive: true));

    final env = {...Platform.environment, 'CODEX_HOME': temp.path};

    final install = await runCli(
      ['skill', 'install'],
      repoRoot: _repoRoot(),
      environment: env,
    );

    expect(install.exitCode, 0);
    final skillFile = File(p.join(temp.path, 'skills', 'ae-cli', 'SKILL.md'));
    expect(skillFile.existsSync(), isTrue);

    await skillFile.writeAsString('outdated skill');

    final update = await runCli(
      ['skill', 'update'],
      repoRoot: _repoRoot(),
      environment: env,
    );

    expect(update.exitCode, 0);
    expect(update.json['data']['updated'], isTrue);
    final backupPath = update.json['data']['backup_path'] as String;
    expect(Directory(backupPath).existsSync(), isTrue);
  });
}

String _repoRoot() => '..';
