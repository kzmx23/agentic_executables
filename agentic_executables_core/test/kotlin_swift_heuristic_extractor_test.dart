import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('KotlinSwiftHeuristicExtractor', () {
    late Directory fixtureDir;
    late KotlinSwiftHeuristicExtractor extractor;

    setUp(() {
      fixtureDir = Directory(
        p.join(Directory.current.path, 'test', 'fixtures', 'kotlin_pkg_min'),
      );
      extractor = const KotlinSwiftHeuristicExtractor();
    });

    test('languageId is kotlin_swift', () {
      expect(extractor.languageId, 'kotlin_swift');
    });

    test('canHandle returns true for Package.swift', () async {
      expect(await extractor.canHandle(fixtureDir), isTrue);
    });

    test('canHandle returns true for build.gradle.kts', () async {
      final tmp = await Directory.systemTemp.createTemp('gradle_');
      try {
        await File(p.join(tmp.path, 'build.gradle.kts')).writeAsString('// kts');
        expect(await extractor.canHandle(tmp), isTrue);
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('canHandle returns false for unrelated directories', () async {
      final tmp = await Directory.systemTemp.createTemp('not_kotlin_swift_');
      try {
        expect(await extractor.canHandle(tmp), isFalse);
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('extract reads Package.swift name and lists Swift files', () async {
      final art = await extractor.extract(fixtureDir);
      expect(art.languageId, 'kotlin_swift');
      expect(art.name, 'Foo');
      expect(art.meta.extractor, 'kotlin_swift_v1');
      final paths = art.meta.source.files.map((final f) => f.path).toList();
      expect(paths, contains('Sources/Foo/Foo.swift'));
    });

    test('extract index.md surfaces public type counts', () async {
      final art = await extractor.extract(fixtureDir);
      expect(art.indexMd, contains('# Foo'));
      // Public counts (struct + class + protocol = 3); private struct excluded.
      expect(art.indexMd, contains('public types'));
      expect(art.indexMd, contains('Entity'));
      expect(art.indexMd, contains('EntityManager'));
      expect(art.indexMd, contains('System'));
      expect(art.indexMd, isNot(contains('InternalCounter')));
    });
  });
}
