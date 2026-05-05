import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('RustHeuristicExtractor', () {
    late Directory fixtureDir;
    late RustHeuristicExtractor extractor;

    setUp(() {
      fixtureDir = Directory(
        p.join(Directory.current.path, 'test', 'fixtures', 'rust_crate_min'),
      );
      extractor = const RustHeuristicExtractor();
    });

    test('languageId is rust', () {
      expect(extractor.languageId, 'rust');
    });

    test('canHandle returns true for a directory containing Cargo.toml',
        () async {
      expect(await extractor.canHandle(fixtureDir), isTrue);
    });

    test('canHandle returns false for unrelated directories', () async {
      final tmp = await Directory.systemTemp.createTemp('not_rust_');
      try {
        expect(await extractor.canHandle(tmp), isFalse);
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('extract returns artifact with package name + extractor id', () async {
      final art = await extractor.extract(fixtureDir);
      expect(art.languageId, 'rust');
      expect(art.name, 'ecsly_rust');
      expect(art.meta.extractor, 'rust_v1');
      expect(art.meta.distill.engine, 'heuristic');
    });

    test('extract hashes src files', () async {
      final art = await extractor.extract(fixtureDir);
      final paths = art.meta.source.files.map((final f) => f.path).toList();
      expect(paths, contains('src/lib.rs'));
      for (final f in art.meta.source.files) {
        expect(f.sha256.length, 64);
      }
    });

    test('extract detects Apache-2.0 license', () async {
      final art = await extractor.extract(fixtureDir);
      expect(art.meta.license?.spdx, 'Apache-2.0');
    });

    test('extract index.md surfaces public symbols and feature flags',
        () async {
      final art = await extractor.extract(fixtureDir);
      expect(art.indexMd, contains('# ecsly_rust'));
      // public items
      expect(art.indexMd, contains('Entity'));
      expect(art.indexMd, contains('EntityManager'));
      expect(art.indexMd, contains('System'));
      expect(art.indexMd, contains('EntityError'));
      // private not present
      expect(art.indexMd, isNot(contains('_reset')));
      // feature flags
      expect(art.indexMd, contains('default'));
      expect(art.indexMd, contains('std'));
      expect(art.indexMd, contains('no_std'));
      // deps
      expect(art.indexMd, contains('serde'));
    });

    test('extract harvests doc-comment headlines for public items', () async {
      final art = await extractor.extract(fixtureDir);
      expect(art.indexMd, contains('opaque, non-reusable entity handle'));
      expect(art.indexMd, contains('Marker trait for systems'));
    });
  });
}
