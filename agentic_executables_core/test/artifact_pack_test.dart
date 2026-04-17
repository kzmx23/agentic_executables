import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('ArtifactKind', () {
    test('all values', () {
      expect(ArtifactKind.fromString('local'), ArtifactKind.local);
      expect(ArtifactKind.fromString('external'), ArtifactKind.external);
      expect(ArtifactKind.fromString('use'), ArtifactKind.use);
    });
  });

  group('ArtifactSourceType', () {
    test('all values', () {
      expect(ArtifactSourceType.fromString('path'), ArtifactSourceType.path);
      expect(ArtifactSourceType.fromString('url'), ArtifactSourceType.url);
      expect(ArtifactSourceType.fromString('git'), ArtifactSourceType.git);
    });
  });

  group('ArtifactSourceFile', () {
    test('serializes path + sha256', () {
      const f = ArtifactSourceFile(path: 'lib/x.dart', sha256: 'abc');
      final j = f.toJson();
      expect(j['path'], 'lib/x.dart');
      expect(j['sha256'], 'abc');
    });
  });

  group('CanonicalReference', () {
    test('live reference parses (no @)', () {
      final r = CanonicalReference.parse('ecs');
      expect(r.conceptId, 'ecs');
      expect(r.lockedVersion, isNull);
      expect(r.toString(), 'ecs');
    });

    test('locked reference parses (with @)', () {
      final r = CanonicalReference.parse('gltf/core@v2');
      expect(r.conceptId, 'gltf/core');
      expect(r.lockedVersion, 2);
      expect(r.toString(), 'gltf/core@v2');
    });

    test('rejects malformed lock', () {
      expect(() => CanonicalReference.parse('x@v'), throwsArgumentError);
      expect(() => CanonicalReference.parse('x@2'), throwsArgumentError);
    });
  });

  group('ArtifactMeta', () {
    test('toYamlString + fromMap round-trip for local kind', () {
      final meta = ArtifactMeta(
        kind: ArtifactKind.local,
        title: 'Dart ecs',
        source: const ArtifactSource(
          type: ArtifactSourceType.path,
          path: 'core_packages/ecs',
          files: [
            ArtifactSourceFile(path: 'lib/src/world.dart', sha256: 'h1'),
            ArtifactSourceFile(path: 'lib/src/entity.dart', sha256: 'h2'),
          ],
        ),
        scannedAt: DateTime.utc(2026, 4, 17, 13),
        license: const ArtifactLicense(spdx: 'MIT', detectedFrom: 'license_file'),
        authors: const [
          ArtifactAuthor(name: 'A. Malofeev', detectedFrom: 'pubspec'),
        ],
        referencesCanonical: [
          CanonicalReference.parse('ecs'),
          CanonicalReference.parse('gltf/core@v2'),
        ],
        extractor: 'dart_v1',
        distill: const ArtifactDistill(engine: 'heuristic'),
      );
      final yamlStr = meta.toYamlString();
      final loaded = loadYaml(yamlStr) as Map;
      final back = ArtifactMeta.fromMap(loaded);
      expect(back.kind, ArtifactKind.local);
      expect(back.source.path, 'core_packages/ecs');
      expect(back.source.files.length, 2);
      expect(back.referencesCanonical.length, 2);
      expect(back.referencesCanonical[1].lockedVersion, 2);
      expect(back.license?.spdx, 'MIT');
    });
  });

  group('ArtifactPack', () {
    test('holds meta + matrix + content', () {
      final meta = ArtifactMeta(
        kind: ArtifactKind.local,
        title: 'X',
        source: const ArtifactSource(
          type: ArtifactSourceType.path,
          path: 'p',
        ),
        scannedAt: DateTime.now(),
        referencesCanonical: const [],
        extractor: 'dart_v1',
        distill: const ArtifactDistill(engine: 'heuristic'),
      );
      final pack = ArtifactPack(
        name: 'dart_x',
        meta: meta,
        indexContent: '# X',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      );
      expect(pack.name, 'dart_x');
      expect(pack.indexContent, '# X');
    });
  });
}
