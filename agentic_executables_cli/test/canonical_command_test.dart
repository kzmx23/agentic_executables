import 'dart:io';

import 'package:agentic_executables_cli/agentic_executables_cli.dart';
import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ae canonical', () {
    late Directory tempProject;
    late Directory tempHome;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('ae_can_proj_');
      tempHome = await Directory.systemTemp.createTemp('ae_can_home_');
      final hub = Directory(p.join(tempProject.path, '.ae_hub'));
      await hub.create();
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
      await tempHome.delete(recursive: true);
    });

    test('canonical init creates a new pack', () async {
      final cli = AeCli(environment: {'HOME': tempHome.path});
      final exit = await cli.run([
        'canonical',
        'init',
        '--concept',
        'ecs',
        '--title',
        'ECS',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
      final metaFile = File(p.join(
        tempProject.path,
        '.ae_hub',
        'canonical',
        'ecs',
        'meta.yaml',
      ));
      expect(await metaFile.exists(), isTrue);
    });

    test('canonical list returns the saved concept ids', () async {
      final cli = AeCli(environment: {'HOME': tempHome.path});
      await cli.run([
        'canonical',
        'init',
        '--concept',
        'ecs',
        '--title',
        'ECS',
        '--root',
        tempProject.path,
      ]);
      await cli.run([
        'canonical',
        'init',
        '--concept',
        'render',
        '--title',
        'Render',
        '--root',
        tempProject.path,
      ]);
      final exit = await cli.run([
        'canonical',
        'list',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
    });

    test('canonical scaffold seeds canonical from artifact public API',
        () async {
      // Stage an artifact with a Public API section in its index.
      final artStore = FileArtifactStore(p.join(tempProject.path, '.ae_hub'));
      await artStore.save(ArtifactPack(
        name: 'pkg_a',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'pkg_a',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: 'src/pkg_a',
            files: [],
          ),
          scannedAt: DateTime.utc(2026, 4, 17),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# pkg_a\n\n## Public API\n\n'
            '- `Foo` (class) — Headline [lib/x.dart]\n'
            '- `runFoo` (function) [lib/x.dart]\n',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      ));

      final cli = AeCli(environment: {'HOME': tempHome.path});
      final exit = await cli.run([
        'canonical',
        'scaffold',
        '--concept',
        'pkg/concept',
        '--title',
        'PKG concept',
        '--from-artifact',
        'pkg_a',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
      final matrixFile = File(p.join(
        tempProject.path,
        '.ae_hub',
        'canonical',
        'pkg/concept',
        'matrix.yaml',
      ));
      expect(await matrixFile.exists(), isTrue);
      final body = await matrixFile.readAsString();
      expect(body, contains('pkg_a.foo'));
      expect(body, contains('pkg_a.run_foo'));
    });

    test('canonical scaffold rejects missing --concept', () async {
      final cli = AeCli(environment: {'HOME': tempHome.path});
      final exit = await cli.run([
        'canonical',
        'scaffold',
        '--title',
        'X',
        '--from-artifact',
        'pkg_a',
        '--root',
        tempProject.path,
      ]);
      expect(exit, isNot(0));
    });

    test('canonical snapshot freezes live + bumps version', () async {
      final cli = AeCli(environment: {'HOME': tempHome.path});
      await cli.run([
        'canonical',
        'init',
        '--concept',
        'ecs',
        '--title',
        'ECS',
        '--root',
        tempProject.path,
      ]);
      final exit = await cli.run([
        'canonical',
        'snapshot',
        '--concept',
        'ecs',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
      final v1 = Directory(p.join(
        tempProject.path,
        '.ae_hub',
        'canonical',
        'ecs',
        'v1',
      ));
      expect(await v1.exists(), isTrue);
    });
  });
}
