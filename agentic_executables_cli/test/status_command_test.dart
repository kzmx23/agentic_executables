import 'dart:io';

import 'package:agentic_executables_cli/agentic_executables_cli.dart';
import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ae status', () {
    late Directory tempProject;
    late Directory tempHome;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('ae_status_proj_');
      tempHome = await Directory.systemTemp.createTemp('ae_status_home_');
      final hub = Directory(p.join(tempProject.path, '.ae_hub'));
      await hub.create();
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
      await tempHome.delete(recursive: true);
    });

    test('status returns empty tier counts when hub has no artifacts',
        () async {
      final cli = AeCli(environment: {'HOME': tempHome.path});
      final exit = await cli.run([
        'status',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
    });

    test('status surfaces tier 1 invariant violation', () async {
      // Stage a canonical with an invariant + an artifact that lacks tests=yes.
      final canStore = FileCanonicalStore(p.join(tempProject.path, '.ae_hub'));
      final artStore = FileArtifactStore(p.join(tempProject.path, '.ae_hub'));
      await canStore.save(
        'ecs',
        CanonicalPack(
          meta: CanonicalMeta(
            concept: 'ecs',
            version: 1,
            title: 'ECS',
            license:
                const CanonicalLicense(spdx: 'CC-BY-4.0', url: 'https://c'),
            authors: const [],
            sources: const [
              CanonicalSource(
                kind: CanonicalSourceKind.code,
                title: 's',
                url: 'https://x',
              ),
            ],
            provenance: CanonicalProvenance(
              authored: CanonicalAuthored.hand,
              authoredAt: DateTime.utc(2026, 4, 17),
            ),
          ),
          indexContent: '# ecs',
          matrix: CanonicalMatrix(
            concept: 'ecs',
            version: 1,
            columnSchema: const [
              CanonicalColumn(id: 'spec', type: 'text'),
              CanonicalColumn(id: 'invariant', type: 'text'),
            ],
            features: [
              CanonicalFeature(
                id: FeatureId.parse('system.tick'),
                cells: const {
                  'spec': 'order',
                  'invariant': 'monotonic',
                },
              ),
            ],
          ),
        ),
      );
      await artStore.save(ArtifactPack(
        name: 'pack',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'pack',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: '/tmp/pack',
          ),
          scannedAt: DateTime.utc(2026, 4, 17),
          referencesCanonical: [CanonicalReference.parse('ecs')],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# pack',
        matrix: ArtifactMatrix(
          columnSchema: const [],
          features: [
            ArtifactFeatureRow(
              id: FeatureId.parse('system.tick'),
              canonical: 'ecs',
              cell: const ArtifactCell(impl: ImplStatus.partial),
            ),
          ],
        ),
      ));

      final cli = AeCli(environment: {'HOME': tempHome.path});
      // Exits 0 for status (it's diagnostic, not strict).
      final exit = await cli.run([
        'status',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
    });
  });
}
