import 'dart:io';

import 'package:agentic_executables_mcp/src/adapter.dart';
import 'package:agentic_executables_core/agentic_executables_core.dart';
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

    test('verify returns v2 envelope shape', () async {
      final result = await adapter.verify(
        {
          'context_type': 'project',
          'action': 'install',
          'checklist_completed': {'modularity': true},
        },
      );

      expect(result['success'], isTrue);
      expect(result['data'], isA<Map>());
      expect(result['warnings'], isA<List>());
      expect(result['meta'], isA<Map>());
      expect((result['data'] as Map)['verification'], isA<Map>());
    });

    test('evaluate returns v2 envelope shape', () async {
      final result = await adapter.evaluate(
        {
          'context_type': 'project',
          'action': 'install',
          'sections_present': ['Setup', 'Config', 'Integration', 'Validation'],
          'validation_steps_exists': true,
          'integration_points_defined': true,
        },
      );

      expect(result['success'], isTrue);
      expect(result['data'], isA<Map>());
      expect((result['data'] as Map)['evaluation'], isA<Map>());
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
