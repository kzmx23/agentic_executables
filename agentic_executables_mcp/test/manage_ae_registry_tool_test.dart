import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('server registers only v3 tool names', () async {
    final serverFile = File(
      p.join(Directory.current.path, 'lib', 'src', 'server.dart'),
    );
    expect(serverFile.existsSync(), isTrue);

    final source = await serverFile.readAsString();

    const expectedTools = [
      'ae_definition',
      'ae_instructions',
      'ae_generate',
      'ae_registry',
      'ae_verify',
      'ae_evaluate',
    ];

    for (final tool in expectedTools) {
      expect(source, contains("name: '$tool'"));
    }

    const removedTools = [
      'get_agentic_executable_definition',
      'get_ae_instructions',
      'manage_ae_registry',
      'verify_ae_implementation',
      'evaluate_ae_compliance',
    ];

    for (final oldTool in removedTools) {
      expect(source, isNot(contains("name: '$oldTool'")));
    }
  });

  test('v3 tool schemas enforce required core fields and hard cuts', () async {
    final source = await File(
      p.join(Directory.current.path, 'lib', 'src', 'server.dart'),
    ).readAsString();

    expect(source, contains("required: ['context_type', 'action']"));
    expect(source, contains("required: ['library_id', 'library_root']"));
    expect(source, contains("required: ['operation']"));

    expect(source, contains("enumValues: ['auto', 'template']"));
    expect(
        source, isNot(contains("enumValues: ['auto', 'codex', 'template']")),);

    expect(source, contains("'files_modified': Schema.list"));
    expect(source, isNot(contains("'files_modified': Schema.string()")));

    expect(source, contains("'files_created': Schema.list"));
    expect(source, isNot(contains("'files_created': Schema.string()")));
  });
}
