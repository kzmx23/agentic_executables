import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

CanonicalPack _canonical(
  final String concept,
  final List<({String id, String? invariant})> features,
) {
  return CanonicalPack(
    meta: CanonicalMeta(
      concept: concept,
      version: 1,
      title: concept,
      license: const CanonicalLicense(spdx: 'CC-BY-4.0', url: 'https://c'),
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
    indexContent: '# $concept',
    matrix: CanonicalMatrix(
      concept: concept,
      version: 1,
      columnSchema: const [
        CanonicalColumn(id: 'spec', type: 'text'),
        CanonicalColumn(id: 'invariant', type: 'text'),
      ],
      features: [
        for (final f in features)
          CanonicalFeature(
            id: FeatureId.parse(f.id),
            cells: {
              'spec': 'spec for ${f.id}',
              if (f.invariant != null) 'invariant': f.invariant!,
            },
          ),
      ],
    ),
  );
}

ArtifactPack _artifact({
  required final String name,
  required final List<CanonicalReference> references,
  required final List<ArtifactFeatureRow> rows,
  final List<ArtifactRequiresEntry> requires = const [],
}) =>
    ArtifactPack(
      name: name,
      meta: ArtifactMeta(
        kind: ArtifactKind.local,
        title: name,
        source: ArtifactSource(
          type: ArtifactSourceType.path,
          path: '/tmp/$name',
        ),
        scannedAt: DateTime.utc(2026, 4, 17),
        referencesCanonical: references,
        extractor: 'dart_v1',
        distill: const ArtifactDistill(engine: 'heuristic'),
      ),
      indexContent: '# $name',
      matrix: ArtifactMatrix(columnSchema: const [], features: rows),
      requires: requires.isEmpty ? null : RequiresSpec(entries: requires),
    );

void main() {
  group('ArtifactService verify', () {
    late Directory tempHub;
    late FileArtifactStore artStore;
    late FileCanonicalStore canStore;
    late HeuristicExtractorRegistry registry;
    late DefaultArtifactService svc;

    setUp(() async {
      tempHub = await Directory.systemTemp.createTemp('ae_verify_');
      artStore = FileArtifactStore(tempHub.path);
      canStore = FileCanonicalStore(tempHub.path);
      registry = HeuristicExtractorRegistry(const []);
      svc = DefaultArtifactService(
        artifactStore: artStore,
        canonicalStore: canStore,
        extractorRegistry: registry,
      );
    });

    tearDown(() async {
      await tempHub.delete(recursive: true);
    });

    test('verifyOne: tier 1 invariant violation when row lacks tests=yes',
        () async {
      await canStore.save('ecs',
          _canonical('ecs', [(id: 'system.tick', invariant: 'monotonic')]));
      await artStore.save(_artifact(
        name: 'pack',
        references: [CanonicalReference.parse('ecs')],
        rows: [
          ArtifactFeatureRow(
            id: FeatureId.parse('system.tick'),
            canonical: 'ecs',
            cell: const ArtifactCell(impl: ImplStatus.partial),
          ),
        ],
      ));
      final report = await svc.verifyOne('pack');
      final t1 = report.byTier(VerifyTier.invariantViolation);
      expect(t1, hasLength(1));
      expect(t1.first.featureId.toString(), 'system.tick');
    });

    test('verifyOne: tier 3 when feature is partial (no invariant)', () async {
      await canStore.save('ecs',
          _canonical('ecs', [(id: 'entity.create', invariant: null)]));
      await artStore.save(_artifact(
        name: 'pack',
        references: [CanonicalReference.parse('ecs')],
        rows: [
          ArtifactFeatureRow(
            id: FeatureId.parse('entity.create'),
            canonical: 'ecs',
            cell: const ArtifactCell(impl: ImplStatus.partial),
          ),
        ],
      ));
      final report = await svc.verifyOne('pack');
      expect(report.byTier(VerifyTier.partialFeature), hasLength(1));
    });

    test('verifyOne: tier 4 unreferenced canonical present in hub', () async {
      await canStore.save(
          'ecs', _canonical('ecs', [(id: 'entity.create', invariant: null)]));
      await canStore.save('lights',
          _canonical('lights', [(id: 'spot.cone', invariant: null)]));
      await artStore.save(_artifact(
        name: 'pack',
        references: [CanonicalReference.parse('ecs')],
        rows: [],
      ));
      final report = await svc.verifyOne('pack');
      // Only ecs is referenced; lights surfaces as unreferenced
      final t4 = report.byTier(VerifyTier.unreferencedCanonical);
      expect(t4.map((final e) => e.canonical), contains('lights'));
    });

    test('verifyProject: tier 2 sorted by downstream count', () async {
      // upstream artifact a provides ecs.entity.create (status missing) → blocker
      await canStore.save(
        'ecs',
        _canonical('ecs', [
          (id: 'entity.create', invariant: null),
          (id: 'system.tick', invariant: null),
        ]),
      );
      await artStore.save(_artifact(
        name: 'a',
        references: [CanonicalReference.parse('ecs')],
        rows: [
          ArtifactFeatureRow(
            id: FeatureId.parse('entity.create'),
            canonical: 'ecs',
            cell: const ArtifactCell(impl: ImplStatus.missing),
          ),
        ],
      ));
      // Two downstream artifacts both require entity.create from a.
      await artStore.save(_artifact(
        name: 'b',
        references: const [],
        rows: const [],
        requires: [
          ArtifactRequiresEntry(
            artifact: 'a',
            canonical: 'ecs',
            features: [FeatureId.parse('entity.create')],
          ),
        ],
      ));
      await artStore.save(_artifact(
        name: 'c',
        references: const [],
        rows: const [],
        requires: [
          ArtifactRequiresEntry(
            artifact: 'a',
            canonical: 'ecs',
            features: [FeatureId.parse('entity.create')],
          ),
        ],
      ));

      final report = await svc.verifyProject();
      final t2 = report.byTier(VerifyTier.upstreamBlocker);
      expect(t2, hasLength(1));
      expect(t2.first.artifact, 'a');
      expect(t2.first.featureId.toString(), 'entity.create');
      expect(t2.first.downstreamCount, 2);
    });
  });
}
