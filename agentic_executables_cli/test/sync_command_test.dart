import 'dart:io';

import 'package:agentic_executables_cli/agentic_executables_cli.dart';
import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ae sync', () {
    late Directory tempProject;
    late Directory tempHome;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('ae_sync_proj_');
      tempHome = await Directory.systemTemp.createTemp('ae_sync_home_');
      final hub = Directory(p.join(tempProject.path, '.ae_hub'));
      await hub.create();
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
      await tempHome.delete(recursive: true);
    });

    test('sync returns ok when hub has no artifacts', () async {
      final cli = AeCli(environment: {'HOME': tempHome.path});
      final exit = await cli.run(['sync', '--root', tempProject.path]);
      expect(exit, 0);
    });

    test('sync --prune removes pack whose source is gone', () async {
      final artStore = FileArtifactStore(p.join(tempProject.path, '.ae_hub'));
      await artStore.save(ArtifactPack(
        name: 'orphan',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'orphan',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: '/nonexistent/path',
          ),
          scannedAt: DateTime.utc(2026, 4, 17),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# orphan',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      ));
      final cli = AeCli(environment: {'HOME': tempHome.path});
      final exit = await cli.run([
        'sync',
        '--root',
        tempProject.path,
        '--prune',
      ]);
      expect(exit, 0);
      expect(await artStore.exists('orphan'), isFalse);
    });

    test('sync --pack reports back name', () async {
      // Stage a pack with no source files.
      final artStore = FileArtifactStore(p.join(tempProject.path, '.ae_hub'));
      await artStore.save(ArtifactPack(
        name: 'p1',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'p1',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: '/nonexistent',
          ),
          scannedAt: DateTime.utc(2026, 4, 17),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# p1',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      ));
      final cli = AeCli(environment: {'HOME': tempHome.path});
      final exit = await cli.run([
        'sync',
        '--root',
        tempProject.path,
        '--pack',
        'p1',
      ]);
      expect(exit, 0);
    });
  });
}
