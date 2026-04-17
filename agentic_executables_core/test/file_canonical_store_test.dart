import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

CanonicalPack _samplePack(final String concept, {final int version = 1}) {
  final meta = CanonicalMeta(
    concept: concept,
    version: version,
    title: 'T',
    license: const CanonicalLicense(spdx: 'CC-BY-4.0', url: 'https://c.org/b/4'),
    authors: const [
      CanonicalAuthor(name: 'A', role: CanonicalAuthorRole.originalAuthor),
    ],
    sources: const [
      CanonicalSource(
        kind: CanonicalSourceKind.code,
        title: 'Bevy',
        url: 'https://github.com/bevyengine/bevy',
      ),
    ],
    provenance: CanonicalProvenance(
      authored: CanonicalAuthored.hand,
      authoredAt: DateTime.utc(2026, 4, 17),
    ),
  );
  return CanonicalPack(
    meta: meta,
    indexContent: '# $concept\n\nDistilled.',
    matrix: CanonicalMatrix(
      concept: concept,
      version: version,
      columnSchema: const [
        CanonicalColumn(id: 'spec', type: 'text'),
      ],
      features: [
        CanonicalFeature(
          id: FeatureId.parse('entity.create'),
          cells: const {'spec': 'Make one.'},
        ),
      ],
    ),
  );
}

void main() {
  group('FileCanonicalStore', () {
    late Directory tempDir;
    late FileCanonicalStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ae_canonical_store_');
      store = FileCanonicalStore(tempDir.path);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('save then exists then load (live)', () async {
      final pack = _samplePack('ecs');
      final written = await store.save('ecs', pack);
      expect(written.length, greaterThanOrEqualTo(3));
      expect(await store.exists('ecs'), isTrue);

      final loaded = await store.load('ecs');
      expect(loaded, isNotNull);
      expect(loaded!.meta.concept, 'ecs');
      expect(loaded.indexContent, contains('Distilled'));
      expect(loaded.matrix.features.first.id.toString(), 'entity.create');
    });

    test('save with nested concept id (gltf/core)', () async {
      final pack = _samplePack('gltf/core');
      await store.save('gltf/core', pack);
      expect(await store.exists('gltf/core'), isTrue);

      // Files exist on disk under canonical/gltf/core/
      final metaPath = p.join(tempDir.path, 'canonical', 'gltf', 'core', 'meta.yaml');
      expect(await File(metaPath).exists(), isTrue);

      final loaded = await store.load('gltf/core');
      expect(loaded, isNotNull);
      expect(loaded!.meta.concept, 'gltf/core');
    });

    test('list returns saved concept ids (including nested)', () async {
      await store.save('ecs', _samplePack('ecs'));
      await store.save('gltf/core', _samplePack('gltf/core'));
      await store.save('gltf/extensions/khr_lights_punctual',
          _samplePack('gltf/extensions/khr_lights_punctual'));

      final all = await store.list();
      expect(all, containsAll(['ecs', 'gltf/core', 'gltf/extensions/khr_lights_punctual']));
    });

    test('snapshot moves live to v1/ and returns snapshot path', () async {
      await store.save('ecs', _samplePack('ecs'));
      final snapPath = await store.snapshot('ecs');
      expect(snapPath, contains('v1'));
      expect(await Directory(snapPath).exists(), isTrue);
      // Live files removed from concept root after snapshot
      expect(
        await File(p.join(tempDir.path, 'canonical', 'ecs', 'meta.yaml'))
            .exists(),
        isFalse,
      );
    });

    test('load with lockedVersion reads snapshot', () async {
      await store.save('ecs', _samplePack('ecs', version: 1));
      await store.snapshot('ecs');
      // After snapshot, save a new live (would-be v2)
      await store.save('ecs', _samplePack('ecs', version: 2));

      final v1 = await store.load('ecs', lockedVersion: 1);
      expect(v1, isNotNull);
      expect(v1!.meta.version, 1);

      final live = await store.load('ecs');
      expect(live!.meta.version, 2);
    });

    test('remove deletes live + snapshots', () async {
      await store.save('ecs', _samplePack('ecs'));
      await store.snapshot('ecs');
      await store.save('ecs', _samplePack('ecs', version: 2));

      final removed = await store.remove('ecs');
      expect(removed, isTrue);
      expect(await store.exists('ecs'), isFalse);
      expect(
        await Directory(p.join(tempDir.path, 'canonical', 'ecs')).exists(),
        isFalse,
      );
    });

    test('load returns null for unknown concept', () async {
      expect(await store.load('does_not_exist'), isNull);
    });
  });
}
