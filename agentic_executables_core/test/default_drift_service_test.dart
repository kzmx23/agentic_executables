import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('DefaultDriftService', () {
    late Directory tempHub;
    late Directory sourceRoot;
    late FileArtifactStore artStore;
    late FileCanonicalStore canStore;
    late DefaultDriftService svc;

    setUp(() async {
      tempHub = await Directory.systemTemp.createTemp('ae_dsvc_');
      sourceRoot = await Directory.systemTemp.createTemp('ae_dsvc_src_');
      artStore = FileArtifactStore(tempHub.path);
      canStore = FileCanonicalStore(tempHub.path);
      svc = DefaultDriftService(
        artifactStore: artStore,
        canonicalStore: canStore,
      );
    });

    tearDown(() async {
      await tempHub.delete(recursive: true);
      await sourceRoot.delete(recursive: true);
    });

    Future<String> writeSource(
        final String relPath, final String content) async {
      final file = File(p.join(sourceRoot.path, relPath));
      await file.create(recursive: true);
      await file.writeAsString(content);
      return sha256.convert(content.codeUnits).toString();
    }

    ArtifactPack samplePack({
      required final List<ArtifactSourceFile> files,
      final List<CanonicalReference> references = const [],
      final List<ArtifactFeatureRow> matrixRows = const [],
    }) {
      return ArtifactPack(
        name: 'pack',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'pack',
          source: ArtifactSource(
            type: ArtifactSourceType.path,
            path: sourceRoot.path,
            files: files,
          ),
          scannedAt: DateTime.utc(2026, 4, 17),
          referencesCanonical: references,
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# pack',
        matrix: ArtifactMatrix(columnSchema: const [], features: matrixRows),
      );
    }

    test('computeCodeDrift detects modified, added, removed', () async {
      final origHash = await writeSource('a.dart', 'one');
      await writeSource('b.dart', 'old-b');
      // Pack records a.dart=origHash, b.dart=stale, c.dart=missing
      final pack = samplePack(files: [
        ArtifactSourceFile(path: 'a.dart', sha256: origHash),
        const ArtifactSourceFile(path: 'b.dart', sha256: 'stale_b_hash'),
        const ArtifactSourceFile(path: 'c.dart', sha256: 'gone_c_hash'),
      ]);
      await artStore.save(pack);

      final entries = await svc.computeCodeDrift('pack');
      // a.dart unchanged → no entry
      expect(entries.where((final e) => e.path == 'a.dart').isEmpty, isTrue);
      // b.dart modified
      final bEntry = entries.firstWhere((final e) => e.path == 'b.dart');
      expect(bEntry.change, CodeDriftChange.modified);
      // c.dart removed (file gone)
      final cEntry = entries.firstWhere((final e) => e.path == 'c.dart');
      expect(cEntry.change, CodeDriftChange.removed);
    });

    test('computeIntentDrift flags invariants without tests=yes', () async {
      // Canonical with one invariant
      final canonical = CanonicalPack(
        meta: CanonicalMeta(
          concept: 'ecs',
          version: 1,
          title: 'ECS',
          license: const CanonicalLicense(spdx: 'CC-BY-4.0', url: 'https://c'),
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
                'spec': 'systems run in declared order',
                'invariant': 'tick is monotonic',
              },
            ),
          ],
        ),
      );
      await canStore.save('ecs', canonical);

      // Artifact references ecs but matrix row has no tests
      final pack = samplePack(
        files: const [],
        references: [CanonicalReference.parse('ecs')],
        matrixRows: [
          ArtifactFeatureRow(
            id: FeatureId.parse('system.tick'),
            canonical: 'ecs',
            cell: const ArtifactCell(impl: ImplStatus.partial),
          ),
        ],
      );
      await artStore.save(pack);

      final entries = await svc.computeIntentDrift('pack');
      expect(entries, hasLength(1));
      expect(entries.first.featureId.toString(), 'system.tick');
      expect(entries.first.canonical, 'ecs');
      expect(entries.first.invariant, 'tick is monotonic');
    });

    test('computeIntentDrift OK when matrix row has tests=yes', () async {
      final canonical = CanonicalPack(
        meta: CanonicalMeta(
          concept: 'ecs',
          version: 1,
          title: 'ECS',
          license: const CanonicalLicense(spdx: 'CC-BY-4.0', url: 'https://c'),
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
                'spec': 'systems run in declared order',
                'invariant': 'tick is monotonic',
              },
            ),
          ],
        ),
      );
      await canStore.save('ecs', canonical);

      final pack = samplePack(
        files: const [],
        references: [CanonicalReference.parse('ecs')],
        matrixRows: [
          ArtifactFeatureRow(
            id: FeatureId.parse('system.tick'),
            canonical: 'ecs',
            cell: const ArtifactCell(
              impl: ImplStatus.done,
              tests: TestStatus.yes,
            ),
          ),
        ],
      );
      await artStore.save(pack);

      final entries = await svc.computeIntentDrift('pack');
      expect(entries, isEmpty);
    });

    test('buildReport combines code + intent + accepted', () async {
      // No source / no canonical — empty drift.
      final pack = samplePack(files: const []);
      await artStore.save(pack);

      final report = await svc.buildReport('pack', generatedBy: 'ae sync');
      expect(report.generatedBy, 'ae sync');
      expect(report.codeDrift, isEmpty);
      expect(report.intentDrift, isEmpty);
      expect(report.accepted, isEmpty);
    });
  });
}
