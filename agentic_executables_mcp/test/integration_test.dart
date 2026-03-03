import 'dart:io';

import 'package:agentic_executables_mcp/src/adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
      'MCP adapter integration: definition -> instructions -> generate -> verify/evaluate -> registry',
      () async {
    final temp = await Directory.systemTemp.createTemp('ae_mcp_integration_');
    addTearDown(() => temp.delete(recursive: true));

    final docsDir = Directory(p.join(temp.path, 'docs'));
    await docsDir.create(recursive: true);
    await File(p.join(docsDir.path, 'ae_context.md')).writeAsString('context');
    await File(p.join(docsDir.path, 'ae_bootstrap.md'))
        .writeAsString('bootstrap');
    await File(p.join(docsDir.path, 'ae_use.md')).writeAsString('use');

    final adapter = AeMcpAdapter(resourcesPath: docsDir.path);
    addTearDown(adapter.close);

    final definition = await adapter.definition({});
    expect(definition['success'], isTrue);

    final instructions = await adapter.instructions(
      {
        'context_type': 'library',
        'action': 'bootstrap',
      },
    );
    expect(instructions['success'], isTrue);
    final instructionDocs = (instructions['data'] as Map)['documents'] as Map;
    expect(instructionDocs.keys,
        containsAll(['ae_context.md', 'ae_bootstrap.md']));

    final generatedDir = p.join(temp.path, 'ae_use');
    final generate = await adapter.generate(
      {
        'library_id': 'dart_provider',
        'library_root': temp.path,
        'output_dir': generatedDir,
        'engine': 'template',
        'dry_run': false,
      },
    );
    expect(generate['success'], isTrue);

    for (final file in const [
      'ae_install.md',
      'ae_uninstall.md',
      'ae_update.md',
      'ae_use.md',
    ]) {
      expect(File(p.join(generatedDir, file)).existsSync(), isTrue);
    }

    final installLoc =
        File(p.join(generatedDir, 'ae_install.md')).readAsLinesSync().length;

    final verify = await adapter.verify(
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
    );
    expect(verify['success'], isTrue);
    expect(((verify['data'] as Map)['overall_status']), 'PASS');

    final evaluate = await adapter.evaluate(
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
    );
    expect(evaluate['success'], isTrue);
    expect(((evaluate['data'] as Map)['overall_status']), 'PASS');

    final registryBootstrap = await adapter.registry(
      {
        'operation': 'bootstrap_local_registry',
        'ae_use_path': generatedDir,
      },
    );
    expect(registryBootstrap['success'], isTrue);

    final registrySubmit = await adapter.registry(
      {
        'operation': 'submit_to_registry',
        'library_url': 'https://github.com/example/dart_provider',
        'library_id': 'dart_provider',
        'ae_use_files':
            'ae_use/ae_install.md,ae_use/ae_uninstall.md,ae_use/ae_update.md,ae_use/ae_use.md',
      },
    );
    expect(registrySubmit['success'], isTrue);
  });
}
