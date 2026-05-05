import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:agentic_executables_mcp/src/adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AeMcpAdapter.canonical', () {
    late Directory tempProject;
    late AeMcpAdapter adapter;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('mcp_can_');
      final hub = Directory(p.join(tempProject.path, '.ae_hub'));
      await hub.create();
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
      adapter = AeMcpAdapter(resourcesPath: '/tmp/nonexistent');
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
    });

    test('init creates a new canonical pack', () async {
      final result = await adapter.canonical({
        'operation': 'init',
        'concept': 'ecs',
        'title': 'ECS',
        'root': tempProject.path,
      });
      expect(result['success'], isTrue);
      final metaFile = File(p.join(
        tempProject.path,
        '.ae_hub',
        'canonical',
        'ecs',
        'meta.yaml',
      ),);
      expect(await metaFile.exists(), isTrue);
    });

    test('list returns saved concept ids', () async {
      await adapter.canonical({
        'operation': 'init',
        'concept': 'ecs',
        'title': 'ECS',
        'root': tempProject.path,
      });
      final result = await adapter.canonical({
        'operation': 'list',
        'root': tempProject.path,
      });
      expect(result['success'], isTrue);
      expect((result['data'] as Map)['concepts'], contains('ecs'));
    });

    test('snapshot freezes live + creates v1 dir', () async {
      await adapter.canonical({
        'operation': 'init',
        'concept': 'ecs',
        'title': 'ECS',
        'root': tempProject.path,
      });
      final result = await adapter.canonical({
        'operation': 'snapshot',
        'concept': 'ecs',
        'root': tempProject.path,
      });
      expect(result['success'], isTrue);
      final v1 = Directory(p.join(
        tempProject.path,
        '.ae_hub',
        'canonical',
        'ecs',
        'v1',
      ),);
      expect(await v1.exists(), isTrue);
    });

    test('scaffold seeds canonical from artifact public API', () async {
      final artStore = FileArtifactStore(p.join(tempProject.path, '.ae_hub'));
      await artStore.save(
        ArtifactPack(
          name: 'pkg_a',
          meta: ArtifactMeta(
            kind: ArtifactKind.local,
            title: 'pkg_a',
            source: const ArtifactSource(
              type: ArtifactSourceType.path,
              path: 'src/pkg_a',
            ),
            scannedAt: DateTime.utc(2026, 4, 17),
            referencesCanonical: const [],
            extractor: 'dart_v1',
            distill: const ArtifactDistill(engine: 'heuristic'),
          ),
          indexContent: '# pkg_a\n\n## Public API\n\n'
              '- `Foo` (class) [lib/x.dart]\n'
              '- `runFoo` (function) [lib/x.dart]\n',
          matrix: const ArtifactMatrix(columnSchema: [], features: []),
        ),
      );
      final result = await adapter.canonical({
        'operation': 'scaffold',
        'concept': 'pkg/concept',
        'title': 'PKG concept',
        'from_artifact': ['pkg_a'],
        'root': tempProject.path,
      });
      expect(result['success'], isTrue);
      final data = result['data'] as Map;
      expect(data['feature_count'], 2);
      expect(data['authored'], 'scaffolded');
    });

    test('scaffold rejects missing from_artifact', () async {
      final result = await adapter.canonical({
        'operation': 'scaffold',
        'concept': 'pkg/concept',
        'title': 'PKG',
        'root': tempProject.path,
      });
      expect(result['success'], isFalse);
      expect((result['error'] as Map)['code'], 'validation_error');
    });

    test('scaffold update reports added/removed against existing canonical',
        () async {
      final artStore = FileArtifactStore(p.join(tempProject.path, '.ae_hub'));

      // Stage 1: artifact with two symbols (alpha, beta).
      await artStore.save(ArtifactPack(
        name: 'demo_pack',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'demo_pack',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: 'src/demo',
          ),
          scannedAt: DateTime.utc(2026, 4, 27),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# demo_pack\n\n## Public API\n\n'
            '- `alpha` (function)\n'
            '- `beta` (function)\n',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      ),);

      // Initial scaffold.
      final scaffoldResult = await adapter.canonical({
        'operation': 'scaffold',
        'concept': 'demo',
        'title': 'Demo',
        'from_artifact': ['demo_pack'],
        'root': tempProject.path,
      });
      expect(scaffoldResult['success'], isTrue);

      // Stage 2: update artifact — add gamma, remove beta.
      await artStore.save(ArtifactPack(
        name: 'demo_pack',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'demo_pack',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: 'src/demo',
          ),
          scannedAt: DateTime.utc(2026, 4, 27),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# demo_pack\n\n## Public API\n\n'
            '- `alpha` (function)\n'
            '- `gamma` (function)\n',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      ),);

      // Run scaffold --update.
      final result = await adapter.canonical({
        'operation': 'scaffold',
        'concept': 'demo',
        'from_artifact': ['demo_pack'],
        'update': true,
        'root': tempProject.path,
      });
      expect(result['success'], isTrue);
      final data = result['data'] as Map;
      expect(data['mode'], 'update');
      expect(data['added'] as List, contains('demo_pack.gamma'));
      expect(data['removed'] as List, contains('demo_pack.beta'));
    });

    test('scaffold update --rename migrates id and preserves text', () async {
      final artStore = FileArtifactStore(p.join(tempProject.path, '.ae_hub'));

      // Stage 1: artifact with one symbol (oldName).
      await artStore.save(ArtifactPack(
        name: 'demo_pack',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'demo_pack',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: 'src/demo',
          ),
          scannedAt: DateTime.utc(2026, 4, 27),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# demo_pack\n\n## Public API\n\n'
            '- `oldName` (function)\n',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      ),);

      // Initial scaffold.
      final scaffoldResult = await adapter.canonical({
        'operation': 'scaffold',
        'concept': 'demo',
        'title': 'Demo',
        'from_artifact': ['demo_pack'],
        'root': tempProject.path,
      });
      expect(scaffoldResult['success'], isTrue);

      // Stage 2: artifact now has newName instead of oldName.
      await artStore.save(ArtifactPack(
        name: 'demo_pack',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'demo_pack',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: 'src/demo',
          ),
          scannedAt: DateTime.utc(2026, 4, 27),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# demo_pack\n\n## Public API\n\n'
            '- `newName` (function)\n',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      ),);

      // Run scaffold --update with renames.
      final result = await adapter.canonical({
        'operation': 'scaffold',
        'concept': 'demo',
        'from_artifact': ['demo_pack'],
        'update': true,
        'renames': [
          {'from': 'demo_pack.old_name', 'to': 'demo_pack.new_name'},
        ],
        'root': tempProject.path,
      });
      expect(result['success'], isTrue);
      final data = result['data'] as Map;
      expect(data['mode'], 'update');
      expect(
        (data['renamed'] as List).single,
        {'from': 'demo_pack.old_name', 'to': 'demo_pack.new_name'},
      );
    });

    test('ae_canonical accept-concept happy path returns accepted_id',
        () async {
      // Setup: scaffold a concept and write proposals via service.
      final canStore = FileCanonicalStore(p.join(tempProject.path, '.ae_hub'));
      final svc = DefaultCanonicalService(store: canStore);
      await svc.scaffold('demo', title: 'Demo');
      await svc.writeProposalsFile(
        'demo',
        proposals: const [
          ProposedConcept(
            name: 'envelope-shape',
            spec: 'every command writes JSON',
            invariant: 'success is bool',
            rationale: 'cross-cutting',
          ),
        ],
        executorUsed: 'claude_code',
      );

      final result = await adapter.canonical({
        'operation': 'accept-concept',
        'concept': 'demo',
        'id': 'demo.json_envelope',
        'from_proposal': 'envelope-shape',
        'root': tempProject.path,
      });
      expect(result['success'], isTrue);
      expect((result['data'] as Map)['accepted_id'], 'demo.json_envelope');
    });

    test(
        'ae_canonical accept-concept returns id_collision when id already exists',
        () async {
      // Setup: scaffold + upsert a row at demo.taken + write proposals.
      final canStore = FileCanonicalStore(p.join(tempProject.path, '.ae_hub'));
      final svc = DefaultCanonicalService(store: canStore);
      await svc.scaffold('demo', title: 'Demo');
      await svc.upsert(
        'demo',
        CanonicalPack(
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
              authored: CanonicalAuthored.hand,
              authoredAt: DateTime.utc(2026, 4, 27),
            ),
          ),
          indexContent: '# demo',
          matrix: CanonicalMatrix(
            concept: 'demo',
            version: 1,
            columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
            features: [
              CanonicalFeature(
                id: FeatureId.parse('demo.taken'),
                cells: const {'spec': 's'},
              ),
            ],
          ),
        ),
      );
      await svc.writeProposalsFile(
        'demo',
        proposals: const [
          ProposedConcept(
            name: 'envelope-shape',
            spec: 'every command writes JSON',
            invariant: 'success is bool',
            rationale: 'cross-cutting',
          ),
        ],
        executorUsed: 'claude_code',
      );

      final result = await adapter.canonical({
        'operation': 'accept-concept',
        'concept': 'demo',
        'id': 'demo.taken',
        'from_proposal': 'envelope-shape',
        'root': tempProject.path,
      });
      expect(result['success'], isFalse);
      expect(((result['error']) as Map)['code'], 'id_collision');
    });

    test('returns validation_error when operation missing', () async {
      final result = await adapter.canonical({});
      expect(result['success'], isFalse);
      expect((result['error'] as Map)['code'], 'validation_error');
    });

    test('returns validation_error for unknown operation', () async {
      final result = await adapter.canonical({
        'operation': 'frobnicate',
        'root': tempProject.path,
      });
      expect(result['success'], isFalse);
      expect((result['error'] as Map)['code'], 'validation_error');
    });
  });
}
