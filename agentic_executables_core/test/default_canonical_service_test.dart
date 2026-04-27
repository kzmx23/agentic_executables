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

    test('mergeDistillationDetailed reports duplicate ids + accurate counts',
        () async {
      final dupOutput = DistillationOutput(
        conceptId: 'ecs',
        conceptVersion: 1,
        indexMd: '# distilled',
        matrix: CanonicalMatrix(
          concept: 'ecs',
          version: 1,
          columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
          features: [
            CanonicalFeature(
              id: FeatureId.parse('feature.a'),
              cells: const {'spec': 'A first'},
            ),
            CanonicalFeature(
              id: FeatureId.parse('feature.b'),
              cells: const {'spec': 'B'},
            ),
            CanonicalFeature(
              id: FeatureId.parse('feature.a'),
              cells: const {'spec': 'A second (collides)'},
            ),
          ],
        ),
      );
      final report = await svc.mergeDistillationDetailed('ecs', dupOutput);
      expect(report.featureCountReceived, 3);
      expect(report.featureCountAfterMerge, 2);
      expect(report.duplicateIds, contains('feature.a'));
      expect(report.warnings, isNotEmpty);
      // Last-write-wins on disk.
      final loaded = await svc.load('ecs');
      final feature = loaded!.matrix.features
          .firstWhere((final f) => f.id.toString() == 'feature.a');
      expect(feature.cells['spec'], 'A second (collides)');
    });

    test(
        'mergeDistillation widens column_schema to match observed feature columns',
        () async {
      // Existing scaffold-style schema (spec §4.2 minimal: spec + invariant).
      await svc.upsert(
        'ecs',
        _samplePack(
          'ecs',
          features: [
            CanonicalFeature(
              id: FeatureId.parse('feature.a'),
              cells: const {'spec': 'B'},  // pre-distill cells (will be overwritten)
            ),
          ],
        ),
      );
      // Distill output carries cells beyond the existing schema.
      final wideOutput = DistillationOutput(
        conceptId: 'ecs',
        conceptVersion: 1,
        indexMd: '# distilled',
        matrix: CanonicalMatrix(
          concept: 'ecs',
          version: 1,
          // Output also declares only [spec], but cells include invocation+notes.
          columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
          features: [
            CanonicalFeature(
              id: FeatureId.parse('feature.a'),
              cells: const {
                'spec': 'A',
                'invocation': 'AeCli().run(...)',
                'notes': 'extras carry data',
              },
            ),
          ],
        ),
      );
      final merged = await svc.mergeDistillation('ecs', wideOutput);
      final colIds =
          merged.matrix.columnSchema.map((final c) => c.id).toList();
      expect(colIds, containsAll(['spec', 'invocation', 'notes']));
      // existing schema had 'spec' — that order is preserved; new ones append.
      expect(colIds.first, 'spec');
    });

    test(
        'mergeDistillation widens column_schema on first-write (no existing pack)',
        () async {
      final wideOutput = DistillationOutput(
        conceptId: 'ecs_new',
        conceptVersion: 1,
        indexMd: '# distilled',
        matrix: CanonicalMatrix(
          concept: 'ecs_new',
          version: 1,
          columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
          features: [
            CanonicalFeature(
              id: FeatureId.parse('feature.a'),
              cells: const {
                'spec': 'A',
                'invocation': 'foo()',
              },
            ),
          ],
        ),
      );
      final merged = await svc.mergeDistillation('ecs_new', wideOutput);
      final colIds =
          merged.matrix.columnSchema.map((final c) => c.id).toList();
      expect(colIds, containsAll(['spec', 'invocation']));
    });

    test('mergeDistillationDetailed reports zero duplicates on clean output',
        () async {
      final report = await svc.mergeDistillationDetailed('ecs', _output('ecs'));
      expect(report.duplicateIds, isEmpty);
      expect(report.warnings, isEmpty);
      expect(report.featureCountReceived, 1);
      expect(report.featureCountAfterMerge, 1);
    });

    test('mergeDistillation merges into existing pack (matrix union by id)',
        () async {
      // Existing pack with one feature
      await svc.upsert('ecs', _samplePack('ecs', features: [
        CanonicalFeature(
          id: FeatureId.parse('feature.a'),
          cells: const {'spec': 'A existing'},
        ),
        CanonicalFeature(
          id: FeatureId.parse('feature.b'),
          cells: const {'spec': 'B existing'},
        ),
      ]));
      // Merge in another feature
      final merged = await svc.mergeDistillation('ecs', _output('ecs'));
      final ids = merged.matrix.features.map((final f) => f.id.toString()).toSet();
      expect(ids, containsAll(['feature.a', 'feature.b']));
      // feature.b was not in the distill output — its cells must remain
      // untouched (this is the actual union-shape contract).
      final featureB = merged.matrix.features
          .firstWhere((final f) => f.id.toString() == 'feature.b');
      expect(featureB.cells['spec'], 'B existing');
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

    test('mergeDistillationDetailed passes proposedConcepts through verbatim',
        () async {
      final tmp = await Directory.systemTemp.createTemp('id_stability_a2');
      addTearDown(() async {
        await tmp.delete(recursive: true);
      });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

      await service.scaffold('demo', title: 'Demo');

      final output = DistillationOutput(
        conceptId: 'demo',
        conceptVersion: 1,
        indexMd: '# demo',
        matrix: CanonicalMatrix(
          concept: 'demo',
          version: 1,
          columnSchema: const [],
          features: const [],
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

      final result = await service.mergeDistillationDetailed('demo', output);
      expect(result.proposedConcepts, hasLength(1));
      expect(result.proposedConcepts.single.name, 'envelope-shape');
    });

    test('mergeDistillationDetailed rejects feature rows with ids not in pre-distill matrix',
        () async {
      final tmp = await Directory.systemTemp.createTemp('id_stability_a3_reject');
      addTearDown(() async {
        await tmp.delete(recursive: true);
      });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

      // Seed an existing canonical with a single known id.
      await service.scaffold('demo', title: 'Demo');
      final seeded = _samplePack('demo', features: [
        CanonicalFeature(
          id: FeatureId.parse('demo.known'),
          cells: const {'spec': 'spec', 'invariant': 'inv'},
        ),
      ]);
      await service.upsert('demo', seeded);

      // Distill output emits a row whose id is NOT in matrix.
      final output = DistillationOutput(
        conceptId: 'demo',
        conceptVersion: 1,
        indexMd: '',
        matrix: CanonicalMatrix(
          concept: 'demo',
          version: 1,
          columnSchema: const [],
          features: [
            CanonicalFeature(
              id: FeatureId.parse('demo.invented'),
              cells: const {'spec': 'spec', 'invariant': 'inv'},
            ),
          ],
        ),
      );

      expect(
        () => service.mergeDistillationDetailed('demo', output),
        throwsA(isA<IdNotInMatrixException>()
            .having(
              (final e) => e.unknownIds,
              'unknownIds',
              contains('demo.invented'),
            )
            .having(
              (final e) => e.conceptId,
              'conceptId',
              'demo',
            )
            .having(
              (final e) => e.knownIdCount,
              'knownIdCount',
              1,
            )),
      );
    });

    test('mergeDistillationDetailed accepts feature rows with ids that ARE in pre-distill matrix',
        () async {
      final tmp = await Directory.systemTemp.createTemp('id_stability_a3_accept');
      addTearDown(() async {
        await tmp.delete(recursive: true);
      });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

      await service.scaffold('demo', title: 'Demo');
      final seeded = _samplePack('demo', features: [
        CanonicalFeature(
          id: FeatureId.parse('demo.known'),
          cells: const {'spec': 'old', 'invariant': 'old'},
        ),
      ]);
      await service.upsert('demo', seeded);

      final output = DistillationOutput(
        conceptId: 'demo',
        conceptVersion: 1,
        indexMd: '',
        matrix: CanonicalMatrix(
          concept: 'demo',
          version: 1,
          columnSchema: const [],
          features: [
            CanonicalFeature(
              id: FeatureId.parse('demo.known'),
              cells: const {'spec': 'enriched', 'invariant': 'enriched'},
            ),
          ],
        ),
      );

      final result = await service.mergeDistillationDetailed('demo', output);
      expect(result.featureCountAfterMerge, 1);
      expect(result.pack.matrix.features.single.cells['spec'], 'enriched');
    });

    test('mergeDistillationDetailed accepts an empty matrix when proposedConcepts is non-empty',
        () async {
      // Exercises validator's `existing != null` branch with empty
      // output.matrix.features. Demonstrates that empty distill output +
      // proposals passes through the validator without rejection. (Delete
      // the validator block and this test still passes — its purpose is to
      // document the proposal-passthrough path on an existing pack, not to
      // verify the validator's discriminating logic.)
      final tmp = await Directory.systemTemp.createTemp('id_stability_a3_empty');
      addTearDown(() async {
        await tmp.delete(recursive: true);
      });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

      await service.scaffold('demo', title: 'Demo');

      final output = DistillationOutput(
        conceptId: 'demo',
        conceptVersion: 1,
        indexMd: '',
        matrix: CanonicalMatrix(
          concept: 'demo',
          version: 1,
          columnSchema: const [],
          features: const [],
        ),
        proposedConcepts: const [
          ProposedConcept(
            name: 'envelope',
            spec: 'JSON',
            invariant: 'bool',
            rationale: 'cross-cutting',
          ),
        ],
      );

      final result = await service.mergeDistillationDetailed('demo', output);
      expect(result.featureCountAfterMerge, 0);
      expect(result.proposedConcepts, hasLength(1));
    });
  });
}
