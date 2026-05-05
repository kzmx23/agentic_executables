import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('CanonicalLicense', () {
    test('toJson + fromMap round-trip', () {
      const lic = CanonicalLicense(
        spdx: 'CC-BY-4.0',
        url: 'https://creativecommons.org/licenses/by/4.0/',
      );
      final j = lic.toJson();
      expect(j['spdx'], 'CC-BY-4.0');
      final back = CanonicalLicense.fromMap(j);
      expect(back.spdx, lic.spdx);
      expect(back.url, lic.url);
    });
  });

  group('CanonicalAuthor', () {
    test('role required', () {
      const a =
          CanonicalAuthor(name: 'A', role: CanonicalAuthorRole.originalAuthor);
      expect(a.toJson()['role'], 'original_author');
    });
  });

  group('CanonicalSource', () {
    test('all source kinds round-trip', () {
      for (final kind in CanonicalSourceKind.values) {
        final s = CanonicalSource(kind: kind, title: 'T', url: 'https://x');
        final back = CanonicalSource.fromMap(s.toJson());
        expect(back.kind, kind);
      }
    });
  });

  group('CanonicalMeta', () {
    test('toYamlString + fromMap round-trip', () {
      final meta = CanonicalMeta(
        concept: 'ecs',
        version: 1,
        title: 'Entity-Component-System',
        license: const CanonicalLicense(
          spdx: 'CC-BY-4.0',
          url: 'https://creativecommons.org/licenses/by/4.0/',
        ),
        authors: const [
          CanonicalAuthor(
              name: 'A. Malofeev', role: CanonicalAuthorRole.originalAuthor),
        ],
        sources: const [
          CanonicalSource(
            kind: CanonicalSourceKind.book,
            title: 'DOD Book',
            url: 'https://www.dataorienteddesign.com/dodbook/',
          ),
        ],
        provenance: CanonicalProvenance(
          authored: CanonicalAuthored.hand,
          authoredAt: DateTime.utc(2026, 4, 17),
        ),
      );

      final yamlStr = meta.toYamlString();
      final loaded = loadYaml(yamlStr) as Map;
      final back = CanonicalMeta.fromMap(loaded);
      expect(back.concept, 'ecs');
      expect(back.version, 1);
      expect(back.license.spdx, 'CC-BY-4.0');
      expect(back.authors.first.name, 'A. Malofeev');
      expect(back.sources.first.kind, CanonicalSourceKind.book);
      expect(back.provenance.authored, CanonicalAuthored.hand);
    });

    test('fromMap requires license', () {
      expect(
        () => CanonicalMeta.fromMap({
          'schema': 'ae.canonical.meta.v1',
          'concept': 'x',
          'version': 1,
        }),
        throwsArgumentError,
      );
    });
  });

  group('CanonicalPack', () {
    test('holds meta + content', () {
      final meta = CanonicalMeta(
        concept: 'ecs',
        version: 1,
        title: 'ECS',
        license:
            const CanonicalLicense(spdx: 'CC-BY-4.0', url: 'https://c.org/b/4'),
        authors: const [],
        sources: const [
          CanonicalSource(
              kind: CanonicalSourceKind.code,
              title: 'Bevy',
              url: 'https://github.com/bevyengine/bevy'),
        ],
        provenance: CanonicalProvenance(
          authored: CanonicalAuthored.hand,
          authoredAt: DateTime.now(),
        ),
      );
      final pack = CanonicalPack(
        meta: meta,
        indexContent: '# ECS\n\nDistilled.',
        matrix: CanonicalMatrix(
          concept: 'ecs',
          version: 1,
          columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
          features: const [],
        ),
      );
      expect(pack.indexContent, contains('Distilled'));
      expect(pack.matrix.concept, 'ecs');
    });
  });
}
