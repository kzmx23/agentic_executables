import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('DartHeuristicExtractor', () {
    late Directory fixtureDir;
    late DartHeuristicExtractor extractor;

    setUp(() {
      fixtureDir = Directory(
        p.join(Directory.current.path, 'test', 'fixtures', 'dart_pkg_min'),
      );
      extractor = const DartHeuristicExtractor();
    });

    test('languageId is dart', () {
      expect(extractor.languageId, 'dart');
    });

    test('canHandle returns true for a directory containing pubspec.yaml',
        () async {
      expect(await extractor.canHandle(fixtureDir), isTrue);
    });

    test('canHandle returns false for unrelated directories', () async {
      final tmp = await Directory.systemTemp.createTemp('not_dart_');
      try {
        expect(await extractor.canHandle(tmp), isFalse);
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('extract returns an artifact with the package name and language',
        () async {
      final art = await extractor.extract(fixtureDir);
      expect(art.languageId, 'dart');
      expect(art.name, 'ecsly');
      expect(art.meta.kind, ArtifactKind.local);
      expect(art.meta.extractor, 'dart_v1');
      expect(art.meta.distill.engine, 'heuristic');
      expect(art.meta.title, 'ecsly');
    });

    test('extract hashes every .dart file under lib/ with sha256', () async {
      final art = await extractor.extract(fixtureDir);
      final paths = art.meta.source.files.map((final f) => f.path).toList();
      expect(
          paths,
          containsAll([
            'lib/ecsly.dart',
            'lib/src/entities.dart',
            'lib/src/systems.dart',
          ]));
      // sha256 hex is 64 chars
      for (final f in art.meta.source.files) {
        expect(f.sha256.length, 64, reason: 'expected sha256 hex');
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(f.sha256), isTrue);
      }
    });

    test('extract detects MIT license from LICENSE file', () async {
      final art = await extractor.extract(fixtureDir);
      expect(art.meta.license?.spdx, 'MIT');
      expect(art.meta.license?.detectedFrom, 'license_file');
    });

    test(
        'extract index.md includes title, README excerpt, public symbols, deps',
        () async {
      final art = await extractor.extract(fixtureDir);
      // title
      expect(art.indexMd, contains('# ecsly'));
      // README excerpt (first paragraph after H1)
      expect(art.indexMd, contains('A tiny Entity-Component-System'));
      // public symbols
      expect(art.indexMd, contains('Entity'));
      expect(art.indexMd, contains('EntityManager'));
      expect(art.indexMd, contains('System'));
      expect(art.indexMd, contains('NoopSystem'));
      expect(art.indexMd, contains('TickFn'));
      // private symbols are NOT listed
      expect(art.indexMd, isNot(contains('_reset')));
      // dependency list
      expect(art.indexMd, contains('meta'));
    });

    test('extract harvests doc-comment headlines for public symbols', () async {
      final art = await extractor.extract(fixtureDir);
      // From entities.dart — the doc comment above Entity
      expect(art.indexMd, contains('opaque, non-reusable entity handle'));
      // From systems.dart — the doc comment above System
      expect(art.indexMd, contains('Marker for systems that run each tick'));
    });

    test('extract reports source path relative to extract root', () async {
      final art = await extractor.extract(fixtureDir);
      // The extractor records source.path as the directory it scanned.
      expect(art.meta.source.path, isNotNull);
      expect(art.meta.source.type, ArtifactSourceType.path);
    });
  });
}
