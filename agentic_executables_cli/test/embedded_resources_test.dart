import 'dart:io';

import 'package:agentic_executables_cli/src/resources/embedded_cli_resources.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test(
      'embedded prompts and skill template stay in sync with canonical sources',
      () {
    final repoRoot = _findRepoRoot();

    for (final entry in EmbeddedCliResources.prompts.entries) {
      final canonical =
          File(p.join(repoRoot.path, 'prompts_framework', entry.key));
      expect(canonical.existsSync(), isTrue);
      expect(entry.value, canonical.readAsStringSync());
    }

    final skillCanonical =
        File(p.join(repoRoot.path, 'skills', 'ae-cli', 'SKILL.md'));
    expect(skillCanonical.existsSync(), isTrue);
    expect(
        EmbeddedCliResources.skillTemplate, skillCanonical.readAsStringSync());
  });

  test('embedded resources work outside repository layout', () async {
    final temp = await Directory.systemTemp.createTemp('ae_embedded_');
    addTearDown(() => temp.delete(recursive: true));

    final instructions = await runCli(
      ['instructions', '--context', 'library', '--action', 'bootstrap'],
    );

    expect(instructions.exitCode, 0);
    final docs = instructions.json['data']['documents'] as Map<String, dynamic>;
    expect(docs.keys, containsAll(['ae_context.md', 'ae_bootstrap.md']));

    final env = {...Platform.environment, 'CODEX_HOME': temp.path};
    final skillInstall = await runCli(
      ['skill', 'install'],
      environment: env,
    );

    expect(skillInstall.exitCode, 0);
    expect(
      File(p.join(temp.path, 'skills', 'ae-cli', 'SKILL.md')).existsSync(),
      isTrue,
    );
  });
}

Directory _findRepoRoot() {
  return findRepoRootDirectory(
    matches: (final rootPath) {
      final promptsDir = Directory(p.join(rootPath, 'prompts_framework'));
      final skillsDir = Directory(p.join(rootPath, 'skills'));
      return promptsDir.existsSync() && skillsDir.existsSync();
    },
  );
}
