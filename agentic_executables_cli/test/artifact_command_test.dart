import 'dart:io';

import 'package:agentic_executables_cli/agentic_executables_cli.dart';
import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ae artifact', () {
    late Directory tempProject;
    late Directory tempHome;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('ae_art_proj_');
      tempHome = await Directory.systemTemp.createTemp('ae_art_home_');
      final hub = Directory(p.join(tempProject.path, '.ae_hub'));
      await hub.create();
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
      await tempHome.delete(recursive: true);
    });

    test('artifact list returns names', () async {
      final artStore = FileArtifactStore(p.join(tempProject.path, '.ae_hub'));
      await artStore.save(ArtifactPack(
        name: 'p1',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'p1',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: '/x',
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
        'artifact',
        'list',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
    });

    test('artifact link adds canonical reference', () async {
      final artStore = FileArtifactStore(p.join(tempProject.path, '.ae_hub'));
      await artStore.save(ArtifactPack(
        name: 'p1',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'p1',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: '/x',
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
        'artifact',
        'link',
        '--pack',
        'p1',
        '--canonical',
        'ecs',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
      final loaded = await artStore.load('p1');
      expect(loaded!.meta.referencesCanonical, hasLength(1));
      expect(loaded.meta.referencesCanonical.first.conceptId, 'ecs');
    });

    test('artifact verify --pack returns tier counts', () async {
      final artStore = FileArtifactStore(p.join(tempProject.path, '.ae_hub'));
      await artStore.save(ArtifactPack(
        name: 'p1',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'p1',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: '/x',
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
        'artifact',
        'verify',
        '--pack',
        'p1',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
    });
  });
}
