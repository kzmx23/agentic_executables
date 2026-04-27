import 'dart:convert';
import 'dart:io';

import 'package:agentic_executables_cli/agentic_executables_cli.dart';
import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('ae spec export (v3)', () {
    late Directory tempProject;
    late Directory tempHome;
    late String hubPath;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('ae_spec_proj_');
      tempHome = await Directory.systemTemp.createTemp('ae_spec_home_');
      hubPath = p.join(tempProject.path, '.ae_hub');
      await Directory(hubPath).create(recursive: true);
      await File(p.join(hubPath, 'hub.yaml')).writeAsString('version: 1\n');
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
      await tempHome.delete(recursive: true);
    });

    test('emits spec_export.v3 with canonical + artifact files', () async {
      // Seed one canonical (ecs) with two features.
      final canStore = FileCanonicalStore(hubPath);
      final now = DateTime.utc(2026, 4, 17);
      await canStore.save('ecs', CanonicalPack(
        meta: CanonicalMeta(
          concept: 'ecs',
          version: 1,
          title: 'Entity-Component-System',
          license: const CanonicalLicense(
            spdx: 'CC-BY-4.0',
            url: 'https://creativecommons.org/licenses/by/4.0/',
          ),
          authors: const [
            CanonicalAuthor(
              name: 'Anton Malofeev',
              role: CanonicalAuthorRole.originalAuthor,
            ),
          ],
          sources: const [
            CanonicalSource(
              kind: CanonicalSourceKind.code,
              title: 'Bevy',
              url: 'https://github.com/bevyengine/bevy',
            ),
          ],
          provenance: CanonicalProvenance(
            authored: CanonicalAuthored.hand,
            authoredAt: now,
          ),
        ),
        indexContent: '# ecs\n\nEntity-Component-System canonical.\n',
        matrix: CanonicalMatrix(
          concept: 'ecs',
          version: 1,
          columnSchema: const [
            CanonicalColumn(id: 'spec', type: 'text'),
            CanonicalColumn(id: 'invariant', type: 'text'),
          ],
          features: [
            CanonicalFeature(
              id: FeatureId.parse('entity.create'),
              cells: const {
                'spec': 'An entity is created with a unique opaque handle.',
                'invariant': 'Handles are non-reusable within a session.',
              },
            ),
            CanonicalFeature(
              id: FeatureId.parse('system.tick'),
              cells: const {
                'spec': 'Systems run in declared order each tick.',
                'invariant': 'Tick is monotonically increasing.',
              },
            ),
          ],
        ),
      ));

      // Seed one artifact (dart_ecs) referencing ecs.
      final artStore = FileArtifactStore(hubPath);
      await artStore.save(ArtifactPack(
        name: 'dart_ecs',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'Dart ECS (core)',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: 'core_packages/ecs',
          ),
          scannedAt: now,
          referencesCanonical: [CanonicalReference.parse('ecs')],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# dart_ecs\n',
        matrix: ArtifactMatrix(
          columnSchema: const [
            ArtifactColumn(id: 'impl', type: 'enum'),
            ArtifactColumn(id: 'tests', type: 'enum'),
          ],
          features: [
            ArtifactFeatureRow(
              id: FeatureId.parse('entity.create'),
              canonical: 'ecs',
              cell: const ArtifactCell(
                impl: ImplStatus.done,
                tests: TestStatus.yes,
              ),
            ),
            ArtifactFeatureRow(
              id: FeatureId.parse('system.tick'),
              canonical: 'ecs',
              cell: const ArtifactCell(
                impl: ImplStatus.partial,
                tests: TestStatus.no,
              ),
            ),
          ],
        ),
      ));

      final outDir = p.join(tempProject.path, 'out');
      final cli = AeCli(environment: {'HOME': tempHome.path});
      final exit = await cli.run([
        'spec',
        'export',
        '--out',
        outDir,
        '--hub',
        hubPath,
      ]);
      expect(exit, 0);

      // spec_index.json
      final indexFile = File(p.join(outDir, 'spec_index.json'));
      expect(await indexFile.exists(), isTrue);
      final index = jsonDecode(await indexFile.readAsString())
          as Map<String, dynamic>;
      expect(index['schema'], 'spec_export.v3');
      expect(index['version'], 3);
      expect(index['export_base'], '.');
      expect(index['locale'], 'en');

      final canonicals = index['canonicals'] as List;
      expect(canonicals, hasLength(1));
      expect((canonicals.first as Map)['concept'], 'ecs');
      expect((canonicals.first as Map)['file'], 'canonical_ecs.json');
      expect((canonicals.first as Map)['feature_count'], 2);

      final artifacts = index['artifacts'] as List;
      expect(artifacts, hasLength(1));
      expect((artifacts.first as Map)['name'], 'dart_ecs');
      expect((artifacts.first as Map)['file'], 'artifact_dart_ecs.json');

      // canonical JSON
      final canFile = File(p.join(outDir, 'canonical_ecs.json'));
      expect(await canFile.exists(), isTrue);
      final canJson =
          jsonDecode(await canFile.readAsString()) as Map<String, dynamic>;
      expect(canJson['schema'], 'ae.canonical.v3');
      expect((canJson['meta'] as Map)['schema'], 'ae.canonical.meta.v1');
      expect((canJson['matrix'] as Map)['schema'], 'ae.canonical_matrix.v1');
      final canFeatures = (canJson['matrix'] as Map)['features'] as List;
      expect(canFeatures, hasLength(2));
      expect(canJson['index_md'], contains('ecs'));

      // artifact JSON
      final artFile = File(p.join(outDir, 'artifact_dart_ecs.json'));
      expect(await artFile.exists(), isTrue);
      final artJson =
          jsonDecode(await artFile.readAsString()) as Map<String, dynamic>;
      expect(artJson['schema'], 'ae.artifact.v3');
      expect((artJson['meta'] as Map)['schema'], 'ae.artifact.meta.v1');
      expect((artJson['matrix'] as Map)['schema'], 'ae.artifact_matrix.v1');
      final artFeatures = (artJson['matrix'] as Map)['features'] as List;
      expect(artFeatures, hasLength(2));

      // definition trio present.
      expect(await File(p.join(outDir, 'definition.yaml')).exists(), isTrue);
      expect(await File(p.join(outDir, 'definition.md')).exists(), isTrue);
      expect(await File(p.join(outDir, 'definition.json')).exists(), isTrue);
    });

    test('spec export carries CanonicalFeature.removed through to canonical JSON', () async {
      // Build a hub with a canonical that has one removed:true row.
      final canStore = FileCanonicalStore(hubPath);
      final now = DateTime.utc(2026, 4, 27);
      await canStore.save('demo', CanonicalPack(
        meta: CanonicalMeta(
          concept: 'demo',
          version: 1,
          title: 'Demo',
          license: const CanonicalLicense(
            spdx: 'CC-BY-4.0',
            url: 'https://creativecommons.org/licenses/by/4.0/',
          ),
          authors: const [],
          sources: const [],
          provenance: CanonicalProvenance(
            authored: CanonicalAuthored.scaffolded,
            authoredAt: now,
          ),
        ),
        indexContent: '# demo\n',
        matrix: CanonicalMatrix(
          concept: 'demo',
          version: 1,
          columnSchema: const [
            CanonicalColumn(id: 'spec', type: 'text'),
          ],
          features: [
            CanonicalFeature(
              id: FeatureId.parse('demo.kept'),
              cells: const {'spec': 'still here'},
            ),
            CanonicalFeature(
              id: FeatureId.parse('demo.gone'),
              cells: const {'spec': 'was here'},
              removed: true,
            ),
          ],
        ),
      ));

      final outDir = p.join(tempProject.path, 'out_removed');
      final cli = AeCli(environment: {'HOME': tempHome.path});
      final exit = await cli.run([
        'spec', 'export',
        '--out', outDir,
        '--hub', hubPath,
      ]);
      expect(exit, 0);

      final canFile = File(p.join(outDir, 'canonical_demo.json'));
      expect(await canFile.exists(), isTrue);
      final canJson = jsonDecode(await canFile.readAsString()) as Map<String, dynamic>;
      final features = ((canJson['matrix'] as Map)['features'] as List)
          .cast<Map<String, dynamic>>();
      final tombstone = features.firstWhere(
        (final f) => f['id'] == 'demo.gone',
      );
      expect(tombstone['removed'], isTrue,
          reason: 'spec_export.v3 must surface the removed flag for downstream '
              'consumers (see id-stability design Q11)');
      // Verify non-removed row does NOT carry the key.
      final kept = features.firstWhere((final f) => f['id'] == 'demo.kept');
      expect(kept.containsKey('removed'), isFalse,
          reason: 'removed:false must be omitted to keep output stable');
    });

    test('empty hub still emits spec_index.json + definition trio', () async {
      final outDir = p.join(tempProject.path, 'out_empty');
      final result = await runCli([
        'spec',
        'export',
        '--out',
        outDir,
        '--hub',
        hubPath,
      ]);
      expect(result.exitCode, 0);

      final indexFile = File(p.join(outDir, 'spec_index.json'));
      expect(await indexFile.exists(), isTrue);
      final index = jsonDecode(await indexFile.readAsString())
          as Map<String, dynamic>;
      expect(index['schema'], 'spec_export.v3');
      expect(index['canonicals'], isEmpty);
      expect(index['artifacts'], isEmpty);

      expect(await File(p.join(outDir, 'definition.yaml')).exists(), isTrue);
      expect(await File(p.join(outDir, 'definition.md')).exists(), isTrue);
      expect(await File(p.join(outDir, 'definition.json')).exists(), isTrue);

      final defPtr = jsonDecode(
        await File(p.join(outDir, 'definition.json')).readAsString(),
      ) as Map<String, dynamic>;
      expect(defPtr['schema'], 'ae.spec_definition_ptr.v1');
    });
  });
}
