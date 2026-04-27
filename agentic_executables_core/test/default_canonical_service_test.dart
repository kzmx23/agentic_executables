import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _FakeArtifactStore implements ArtifactStore {
  _FakeArtifactStore(this._packs);
  final Map<String, String> _packs; // name → indexContent

  @override
  Future<bool> exists(final String name) async => _packs.containsKey(name);

  @override
  Future<ArtifactPack?> load(final String name) async {
    final indexContent = _packs[name];
    if (indexContent == null) return null;
    return ArtifactPack(
      name: name,
      meta: ArtifactMeta(
        kind: ArtifactKind.local,
        title: name,
        source: const ArtifactSource(
          type: ArtifactSourceType.path,
          path: 'src',
          files: [],
        ),
        scannedAt: DateTime.utc(2026, 4, 27),
        referencesCanonical: const [],
        extractor: 'dart_v1',
        distill: const ArtifactDistill(engine: 'heuristic'),
      ),
      indexContent: indexContent,
      matrix: const ArtifactMatrix(columnSchema: [], features: []),
    );
  }

  @override
  dynamic noSuchMethod(final Invocation i) => super.noSuchMethod(i);
}

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
      // With the strict validator (Phase B), we must scaffold first with
      // matching feature ids.
      await svc.scaffold('ecs', title: 'ECS');
      await svc.upsert('ecs', _samplePack('ecs', features: [
        CanonicalFeature(
          id: FeatureId.parse('feature.a'),
          cells: const {'spec': 'A'},
        ),
      ]));
      final pack = await svc.mergeDistillation('ecs', _output('ecs'));
      expect(pack.meta.concept, 'ecs');
      expect(pack.matrix.features.first.id.toString(), 'feature.a');
      expect(await store.exists('ecs'), isTrue);
    });

    test('mergeDistillationDetailed reports duplicate ids + accurate counts',
        () async {
      // With the strict validator (Phase B), we must scaffold first with
      // matching feature ids.
      await svc.scaffold('ecs', title: 'ECS');
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
      // Seed the scaffold with the ids to avoid the validator rejection.
      await svc.upsert('ecs', _samplePack('ecs', features: [
        CanonicalFeature(
          id: FeatureId.parse('feature.a'),
          cells: const {'spec': 'A'},
        ),
        CanonicalFeature(
          id: FeatureId.parse('feature.b'),
          cells: const {'spec': 'B'},
        ),
      ]));
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
      // With the strict validator (Phase B), we must scaffold first with
      // matching feature ids.
      await svc.scaffold('ecs_new', title: 'ECS New');
      await svc.upsert('ecs_new', _samplePack('ecs_new', features: [
        CanonicalFeature(
          id: FeatureId.parse('feature.a'),
          cells: const {'spec': 'A'},
        ),
      ]));
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
      // With the strict validator (Phase B), we must scaffold first with
      // matching feature ids.
      await svc.scaffold('ecs', title: 'ECS');
      await svc.upsert('ecs', _samplePack('ecs', features: [
        CanonicalFeature(
          id: FeatureId.parse('feature.a'),
          cells: const {'spec': 'A'},
        ),
      ]));
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

    test('mergeDistillationDetailed rejects features when no canonical exists yet', () async {
      // Empty-matrix bypass closure (M2). Pre-Phase B, distill against a missing
      // concept silently created a pack from the LLM output. Now: validator runs
      // unconditionally; the operator must scaffold or init first.
      final tmp = await Directory.systemTemp.createTemp('id_stability_b0_no_pack');
      addTearDown(() async {
        await tmp.delete(recursive: true);
      });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

      // Note: NO scaffold/init. `existing` will be null inside the merge.
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
              cells: const {'spec': 's', 'invariant': 'i'},
            ),
          ],
        ),
      );

      expect(
        () => service.mergeDistillationDetailed('demo', output),
        throwsA(isA<IdNotInMatrixException>()
            .having((final e) => e.knownIdCount, 'knownIdCount', 0)
            .having((final e) => e.unknownIds, 'unknownIds', ['demo.invented'])),
      );
    });

    test('mergeDistillationDetailed accepts empty-features output even with no canonical', () async {
      // Counterpart to the rejection test: when the LLM correctly produces zero
      // features (e.g. all signal routed to proposed_concepts), the validator
      // does NOT trip. This is the "init alone, then distill rejects all" path
      // closing cleanly when distill respects the contract.
      final tmp = await Directory.systemTemp.createTemp('id_stability_b0_empty_ok');
      addTearDown(() async {
        await tmp.delete(recursive: true);
      });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

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
            spec: 's', invariant: 'i', rationale: 'cross-cutting',
          ),
        ],
      );

      // No canonical exists. Output has zero features. Should succeed and create
      // the pack from the (empty) output, carrying the proposals through.
      final result = await service.mergeDistillationDetailed('demo', output);
      expect(result.featureCountAfterMerge, 0);
      expect(result.proposedConcepts, hasLength(1));
    });

    test('scaffoldUpdate adds rows for new symbols and marks vanished as removed', () async {
      final tmp = await Directory.systemTemp.createTemp('id_stability_b1_diff');
      addTearDown(() async {
        await tmp.delete(recursive: true);
      });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

      // Stage 1: scaffold against an artifact with two symbols (kept, gone).
      final initialArtStore = _FakeArtifactStore({
        'demo': '## Public API\n- `kept` (function)\n- `gone` (function)\n',
      });
      await service.scaffoldFromArtifact(
        'demo',
        title: 'Demo',
        artifactNames: const ['demo'],
        artifactStore: initialArtStore,
      );

      // Hand-edit: enrich kept's spec so we can check preservation.
      final pre = (await service.load('demo'))!;
      final enriched = CanonicalPack(
        meta: pre.meta,
        indexContent: pre.indexContent,
        matrix: CanonicalMatrix(
          concept: pre.matrix.concept,
          version: pre.matrix.version,
          columnSchema: pre.matrix.columnSchema,
          features: [
            for (final f in pre.matrix.features)
              if (f.id.toString() == 'demo.kept')
                CanonicalFeature(
                  id: f.id,
                  cells: const {'spec': 'enriched-by-hand', 'invariant': 'inv'},
                )
              else
                f,
          ],
        ),
      );
      await service.upsert('demo', enriched);

      // Stage 2: source artifact gains `added`, loses `gone`.
      final updatedArtStore = _FakeArtifactStore({
        'demo': '## Public API\n- `kept` (function)\n- `added` (function)\n',
      });

      final report = await service.scaffoldUpdate(
        'demo',
        artifactNames: const ['demo'],
        artifactStore: updatedArtStore,
      );

      expect(report.added, ['demo.added']);
      expect(report.removed, ['demo.gone']);
      expect(report.unchanged, 1);
      expect(report.renamed, isEmpty);

      final after = (await service.load('demo'))!;
      final byId = {for (final f in after.matrix.features) f.id.toString(): f};
      expect(byId.keys, containsAll(['demo.kept', 'demo.added', 'demo.gone']));
      expect(byId['demo.kept']!.cells['spec'], 'enriched-by-hand',
          reason: 'preserves text on unchanged rows');
      expect(byId['demo.gone']!.removed, isTrue,
          reason: 'marks vanished, does not delete');
      expect(byId['demo.gone']!.cells['spec'], isNotEmpty,
          reason: 'preserves text on removed rows');
      expect(byId['demo.added']!.removed, isFalse);
    });

    test('scaffoldUpdate is idempotent (re-running with same source produces no diff)', () async {
      final tmp = await Directory.systemTemp.createTemp('id_stability_b1_idempotent');
      addTearDown(() async {
        await tmp.delete(recursive: true);
      });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

      final artStore = _FakeArtifactStore({
        'demo': '## Public API\n- `a` (function)\n- `b` (function)\n',
      });
      await service.scaffoldFromArtifact(
        'demo',
        title: 'Demo',
        artifactNames: const ['demo'],
        artifactStore: artStore,
      );

      final r1 = await service.scaffoldUpdate(
        'demo',
        artifactNames: const ['demo'],
        artifactStore: artStore,
      );
      expect(r1.added, isEmpty);
      expect(r1.removed, isEmpty);
      expect(r1.unchanged, 2);

      final r2 = await service.scaffoldUpdate(
        'demo',
        artifactNames: const ['demo'],
        artifactStore: artStore,
      );
      expect(r2.added, isEmpty);
      expect(r2.removed, isEmpty);
      expect(r2.unchanged, 2);
    });

    test('scaffoldUpdate preserves accepted_concept rows (no false tombstone)', () async {
      // Without the provenance check, accepted-concept rows look like vanished
      // symbols (no source id matches) and would be tombstoned every --update.
      final tmp = await Directory.systemTemp.createTemp('id_stability_b1_accept_preserve');
      addTearDown(() async {
        await tmp.delete(recursive: true);
      });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

      final artStore = _FakeArtifactStore({
        'demo': '## Public API\n- `kept` (function)\n',
      });
      await service.scaffoldFromArtifact(
        'demo',
        title: 'Demo',
        artifactNames: const ['demo'],
        artifactStore: artStore,
      );

      // Hand-add an accepted-concept row (mimics a successful B4 acceptConcept).
      final pre = (await service.load('demo'))!;
      final withAccepted = CanonicalPack(
        meta: pre.meta,
        indexContent: pre.indexContent,
        matrix: CanonicalMatrix(
          concept: pre.matrix.concept,
          version: pre.matrix.version,
          columnSchema: pre.matrix.columnSchema,
          features: [
            ...pre.matrix.features,
            CanonicalFeature(
              id: FeatureId.parse('demo.json_envelope'),
              cells: const {
                'spec': 'every command writes JSON',
                'invariant': 'success is bool',
                'provenance': 'accepted_concept',
              },
            ),
          ],
        ),
      );
      await service.upsert('demo', withAccepted);

      // Re-run --update against the same artifact (no source change).
      final report = await service.scaffoldUpdate(
        'demo',
        artifactNames: const ['demo'],
        artifactStore: artStore,
      );

      expect(report.removed, isEmpty,
          reason: 'accepted_concept rows must not be tombstoned by --update');
      expect(report.added, isEmpty);

      final after = (await service.load('demo'))!;
      final byId = {for (final f in after.matrix.features) f.id.toString(): f};
      expect(byId['demo.json_envelope']!.removed, isFalse);
      expect(byId['demo.json_envelope']!.cells['provenance'], 'accepted_concept');
    });

    test('scaffoldUpdate errors when the canonical does not exist', () async {
      final tmp = await Directory.systemTemp.createTemp('id_stability_b1_missing');
      addTearDown(() async {
        await tmp.delete(recursive: true);
      });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

      final artStore = _FakeArtifactStore({
        'demo': '## Public API\n- `x` (function)\n',
      });
      expect(
        () => service.scaffoldUpdate(
          'never_scaffolded',
          artifactNames: const ['demo'],
          artifactStore: artStore,
        ),
        throwsA(isA<StateError>().having(
          (final e) => e.message,
          'message',
          contains('canonical_not_found'),
        )),
      );
    });

    test('CanonicalFeature carries removed flag through round-trip serialization', () {
      final feature = CanonicalFeature(
        id: FeatureId.parse('demo.gone'),
        cells: const {'spec': 'old', 'invariant': 'old'},
        removed: true,
      );
      final json = feature.toJson();
      expect(json['removed'], isTrue);
      final round = CanonicalFeature.fromMap(json);
      expect(round.removed, isTrue);
      expect(round.id.toString(), 'demo.gone');
      expect(round.cells['spec'], 'old');
    });

    test('CanonicalFeature.removed defaults to false on legacy payloads', () {
      // Flat shape (no nested 'cells' key) — matches on-disk YAML format.
      final json = {'id': 'demo.kept', 'spec': 's'};
      final feature = CanonicalFeature.fromMap(json);
      expect(feature.removed, isFalse);
      expect(feature.toJson().containsKey('removed'), isFalse,
          reason: 'omit `removed: false` from JSON to keep yaml stable');
    });

    test('scaffoldUpdate --rename migrates id and preserves text', () async {
      final tmp = await Directory.systemTemp.createTemp('id_stability_b2_rename');
      addTearDown(() async { await tmp.delete(recursive: true); });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

      final initialArt = _FakeArtifactStore({
        'demo': '## Public API\n- `oldName` (function)\n',
      });
      await service.scaffoldFromArtifact(
        'demo',
        title: 'Demo',
        artifactNames: const ['demo'],
        artifactStore: initialArt,
      );

      // Hand-enrich the row.
      final pre = (await service.load('demo'))!;
      final enriched = CanonicalPack(
        meta: pre.meta,
        indexContent: pre.indexContent,
        matrix: CanonicalMatrix(
          concept: pre.matrix.concept,
          version: pre.matrix.version,
          columnSchema: pre.matrix.columnSchema,
          features: [
            CanonicalFeature(
              id: FeatureId.parse('demo.old_name'),
              cells: const {'spec': 'PRESERVE-ME', 'invariant': 'KEEP-ME'},
            ),
          ],
        ),
      );
      await service.upsert('demo', enriched);

      // Source artifact renamed `oldName` → `newName`.
      final renamedArt = _FakeArtifactStore({
        'demo': '## Public API\n- `newName` (function)\n',
      });
      final report = await service.scaffoldUpdate(
        'demo',
        artifactNames: const ['demo'],
        artifactStore: renamedArt,
        renames: [['demo.old_name', 'demo.new_name']],
      );

      expect(report.renamed, [['demo.old_name', 'demo.new_name']]);
      expect(report.added, isEmpty);
      expect(report.removed, isEmpty);
      expect(report.unchanged, 0);

      final after = (await service.load('demo'))!;
      final byId = {for (final f in after.matrix.features) f.id.toString(): f};
      expect(byId.keys, containsAll(['demo.new_name', 'demo.old_name']));
      expect(byId['demo.new_name']!.cells['spec'], 'PRESERVE-ME');
      expect(byId['demo.new_name']!.removed, isFalse);
      expect(byId['demo.old_name']!.removed, isTrue,
          reason: 'old id retained as a tombstone for traceability');
      expect(byId['demo.old_name']!.cells['renamed_to'], 'demo.new_name');
    });

    test('scaffoldUpdate --rename errors when target id already exists', () async {
      final tmp = await Directory.systemTemp.createTemp('id_stability_b2_collision');
      addTearDown(() async { await tmp.delete(recursive: true); });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

      final art = _FakeArtifactStore({
        'demo': '## Public API\n- `a` (function)\n- `b` (function)\n',
      });
      await service.scaffoldFromArtifact(
        'demo',
        title: 'Demo',
        artifactNames: const ['demo'],
        artifactStore: art,
      );

      expect(
        () => service.scaffoldUpdate(
          'demo',
          artifactNames: const ['demo'],
          artifactStore: art,
          renames: [['demo.a', 'demo.b']], // demo.b already exists
        ),
        throwsA(isA<ArgumentError>().having(
          (final e) => e.message?.toString() ?? '',
          'message',
          contains('rename_collision'),
        )),
      );
    });

    test('scaffoldUpdate --rename errors when source id is absent', () async {
      final tmp = await Directory.systemTemp.createTemp('id_stability_b2_missing_old');
      addTearDown(() async { await tmp.delete(recursive: true); });
      final store = FileCanonicalStore(tmp.path);
      final service = DefaultCanonicalService(store: store);

      final art = _FakeArtifactStore({
        'demo': '## Public API\n- `a` (function)\n',
      });
      await service.scaffoldFromArtifact(
        'demo',
        title: 'Demo',
        artifactNames: const ['demo'],
        artifactStore: art,
      );

      expect(
        () => service.scaffoldUpdate(
          'demo',
          artifactNames: const ['demo'],
          artifactStore: art,
          renames: [['demo.does_not_exist', 'demo.something']],
        ),
        throwsA(isA<ArgumentError>().having(
          (final e) => e.message?.toString() ?? '',
          'message',
          contains('rename_missing'),
        )),
      );
    });
  });
}

