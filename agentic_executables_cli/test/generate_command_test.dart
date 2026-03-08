import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('generate writes expected files and reports deterministic statuses',
      () async {
    final temp = await Directory.systemTemp.createTemp('ae_cli_generate_');
    addTearDown(() => temp.delete(recursive: true));

    final outputDir = p.join(temp.path, 'ae_use');
    final first = await runCli(
      [
        'generate',
        '--library-id',
        'dart_provider',
        '--library-root',
        temp.path,
        '--output-dir',
        outputDir,
        '--engine',
        'template',
      ],
      codexBinary: '/missing/codex',
    );

    expect(first.exitCode, 0);
    final write = first.json['data']['write'] as Map<String, dynamic>;
    final files = (write['files'] as List).cast<Map<String, dynamic>>();
    expect(
      files.map((final entry) => entry['status']).toSet(),
      equals({'added'}),
    );

    final second = await runCli(
      [
        'generate',
        '--library-id',
        'dart_provider',
        '--library-root',
        temp.path,
        '--output-dir',
        outputDir,
        '--engine',
        'template',
      ],
      codexBinary: '/missing/codex',
    );

    expect(second.exitCode, 0);
    expect(second.json['data']['no_op'], isTrue);
    final secondWrite = second.json['data']['write'] as Map<String, dynamic>;
    final secondFiles =
        (secondWrite['files'] as List).cast<Map<String, dynamic>>();
    expect(
      secondFiles.map((final entry) => entry['status']).toSet(),
      equals({'unchanged'}),
    );
  });

  test('generate --check fails when drift exists and includes diff metadata',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('ae_cli_generate_check_');
    addTearDown(() => temp.delete(recursive: true));

    final outputDir = p.join(temp.path, 'ae_use');
    await runCli(
      [
        'generate',
        '--library-id',
        'dart_provider',
        '--library-root',
        temp.path,
        '--output-dir',
        outputDir,
        '--engine',
        'template',
      ],
    );

    await File(p.join(outputDir, 'ae_install.md')).writeAsString('drift');

    final check = await runCli(
      [
        'generate',
        '--library-id',
        'dart_provider',
        '--library-root',
        temp.path,
        '--output-dir',
        outputDir,
        '--engine',
        'template',
        '--check',
        '--diff',
      ],
    );

    expect(check.exitCode, 1);
    expect(check.json['error']['code'], 'check_mode_changes_detected');

    final details = check.json['error']['details'] as Map<String, dynamic>;
    final files = (details['files'] as List).cast<Map<String, dynamic>>();
    final install = files.firstWhere(
      (final file) => (file['path'] as String).endsWith('ae_install.md'),
    );
    expect(install['status'], 'updated');
    expect((install['diff'] as String), contains('---'));
  });

  test('generate --no-overwrite blocks conflicting writes', () async {
    final temp =
        await Directory.systemTemp.createTemp('ae_cli_generate_blocked_');
    addTearDown(() => temp.delete(recursive: true));

    final outputDir = p.join(temp.path, 'ae_use');
    await runCli(
      [
        'generate',
        '--library-id',
        'dart_provider',
        '--library-root',
        temp.path,
        '--output-dir',
        outputDir,
        '--engine',
        'template',
      ],
    );

    await File(p.join(outputDir, 'ae_install.md')).writeAsString('drift');

    final blocked = await runCli(
      [
        'generate',
        '--library-id',
        'dart_provider',
        '--library-root',
        temp.path,
        '--output-dir',
        outputDir,
        '--engine',
        'template',
        '--no-overwrite',
      ],
    );

    expect(blocked.exitCode, 1);
    expect(blocked.json['error']['code'], 'write_conflict_no_overwrite');
    final details = blocked.json['error']['details'] as Map<String, dynamic>;
    expect(details['has_blocked'], isTrue);
  });

  test('generate --backup creates timestamped backups before overwrite',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('ae_cli_generate_backup_');
    addTearDown(() => temp.delete(recursive: true));

    final outputDir = p.join(temp.path, 'ae_use');
    await runCli(
      [
        'generate',
        '--library-id',
        'dart_provider',
        '--library-root',
        temp.path,
        '--output-dir',
        outputDir,
        '--engine',
        'template',
      ],
    );

    await File(p.join(outputDir, 'ae_install.md')).writeAsString('drift');

    final backup = await runCli(
      [
        'generate',
        '--library-id',
        'dart_provider',
        '--library-root',
        temp.path,
        '--output-dir',
        outputDir,
        '--engine',
        'template',
        '--backup',
      ],
    );

    expect(backup.exitCode, 0);
    final write = backup.json['data']['write'] as Map<String, dynamic>;
    final files = (write['files'] as List).cast<Map<String, dynamic>>();
    final updated = files.firstWhere(
      (final file) => (file['path'] as String).endsWith('ae_install.md'),
    );
    final backupPath = updated['backup_path'] as String;
    expect(File(backupPath).existsSync(), isTrue);
  });
}
