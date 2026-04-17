import 'dart:io';

import 'package:agentic_executables_mcp/src/adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AeMcpAdapter.init', () {
    late Directory tempProject;
    late AeMcpAdapter adapter;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('mcp_init_');
      final hub = Directory(p.join(tempProject.path, '.ae_hub'));
      await hub.create();
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
      adapter = AeMcpAdapter(resourcesPath: '/tmp/nonexistent');
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
    });

    test('returns ok envelope when no sub-packages found', () async {
      final result = await adapter.init({'root': tempProject.path});
      expect(result['success'], isTrue);
      final data = result['data'] as Map<String, dynamic>;
      expect(data['hub_path'], contains('.ae_hub'));
      expect(data['ingested'], isEmpty);
    });

    test('returns no_hub error when project has no .ae_hub', () async {
      final naked = await Directory.systemTemp.createTemp('mcp_init_naked_');
      try {
        final result = await IOOverrides.runZoned(
          () => adapter.init({'root': naked.path}),
          getCurrentDirectory: () => naked,
        );
        expect(result['success'], isFalse);
        expect((result['error'] as Map)['code'], 'no_hub');
      } finally {
        await naked.delete(recursive: true);
      }
    });

    test('ingests a sub-package when one is present', () async {
      // Copy the dart_pkg_min fixture from core into the project as a sub-pkg.
      final fixture = Directory(
        p.join(
          Directory.current.path,
          '..',
          'agentic_executables_core',
          'test',
          'fixtures',
          'dart_pkg_min',
        ),
      );
      final target = Directory(p.join(tempProject.path, 'pkg'));
      await target.create();
      await for (final entity in fixture.list(recursive: true)) {
        final rel = p.relative(entity.path, from: fixture.path);
        if (entity is Directory) {
          await Directory(p.join(target.path, rel)).create(recursive: true);
        } else if (entity is File) {
          final out = File(p.join(target.path, rel));
          await out.create(recursive: true);
          await entity.copy(out.path);
        }
      }
      final result = await adapter.init({'root': tempProject.path});
      expect(result['success'], isTrue);
      final data = result['data'] as Map<String, dynamic>;
      expect(data['ingested'], contains('ecsly'));
    });
  });
}
