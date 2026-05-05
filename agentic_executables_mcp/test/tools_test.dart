import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:agentic_executables_mcp/src/adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AeMcpAdapter', () {
    late Directory tempDir;
    late AeMcpAdapter adapter;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ae_mcp_docs_');
      await File(p.join(tempDir.path, 'ae_context.md'))
          .writeAsString('context');
      await File(p.join(tempDir.path, 'ae_use.md')).writeAsString('use');
      await File(p.join(tempDir.path, 'ae_bootstrap.md'))
          .writeAsString('bootstrap');

      adapter = AeMcpAdapter(resourcesPath: tempDir.path);
    });

    tearDown(() async {
      adapter.close();
      await tempDir.delete(recursive: true);
    });

    test('instructions envelope mirrors core output', () async {
      final adapterResult = await adapter.instructions(
        {
          'context_type': 'library',
          'action': 'bootstrap',
        },
      );

      final coreResult = await DefaultAeInstructionService(
        FileDocumentStore(tempDir.path),
      ).getInstructions(
        const GetInstructionsInput(
          context: AeContext.library,
          action: AeAction.bootstrap,
        ),
      );

      expect(adapterResult['success'], coreResult.success);
      expect(
        (adapterResult['data'] as Map)['documents'],
        coreResult.data?.documents,
      );
    });

    test('generate auto resolves to template in MCP', () async {
      final result = await adapter.generate(
        {
          'library_id': 'dart_provider',
          'library_root': tempDir.path,
          'engine': 'auto',
          'dry_run': true,
        },
      );

      expect(result['success'], isTrue);
      expect((result['data'] as Map)['engine_resolved'], 'template');
      final warnings = (result['warnings'] as List).join(' ');
      expect(warnings.toLowerCase(), isNot(contains('codex')));
    });

    test('generate rejects codex engine for MCP hard-cut v3', () async {
      final result = await adapter.generate(
        {
          'library_id': 'dart_provider',
          'library_root': tempDir.path,
          'engine': 'codex',
        },
      );

      expect(result['success'], isFalse);
      expect((result['error'] as Map)['code'], 'validation_error');
    });

    test('verify accepts typed payload', () async {
      final result = await adapter.verify(
        {
          'context_type': 'project',
          'action': 'install',
          'files_modified': [
            {
              'path': 'ae_install.md',
              'loc': 20,
              'sections': ['Setup'],
            },
          ],
          'checklist_completed': {'modularity': true},
        },
      );

      expect(result['success'], isTrue);
      expect((result['data'] as Map)['verification'], isA<Map>());
    });

    test('verify rejects string-encoded JSON payloads', () async {
      final result = await adapter.verify(
        {
          'context_type': 'project',
          'action': 'install',
          'files_modified':
              '[{"path":"ae_install.md","loc":20,"sections":["Setup"]}]',
          'checklist_completed': '{"modularity":true}',
        },
      );

      expect(result['success'], isFalse);
      expect((result['error'] as Map)['code'], 'validation_error');
      expect(
          (result['error'] as Map)['message'], contains('no longer supported'),);
    });

    test('evaluate accepts typed payload', () async {
      final result = await adapter.evaluate(
        {
          'context_type': 'project',
          'action': 'install',
          'files_created': [
            {'path': 'ae_install.md', 'loc': 20},
          ],
          'sections_present': ['Setup', 'Config', 'Integration', 'Validation'],
          'validation_steps_exists': true,
          'integration_points_defined': true,
        },
      );

      expect(result['success'], isTrue);
      expect((result['data'] as Map)['evaluation'], isA<Map>());
    });

    test('evaluate rejects string-encoded JSON payloads', () async {
      final result = await adapter.evaluate(
        {
          'context_type': 'project',
          'action': 'install',
          'files_created': '[{"path":"ae_install.md","loc":20}]',
          'sections_present': '["Setup"]',
          'validation_steps_exists': 'true',
        },
      );

      expect(result['success'], isFalse);
      expect((result['error'] as Map)['code'], 'validation_error');
      expect(
          (result['error'] as Map)['message'], contains('no longer supported'),);
    });

    test('registry bootstrap mirrors core output', () async {
      final adapterResult = await adapter.registry(
        {
          'operation': 'bootstrap_local_registry',
          'ae_use_path': '/tmp/my_lib/ae_use',
        },
      );

      final coreResult = DefaultAeRegistryService(
        _NoopRegistryClient(),
      ).bootstrapLocalRegistry(
        const RegistryBootstrapLocalInput(aeUsePath: '/tmp/my_lib/ae_use'),
      );

      expect(adapterResult['success'], coreResult.success);
      expect(
        (adapterResult['data'] as Map)['suggested_library_id'],
        coreResult.data?.suggestedLibraryId,
      );
    });
  });
}

class _NoopRegistryClient implements RegistryClient {
  @override
  String buildRegistryUrl(final String libraryId, final AeAction action) => '';

  @override
  Future<String> fetchRegistryFile(
    final String libraryId,
    final AeAction action,
  ) async =>
      '';

  @override
  Future<bool> libraryExists(final String libraryId) async => false;
}
