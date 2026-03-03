import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('server registers only v2 tool names', () async {
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

  test('v2 tool schemas keep required core fields', () async {
    final source = await File(
      p.join(Directory.current.path, 'lib', 'src', 'server.dart'),
    ).readAsString();

    expect(source, contains("required: ['context_type', 'action']"));
    expect(source, contains("required: ['library_id', 'library_root']"));
    expect(source, contains("required: ['operation']"));
  });
}
