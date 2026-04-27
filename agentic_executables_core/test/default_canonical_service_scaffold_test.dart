import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

ArtifactPack _artifactWithPublicApi(
  final String name, {
  required final List<List<String>> symbols,
}) {
  // symbols: list of [name, kind, headline, file]; headline/file optional.
  final buf = StringBuffer()
    ..writeln('# $name')
    ..writeln()
    ..writeln('## Public API')
    ..writeln();
  for (final s in symbols) {
    final symName = s[0];
    final kind = s[1];
    final head = s.length > 2 ? s[2] : '';
    final file = s.length > 3 ? s[3] : 'lib/x.dart';
    if (head.isEmpty) {
      buf.writeln('- `$symName` ($kind) [$file]');
    } else {
      buf.writeln('- `$symName` ($kind) — $head [$file]');
    }
  }
  return ArtifactPack(
    name: name,
    meta: ArtifactMeta(
      kind: ArtifactKind.local,
      title: name,
      source: ArtifactSource(
        type: ArtifactSourceType.path,
        path: 'src/$name',
        files: const [
          ArtifactSourceFile(path: 'lib/x.dart', sha256: 'h'),
        ],
      ),
      scannedAt: DateTime.utc(2026, 4, 17),
      referencesCanonical: const [],
      extractor: 'dart_v1',
      distill: const ArtifactDistill(engine: 'heuristic'),
    ),
    indexContent: buf.toString(),
    matrix: const ArtifactMatrix(columnSchema: [], features: []),
  );
}

void main() {
  group('DefaultCanonicalService.scaffoldFromArtifact', () {
    late Directory tempHub;
    late FileCanonicalStore canStore;
    late FileArtifactStore artStore;
    late DefaultCanonicalService svc;

    setUp(() async {
      tempHub = await Directory.systemTemp.createTemp('ae_csvc_scaffold_');
      canStore = FileCanonicalStore(tempHub.path);
      artStore = FileArtifactStore(tempHub.path);
      svc = DefaultCanonicalService(store: canStore);
    });

    tearDown(() async {
      await tempHub.delete(recursive: true);
    });

    test('seeds one feature row per public symbol', () async {
      await artStore.save(_artifactWithPublicApi('agentic_executables_cli',
          symbols: [
            ['AeCli', 'class', 'Public CLI entry', 'lib/src/cli.dart'],
            ['runCli', 'function', '', 'lib/src/cli.dart'],
            ['kAeVersion', 'constant', '', 'lib/src/version.dart'],
          ]));

      final pack = await svc.scaffoldFromArtifact(
        'ae/cli',
        title: 'AE CLI',
        artifactNames: ['agentic_executables_cli'],
        artifactStore: artStore,
      );

      expect(pack.meta.concept, 'ae/cli');
      expect(pack.meta.title, 'AE CLI');
      expect(pack.meta.provenance.authored, CanonicalAuthored.scaffolded);
      expect(pack.matrix.features.length, 3);
      // Stable feature ids namespaced by artifact name.
      final ids = pack.matrix.features.map((final f) => f.id.toString()).toSet();
      expect(ids, containsAll([
        'agentic_executables_cli.ae_cli',
        'agentic_executables_cli.run_cli',
        'agentic_executables_cli.k_ae_version',
      ]));
      // Stub spec carries kind; invariant is empty.
      final aeCli = pack.matrix.features.firstWhere(
        (final f) => f.id.toString() == 'agentic_executables_cli.ae_cli',
      );
      expect(aeCli.cells['spec'], contains('class'));
      expect(aeCli.cells['invariant'], '');
      expect(await canStore.exists('ae/cli'), isTrue);
    });

    test('unions across multiple artifacts; first occurrence wins on dup id',
        () async {
      await artStore.save(_artifactWithPublicApi('pkg_a', symbols: [
        ['Foo', 'class'],
        ['Bar', 'class'],
      ]));
      await artStore.save(_artifactWithPublicApi('pkg_b', symbols: [
        ['Bar', 'class'], // resolves to pkg_b.bar — different id, kept
        ['Baz', 'class'],
      ]));
      final pack = await svc.scaffoldFromArtifact(
        'union',
        title: 'Union',
        artifactNames: ['pkg_a', 'pkg_b'],
        artifactStore: artStore,
      );
      final ids = pack.matrix.features
          .map((final f) => f.id.toString())
          .toList()
        ..sort();
      expect(ids, ['pkg_a.bar', 'pkg_a.foo', 'pkg_b.bar', 'pkg_b.baz']);
    });

    test('re-running without overwrite throws (canonical_exists)', () async {
      await artStore.save(_artifactWithPublicApi('pkg_a', symbols: [
        ['Foo', 'class'],
      ]));
      await svc.scaffoldFromArtifact(
        'concept',
        title: 'C',
        artifactNames: ['pkg_a'],
        artifactStore: artStore,
      );
      await expectLater(
        svc.scaffoldFromArtifact(
          'concept',
          title: 'C',
          artifactNames: ['pkg_a'],
          artifactStore: artStore,
        ),
        throwsA(predicate((final e) =>
            e is StateError && e.message.contains('canonical_exists'))),
      );
    });

    test('re-running with overwrite produces a fresh pack', () async {
      await artStore.save(_artifactWithPublicApi('pkg_a', symbols: [
        ['Foo', 'class'],
      ]));
      await svc.scaffoldFromArtifact(
        'concept',
        title: 'C',
        artifactNames: ['pkg_a'],
        artifactStore: artStore,
      );
      // Replace the artifact's symbol set.
      await artStore.save(_artifactWithPublicApi('pkg_a', symbols: [
        ['Bar', 'class'],
        ['Qux', 'function'],
      ]));
      final pack = await svc.scaffoldFromArtifact(
        'concept',
        title: 'C',
        artifactNames: ['pkg_a'],
        artifactStore: artStore,
        overwrite: true,
      );
      final ids =
          pack.matrix.features.map((final f) => f.id.toString()).toSet();
      expect(ids, {'pkg_a.bar', 'pkg_a.qux'});
    });

    test('artifact with no Public API section yields empty matrix', () async {
      final empty = ArtifactPack(
        name: 'empty_pkg',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'empty',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: 'src/empty',
          ),
          scannedAt: DateTime.utc(2026, 4, 17),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# empty\n\n## Overview\n\nNo public API.\n',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      );
      await artStore.save(empty);
      final pack = await svc.scaffoldFromArtifact(
        'empty_concept',
        title: 'E',
        artifactNames: ['empty_pkg'],
        artifactStore: artStore,
      );
      expect(pack.matrix.features, isEmpty);
      expect(pack.meta.provenance.authored, CanonicalAuthored.scaffolded);
    });

    test('round-trips authored=scaffolded through meta.yaml', () async {
      await artStore.save(_artifactWithPublicApi('pkg_a', symbols: [
        ['Foo', 'class'],
      ]));
      await svc.scaffoldFromArtifact(
        'rt',
        title: 'RT',
        artifactNames: ['pkg_a'],
        artifactStore: artStore,
      );
      final reloaded = await canStore.load('rt');
      expect(reloaded!.meta.provenance.authored, CanonicalAuthored.scaffolded);
    });

    test('missing artifact name raises artifact_not_found', () async {
      await expectLater(
        svc.scaffoldFromArtifact(
          'whatever',
          title: 'X',
          artifactNames: ['does_not_exist'],
          artifactStore: artStore,
        ),
        throwsA(predicate((final e) =>
            e is ArgumentError &&
            e.message.toString().contains('artifact_not_found'))),
      );
    });
  });
}
