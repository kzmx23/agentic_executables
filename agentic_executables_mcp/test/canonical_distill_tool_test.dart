import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:agentic_executables_mcp/src/adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _FakeFixedExecutor implements DistillationExecutor {
  _FakeFixedExecutor(this._output);
  final DistillationOutput _output;

  @override
  String get executorId => 'fake';

  @override
  Future<bool> canRun() async => true;

  @override
  Future<DistillationOutput> execute(final DistillationTask task) async =>
      _output;
}

DistillationOutput _cannedOutput(final String concept) => DistillationOutput(
      conceptId: concept,
      conceptVersion: 1,
      indexMd: '# $concept (distilled)\n',
      matrix: CanonicalMatrix(
        concept: concept,
        version: 1,
        columnSchema: const [
          CanonicalColumn(id: 'spec', type: 'text'),
        ],
        features: [
          CanonicalFeature(
            id: FeatureId.parse('entity.create'),
            cells: const {'spec': 'Make a new entity.'},
          ),
          CanonicalFeature(
            id: FeatureId.parse('entity.destroy'),
            cells: const {'spec': 'Destroy an entity.'},
          ),
        ],
      ),
    );

Future<void> _writeArtifactPack(final String hubPath) async {
  final meta = ArtifactMeta(
    kind: ArtifactKind.local,
    title: 'Dart ECS',
    source: const ArtifactSource(
      type: ArtifactSourceType.path,
      path: 'core_packages/ecs',
      files: [
        ArtifactSourceFile(path: 'lib/src/world.dart', sha256: 'h1'),
      ],
    ),
    scannedAt: DateTime.utc(2026, 4, 17, 12),
    license: const ArtifactLicense(spdx: 'MIT'),
    referencesCanonical: [CanonicalReference.parse('ecs')],
    extractor: 'dart_v1',
    distill: const ArtifactDistill(engine: 'heuristic'),
  );
  final pack = ArtifactPack(
    name: 'dart_ecs',
    meta: meta,
    indexContent: '# dart_ecs\n\nSummary.\n',
    matrix: const ArtifactMatrix(columnSchema: [], features: []),
  );
  final store = FileArtifactStore(hubPath);
  await store.save(pack);
}

