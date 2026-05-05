import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

ArtifactPack _samplePack({
  final String name = 'dart_ecs',
  final ArtifactKind kind = ArtifactKind.local,
  final String? sourcePath = 'core_packages/ecs',
}) {
  final meta = ArtifactMeta(
    kind: kind,
    title: 'Dart ecs',
    source: ArtifactSource(
      type: ArtifactSourceType.path,
      path: sourcePath,
      files: const [
        ArtifactSourceFile(path: 'lib/src/world.dart', sha256: 'h1'),
      ],
    ),
    scannedAt: DateTime.utc(2026, 4, 17, 13),
    license: const ArtifactLicense(spdx: 'MIT', detectedFrom: 'license_file'),
    authors: const [],
    referencesCanonical: [CanonicalReference.parse('ecs')],
    extractor: 'dart_v1',
    distill: const ArtifactDistill(engine: 'heuristic'),
  );
  return ArtifactPack(
    name: name,
    meta: meta,
    indexContent: '# $name',
    matrix: ArtifactMatrix(
      columnSchema: const [
        ArtifactColumn(id: 'impl', type: 'enum', values: ['done', 'missing']),
      ],
      features: [
        ArtifactFeatureRow(
          id: FeatureId.parse('entity.create'),
          canonical: 'ecs',
          cell: const ArtifactCell(impl: ImplStatus.done),
        ),
      ],
    ),
  );
}

void main() {
  group('FileArtifactStore', () {
    late Directory tempDir;
    late FileArtifactStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ae_artifact_store_');
      store = FileArtifactStore(tempDir.path);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('save then exists then load', () async {
      final pack = _samplePack();
      final written = await store.save(pack);
      expect(written.length, greaterThanOrEqualTo(3));
      expect(await store.exists('dart_ecs'), isTrue);

      final loaded = await store.load('dart_ecs');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'dart_ecs');
      expect(loaded.meta.kind, ArtifactKind.local);
      expect(loaded.indexContent, '# dart_ecs');
      expect(loaded.matrix.features.first.id.toString(), 'entity.create');
    });

    test('save into all kinds creates correct directory', () async {
      await store.save(_samplePack(name: 'dart_ecs', kind: ArtifactKind.local));
      await store.save(_samplePack(
        name: 'khronos_gltf',
        kind: ArtifactKind.external,
        sourcePath: null,
      ));
      await store.save(_samplePack(
        name: 'dart_provider',
        kind: ArtifactKind.use,
      ));

      expect(
        await Directory(p.join(tempDir.path, 'artifacts', 'local', 'dart_ecs'))
            .exists(),
        isTrue,
      );
      expect(
        await Directory(
          p.join(tempDir.path, 'artifacts', 'external', 'khronos_gltf'),
        ).exists(),
        isTrue,
      );
      expect(
        await Directory(
          p.join(tempDir.path, 'artifacts', 'use', 'dart_provider'),
        ).exists(),
        isTrue,
      );
    });

    test('list returns names across all kinds', () async {
      await store.save(_samplePack(name: 'dart_ecs', kind: ArtifactKind.local));
      await store.save(_samplePack(
        name: 'khronos_gltf',
        kind: ArtifactKind.external,
      ));
      final all = await store.list();
      expect(all, containsAll(['dart_ecs', 'khronos_gltf']));
    });

    test('listByKind filters', () async {
      await store.save(_samplePack(name: 'dart_a', kind: ArtifactKind.local));
      await store.save(_samplePack(name: 'dart_b', kind: ArtifactKind.local));
      await store.save(_samplePack(name: 'ext_x', kind: ArtifactKind.external));

      final locals = await store.listByKind(ArtifactKind.local);
      expect(locals, containsAll(['dart_a', 'dart_b']));
      expect(locals, isNot(contains('ext_x')));

      final exts = await store.listByKind(ArtifactKind.external);
      expect(exts, contains('ext_x'));
    });

    test('remove deletes the artifact directory', () async {
      await store.save(_samplePack());
      expect(await store.remove('dart_ecs'), isTrue);
      expect(await store.exists('dart_ecs'), isFalse);
    });

    test('load returns null for unknown', () async {
      expect(await store.load('nope'), isNull);
    });

    test('save preserves patterns.md when present', () async {
      final base = _samplePack();
      final withPatterns = ArtifactPack(
        name: base.name,
        meta: base.meta,
        indexContent: base.indexContent,
        matrix: base.matrix,
        patternsContent: '# Patterns\n\nUse iso queues.',
      );
      await store.save(withPatterns);
      final loaded = await store.load('dart_ecs');
      expect(loaded!.patternsContent, contains('iso queues'));
    });
  });
}
