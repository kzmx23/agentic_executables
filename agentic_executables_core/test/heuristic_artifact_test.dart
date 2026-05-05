import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('HeuristicArtifact', () {
    test('toArtifactPack produces a local artifact with empty matrix', () {
      final meta = ArtifactMeta(
        kind: ArtifactKind.local,
        title: 'dart_pkg_min',
        source: const ArtifactSource(
          type: ArtifactSourceType.path,
          path: 'fixtures/dart_pkg_min',
          files: [
            ArtifactSourceFile(path: 'lib/foo.dart', sha256: 'abc'),
          ],
        ),
        scannedAt: DateTime.utc(2026, 4, 17, 13),
        license:
            const ArtifactLicense(spdx: 'MIT', detectedFrom: 'license_file'),
        authors: const [],
        referencesCanonical: const [],
        extractor: 'dart_v1',
        distill: const ArtifactDistill(engine: 'heuristic'),
      );
      final art = HeuristicArtifact(
        name: 'dart_pkg_min',
        languageId: 'dart',
        meta: meta,
        indexMd: '# dart_pkg_min\n\nA tiny Dart package.\n',
      );

      final pack = art.toArtifactPack();
      expect(pack.name, 'dart_pkg_min');
      expect(pack.meta.kind, ArtifactKind.local);
      expect(pack.indexContent, contains('A tiny Dart package'));
      expect(pack.matrix.features, isEmpty);
      expect(pack.matrix.columnSchema, isEmpty);
    });
  });
}