Future<void> _writeCanonicalSeed(final String hubPath) async {
  final store = FileCanonicalStore(hubPath);
  final svc = DefaultCanonicalService(store: store);
  await svc.scaffold('ecs', title: 'ECS');
  // Seed the matrix with the ids that the test fixtures distill, so
  // the id-stability validator (mergeDistillationDetailed) accepts the run.
  final seeded = await svc.load('ecs');
  await svc.upsert(
    'ecs',
    CanonicalPack(
      meta: seeded!.meta,
      indexContent: seeded.indexContent,
      changelogContent: seeded.changelogContent,
      matrix: CanonicalMatrix(
        concept: 'ecs',
        version: 1,
        columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
        features: [
          CanonicalFeature(
            id: FeatureId.parse('entity.create'),
            cells: const {'spec': 'stub'},
          ),
          CanonicalFeature(
            id: FeatureId.parse('entity.destroy'),
            cells: const {'spec': 'stub'},
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('AeMcpAdapter.canonical (distill)', () {
    late Directory tempProject;
    late String hubPath;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('mcp_distill_');
      final hub = Directory(p.join(tempProject.path, '.ae_hub'));
      await hub.create();
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
      hubPath = hub.path;
      await _writeArtifactPack(hubPath);
      await _writeCanonicalSeed(hubPath);
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
    });

    test('distill happy path: merges output into canonical', () async {
      final svc = DefaultDistillationService(
        executors: [_FakeFixedExecutor(_cannedOutput('ecs'))],
      );
      final adapter = AeMcpAdapter(
        resourcesPath: '/tmp/nonexistent',
        distillationServiceOverride: svc,
      );
      final result = await adapter.canonical({
        'operation': 'distill',
        'pack': 'dart_ecs',
        'concept': 'ecs',
        'root': tempProject.path,
      });

      expect(result['success'], isTrue, reason: 'result: $result');
      final data = result['data'] as Map<String, dynamic>;
      expect(data['concept'], 'ecs');
      expect(data['feature_count'], 2);
      expect(data['mode'], 'upsert');
      expect(data['executor_used'], 'fake');

      final store = FileCanonicalStore(hubPath);
      final loaded = await store.load('ecs');
      expect(loaded, isNotNull);
      expect(loaded!.matrix.features.length, 2);
    });

    test('distill fails with validation_error when pack missing', () async {
      final adapter = AeMcpAdapter(resourcesPath: '/tmp/nonexistent');
      final result = await adapter.canonical({
        'operation': 'distill',
        'concept': 'ecs',
        'root': tempProject.path,
      });
      expect(result['success'], isFalse);
      expect((result['error'] as Map)['code'], 'validation_error');
    });

    test('distill fails with artifact_not_found when pack unknown',
        () async {
      final svc = DefaultDistillationService(
        executors: [_FakeFixedExecutor(_cannedOutput('ecs'))],
      );
      final adapter = AeMcpAdapter(
        resourcesPath: '/tmp/nonexistent',
        distillationServiceOverride: svc,
      );
      final result = await adapter.canonical({
        'operation': 'distill',
        'pack': 'missing_pack',
        'concept': 'ecs',
        'root': tempProject.path,
      });
      expect(result['success'], isFalse);
      expect((result['error'] as Map)['code'], 'artifact_not_found');
    });

    test('canonical distill envelope includes proposed_concepts when set',
        () async {
      // Construct an output with one ProposedConcept on top of the seeded
      // ids — the seeded matrix has entity.create + entity.destroy, so the
      // validator accepts the entity.create row in the distill output.
      final output = DistillationOutput(
        conceptId: 'ecs',
        conceptVersion: 1,
        indexMd: '# ecs\n',
        matrix: CanonicalMatrix(
          concept: 'ecs',
          version: 1,
          columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
          features: [
            CanonicalFeature(
              id: FeatureId.parse('entity.create'),
              cells: const {'spec': 'enriched'},
            ),
          ],
        ),
        proposedConcepts: const [
          ProposedConcept(
            name: 'envelope-shape',
            spec: 'every command writes JSON',
            invariant: 'success is bool',
            rationale: 'cross-cutting',
          ),
        ],
      );
      final svc = DefaultDistillationService(
        executors: [_FakeFixedExecutor(output)],
      );
      final adapter = AeMcpAdapter(
        resourcesPath: '/tmp/nonexistent',
        distillationServiceOverride: svc,
      );
      final result = await adapter.canonical({
        'operation': 'distill',
        'pack': 'dart_ecs',
        'concept': 'ecs',
        'root': tempProject.path,
      });

      expect(result['success'], isTrue, reason: 'result: $result');
      final data = result['data'] as Map<String, dynamic>;
      expect(data['proposed_concepts'], isA<List<dynamic>>());
      expect((data['proposed_concepts'] as List), hasLength(1));
      expect(
        ((data['proposed_concepts'] as List).single as Map)['name'],
        'envelope-shape',
      );
    });

    test(
        'canonical distill returns id_not_in_matrix error when distill emits unknown ids',
        () async {
      // Distill output emits an id NOT in the seeded matrix.
      final output = DistillationOutput(
        conceptId: 'ecs',
        conceptVersion: 1,
        indexMd: '',
        matrix: CanonicalMatrix(
          concept: 'ecs',
          version: 1,
          columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
          features: [
            CanonicalFeature(
              id: FeatureId.parse('entity.invented'),
              cells: const {'spec': 'unauthorized'},
            ),
          ],
        ),
      );
      final svc = DefaultDistillationService(
        executors: [_FakeFixedExecutor(output)],
      );
      final adapter = AeMcpAdapter(
        resourcesPath: '/tmp/nonexistent',
        distillationServiceOverride: svc,
      );
      final result = await adapter.canonical({
        'operation': 'distill',
        'pack': 'dart_ecs',
        'concept': 'ecs',
        'root': tempProject.path,
      });

      expect(result['success'], isFalse, reason: 'result: $result');
      expect(result['error'], isNotNull);
    });
  });
}
