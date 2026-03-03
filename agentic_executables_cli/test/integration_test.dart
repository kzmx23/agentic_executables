import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test(
      'CLI integration: definition -> instructions -> generate -> verify/evaluate -> registry/skill',
      () async {
    final temp = await Directory.systemTemp.createTemp('ae_cli_integration_');
    addTearDown(() => temp.delete(recursive: true));

    final repoRoot = _findRepoRoot();
    final outputDir = p.join(temp.path, 'ae_use');

    final definition = await runCli(
      ['definition'],
      repoRoot: repoRoot,
      codexBinary: '/missing/codex',
    );
    expect(definition.exitCode, 0);
    expect(definition.json['success'], isTrue);

    final instructions = await runCli(
      [
        'instructions',
        '--context',
        'library',
        '--action',
        'bootstrap',
        '--resources-path',
        p.join(repoRoot, 'prompts_framework'),
      ],
      repoRoot: repoRoot,
      codexBinary: '/missing/codex',
    );
    expect(instructions.exitCode, 0);
    expect(instructions.json['success'], isTrue);
    final docs = (instructions.json['data'] as Map)['documents'] as Map;
    expect(docs.keys, containsAll(['ae_context.md', 'ae_bootstrap.md']));

    final generate = await runCli(
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
      repoRoot: repoRoot,
      codexBinary: '/missing/codex',
    );
    expect(generate.exitCode, 0);
    expect(generate.json['success'], isTrue);

    for (final file in const [
      'ae_install.md',
      'ae_uninstall.md',
      'ae_update.md',
      'ae_use.md',
    ]) {
      expect(File(p.join(outputDir, file)).existsSync(), isTrue);
    }

    final installLoc =
        File(p.join(outputDir, 'ae_install.md')).readAsLinesSync().length;

    final verifyFile = File(p.join(temp.path, 'verify.json'));
    await verifyFile.writeAsString(
      jsonEncode(
        {
          'context_type': 'project',
          'action': 'install',
          'files_modified': [
            {
              'path': 'ae_install.md',
              'loc': installLoc,
              'sections': ['Setup', 'Config', 'Integration', 'Validation'],
            },
          ],
          'checklist_completed': {
            'modularity': true,
            'contextual_awareness': true,
            'agent_empowerment': true,
            'validation': true,
            'integration': true,
          },
        },
      ),
    );

    final verify = await runCli(
      ['verify', '--input', verifyFile.path],
      repoRoot: repoRoot,
      codexBinary: '/missing/codex',
    );
    expect(verify.exitCode, 0);
    expect(verify.json['success'], isTrue);
    expect((verify.json['data'] as Map)['overall_status'], 'PASS');

    final evaluateFile = File(p.join(temp.path, 'evaluate.json'));
    await evaluateFile.writeAsString(
      jsonEncode(
        {
          'context_type': 'project',
          'action': 'install',
          'files_created': [
            {'path': 'ae_install.md', 'loc': installLoc},
          ],
          'sections_present': ['Setup', 'Config', 'Integration', 'Validation'],
          'validation_steps_exists': true,
          'integration_points_defined': true,
        },
      ),
    );

    final evaluate = await runCli(
      ['evaluate', '--input', evaluateFile.path],
      repoRoot: repoRoot,
      codexBinary: '/missing/codex',
    );
    expect(evaluate.exitCode, 0);
    expect(evaluate.json['success'], isTrue);
    expect((evaluate.json['data'] as Map)['overall_status'], 'PASS');

    final registryBootstrap = await runCli(
      ['registry', 'bootstrap-local', '--ae-use-path', outputDir],
      repoRoot: repoRoot,
      codexBinary: '/missing/codex',
    );
    expect(registryBootstrap.exitCode, 0);
    expect(registryBootstrap.json['success'], isTrue);

    final registrySubmit = await runCli(
      [
        'registry',
        'submit',
        '--library-url',
        'https://github.com/example/dart_provider',
        '--library-id',
        'dart_provider',
        '--ae-use-files',
        'ae_use/ae_install.md,ae_use/ae_uninstall.md,ae_use/ae_update.md,ae_use/ae_use.md',
      ],
      repoRoot: repoRoot,
      codexBinary: '/missing/codex',
    );
    expect(registrySubmit.exitCode, 0);
    expect(registrySubmit.json['success'], isTrue);

    final skillsTarget = p.join(temp.path, 'skills');
    final installSkill = await runCli(
      ['skill', 'install', '--target', skillsTarget],
      repoRoot: repoRoot,
      codexBinary: '/missing/codex',
    );
    expect(installSkill.exitCode, 0);
    expect(installSkill.json['success'], isTrue);

    final updateSkill = await runCli(
      ['skill', 'update', '--target', skillsTarget],
      repoRoot: repoRoot,
      codexBinary: '/missing/codex',
    );
    expect(updateSkill.exitCode, 0);
    expect(updateSkill.json['success'], isTrue);
  });
}

String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory(p.join(dir.path, 'prompts_framework')).existsSync() &&
        Directory(p.join(dir.path, 'skills')).existsSync()) {
      return dir.path;
    }

    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Unable to locate repository root');
    }
    dir = parent;
  }
}
