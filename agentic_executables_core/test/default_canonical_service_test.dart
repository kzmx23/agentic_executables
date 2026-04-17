import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

CanonicalPack _samplePack(
  final String concept, {
  final int version = 1,
  final List<CanonicalFeature> features = const [],
  final String indexContent = '# concept',
}) {
  final meta = CanonicalMeta(
    concept: concept,
    version: version,
    title: 'Title',
    license: const CanonicalLicense(spdx: 'CC-BY-4.0', url: 'https://c.org'),
    authors: const [],
    sources: const [
      CanonicalSource(
        kind: CanonicalSourceKind.code,
        title: 'src',
        url: 'https://x',
      ),
    ],
    provenance: CanonicalProvenance(
      authored: CanonicalAuthored.hand,
      authoredAt: DateTime.utc(2026, 4, 17),
    ),
  );
  return CanonicalPack(
    meta: meta,
    indexContent: indexContent,
    matrix: CanonicalMatrix(
      concept: concept,
      version: version,
      columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
      features: features,
    ),
  );
}

DistillationOutput _output(final String concept) => DistillationOutput(
      conceptId: concept,
      conceptVersion: 1,
      indexMd: '# distilled',
      matrix: CanonicalMatrix(
        concept: concept,
        version: 1,
        columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
        features: [
          CanonicalFeature(
            id: FeatureId.parse('feature.a'),
            cells: const {'spec': 'A'},
          ),
        ],
      ),
    );

void main() {
  group('DefaultCanonicalService', () {
    late Directory tempHub;
    late FileCanonicalStore store;
    late DefaultCanonicalService svc;

    setUp(() async {
      tempHub = await Directory.systemTemp.createTemp('ae_csvc_');
      store = FileCanonicalStore(tempHub.path);
      svc = DefaultCanonicalService(store: store);
    });

    tearDown(() async {
      await tempHub.delete(recursive: true);
    });

    test('scaffold creates a minimal pack', () async {
      final pack = await svc.scaffold('ecs', title: 'ECS');
      expect(pack.meta.concept, 'ecs');
      expect(pack.meta.title, 'ECS');
      expect(pack.matrix.features, isEmpty);
      // Was persisted
      expect(await store.exists('ecs'), isTrue);
    });

    test('upsert + load round-trip', () async {
      final pack = _samplePack('ecs');
      await svc.upsert('ecs', pack);
      final loaded = await svc.load('ecs');
      expect(loaded?.meta.concept, 'ecs');
    });

    test('list reflects upserts', () async {
      await svc.scaffold('a', title: 'A');
      await svc.scaffold('b', title: 'B');
      expect(await svc.list(), containsAll(['a', 'b']));
    });

    test('mergeDistillation creates a new pack when none exists', () async {
      final pack = await svc.mergeDistillation('ecs', _output('ecs'));
      expect(pack.meta.concept, 'ecs');
      expect(pack.matrix.features.first.id.toString(), 'feature.a');
      expect(await store.exists('ecs'), isTrue);
    });

    test('mergeDistillation merges into existing pack (matrix union by id)',
        () async {
      // Existing pack with one feature
      await svc.upsert('ecs', _samplePack('ecs', features: [
        CanonicalFeature(
          id: FeatureId.parse('feature.b'),
          cells: const {'spec': 'B existing'},
        ),
      ]));
      // Merge in another feature
      final merged = await svc.mergeDistillation('ecs', _output('ecs'));
      final ids = merged.matrix.features.map((final f) => f.id.toString()).toSet();
      expect(ids, containsAll(['feature.a', 'feature.b']));
    });

    test('snapshot delegates to store and returns snapshot path', () async {
      await svc.upsert('ecs', _samplePack('ecs', version: 1));
      final snapPath = await svc.snapshot('ecs');
      expect(snapPath, contains('v1'));
    });

    test('diff between snapshot and live computes added/removed/changed',
        () async {
      // v1 has feature.b
      await svc.upsert('ecs', _samplePack('ecs', version: 1, features: [
        CanonicalFeature(
          id: FeatureId.parse('feature.b'),
          cells: const {'spec': 'old'},
        ),
      ]));
      await svc.snapshot('ecs');
      // v2 (live) replaces feature.b with feature.a, modifies existing? — added: feature.a; removed: feature.b
      await svc.upsert('ecs', _samplePack('ecs', version: 2, features: [
        CanonicalFeature(
          id: FeatureId.parse('feature.a'),
          cells: const {'spec': 'new'},
        ),
      ]));
      final diff = await svc.diff(
        'ecs',
        fromVersion: 1,
        toVersion: null,
      );
      expect(diff.addedFeatures, contains('feature.a'));
      expect(diff.removedFeatures, contains('feature.b'));
    });

    test('import copies from external dir into hub', () async {
      // Stage an external canonical dir.
      final extRoot = await Directory.systemTemp.createTemp('ae_ext_');
      try {
        final extConceptDir = Directory(p.join(extRoot.path, 'concept_src'));
        final extStore = FileCanonicalStore(extRoot.path);
        // FileCanonicalStore writes under <root>/canonical/<concept>/, so we
        // stage by saving via store and then pointing import at that dir.
        await extStore.save('foreign_concept', _samplePack('foreign_concept'));
        final importedDir =
            p.join(extRoot.path, 'canonical', 'foreign_concept');

        final pack = await svc.import(
          importedDir,
          asConceptId: 'imported',
        );
        expect(pack.meta.concept, 'foreign_concept'); // meta carries original
        expect(await store.exists('imported'), isTrue);
      } finally {
        await extRoot.delete(recursive: true);
      }
    });
  });
}
