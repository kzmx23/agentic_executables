import 'dart:io';

import 'package:agentic_executables_cli/agentic_executables_cli.dart';
import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('CodexExecGenerationEngine parses fake codex output', () async {
    final temp = await Directory.systemTemp.createTemp('ae_codex_fixture_');
    addTearDown(() => temp.delete(recursive: true));

    final codexScript = File(p.join(temp.path, 'codex'));
    await codexScript.writeAsString(r'''#!/usr/bin/env bash
if [ "$1" = "exec" ]; then
  cat <<'JSON'
{"ae_install.md":"# install","ae_uninstall.md":"# uninstall","ae_update.md":"# update","ae_use.md":"# use","notes":"ok"}
JSON
  exit 0
fi
exit 1
''');
    await Process.run('chmod', ['+x', codexScript.path]);

    final engine = CodexExecGenerationEngine(binaryName: codexScript.path);
    expect(engine.isAvailable, isTrue);

    final result = await engine.generate(
      GenerateInput(
        libraryId: 'dart_provider',
        libraryRoot: temp.path,
        outputDir: p.join(temp.path, 'ae_use'),
      ),
    );

    expect(result.success, isTrue);
    expect(result.data?.files.length, 4);
  });
}
