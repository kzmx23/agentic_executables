import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('generate --engine template writes expected files', () async {
    final temp = await Directory.systemTemp.createTemp('ae_cli_generate_');
    addTearDown(() => temp.delete(recursive: true));

    final outputDir = p.join(temp.path, 'ae_use');
    final result = await runCli(
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
      repoRoot: _repoRoot(),
      codexBinary: '/missing/codex',
    );

    expect(result.exitCode, 0);

    for (final file in const [
      'ae_install.md',
      'ae_uninstall.md',
      'ae_update.md',
      'ae_use.md',
    ]) {
      expect(File(p.join(outputDir, file)).existsSync(), isTrue);
    }
  });

  test('generate --engine auto falls back when codex missing', () async {
    final temp = await Directory.systemTemp.createTemp('ae_cli_generate_auto_');
    addTearDown(() => temp.delete(recursive: true));

    final result = await runCli(
      [
        'generate',
        '--library-id',
        'dart_provider',
        '--library-root',
        temp.path,
        '--engine',
        'auto',
        '--dry-run',
      ],
      repoRoot: _repoRoot(),
      codexBinary: '/missing/codex',
    );

    expect(result.exitCode, 0);
    final warnings = (result.json['warnings'] as List).join(' ');
    expect(warnings, contains('Codex binary not detected'));
  });
}

String _repoRoot() => '..';
