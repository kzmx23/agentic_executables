import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('KnowCanonicalId', () {
    test('sourceId is stable for same source and format', () {
      final source = KnowSource(
        type: KnowSourceType.url,
        url: 'https://example.com/doc.pdf',
        format: KnowFormat.pdf,
      );
      final a = KnowCanonicalId.sourceId(
        source,
        KnowFormat.pdf,
        KnowDistillEngine.passthrough,
      );
      final b = KnowCanonicalId.sourceId(
        source,
        KnowFormat.pdf,
        KnowDistillEngine.passthrough,
      );
      expect(a, equals(b));
      expect(a.length, 16);
    });

    test('sourceId differs for different url', () {
      final s1 = KnowSource(
        type: KnowSourceType.url,
        url: 'https://a.com/x.pdf',
        format: KnowFormat.pdf,
      );
      final s2 = KnowSource(
        type: KnowSourceType.url,
        url: 'https://b.com/x.pdf',
        format: KnowFormat.pdf,
      );
      final id1 = KnowCanonicalId.sourceId(
        s1,
        KnowFormat.pdf,
        KnowDistillEngine.passthrough,
      );
      final id2 = KnowCanonicalId.sourceId(
        s2,
        KnowFormat.pdf,
        KnowDistillEngine.passthrough,
      );
      expect(id1, isNot(equals(id2)));
    });

    test('contentSha256 is deterministic', () {
      const content = 'Hello world';
      expect(
        KnowCanonicalId.contentSha256(content),
        equals(KnowCanonicalId.contentSha256(content)),
      );
      expect(KnowCanonicalId.contentSha256(content).length, 64);
    });
  });

  group('KnowOnConflict', () {
    test('fromString accepts all values', () {
      expect(KnowOnConflict.fromString('reuse'), KnowOnConflict.reuse);
      expect(KnowOnConflict.fromString('update'), KnowOnConflict.update);
      expect(KnowOnConflict.fromString('fail'), KnowOnConflict.fail);
      expect(KnowOnConflict.fromString('new_version'), KnowOnConflict.newVersion);
    });
    test('fromString throws for invalid', () {
      expect(
        () => KnowOnConflict.fromString('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('FileKnowledgeStore canonical + alias', () {
    late Directory tempDir;
    late FileKnowledgeStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ae_know_canonical_');
      store = FileKnowledgeStore(tempDir.path);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('saveCanonical then attachAlias then load by name', () async {
      final sourceId = 'a1b2c3d4e5f67890';
      final contentSha = KnowCanonicalId.contentSha256('index content');
      final meta = KnowMeta(
        name: 'mypack',
        source: const KnowSource(type: KnowSourceType.url, url: 'https://x.com/a.pdf'),
        distillEngine: KnowDistillEngine.passthrough,
        fetchedAt: DateTime.now(),
        sourceId: sourceId,
        contentSha: contentSha,
      );
      final pack = KnowPack(
        meta: meta,
        indexContent: 'index content',
        patternsContent: null,
      );
      await store.saveCanonical(
        sourceId,
        contentSha,
        pack,
        'url',
        'pdf',
      );
      await store.attachAlias('mypack', sourceId, contentSha: contentSha);

      final ref = await store.findBySourceId(sourceId);
      expect(ref, isNotNull);
      expect(ref!.sourceId, sourceId);
      expect(ref.contentSha, contentSha);
      expect(ref.aliases, contains('mypack'));

      final loaded = await store.load('mypack');
      expect(loaded, isNotNull);
      expect(loaded!.indexContent, 'index content');
    });

    test('resolveAlias returns ref for attached alias', () async {
      final sourceId = 'id123';
      final contentSha = 'sha456';
      final meta = KnowMeta(
        name: 'alias_pack',
        source: const KnowSource(type: KnowSourceType.url, url: 'https://y.com'),
        distillEngine: KnowDistillEngine.passthrough,
        fetchedAt: DateTime.now(),
      );
      final pack = KnowPack(meta: meta, indexContent: 'x', patternsContent: null);
      await store.saveCanonical(sourceId, contentSha, pack, 'url', 'markdown');
      await store.attachAlias('alias_pack', sourceId, contentSha: contentSha);

      final ref = await store.resolveAlias('alias_pack');
      expect(ref, isNotNull);
      expect(ref!.sourceId, sourceId);
      expect(ref.canonicalPath, 'url/markdown/$sourceId');
    });
  });

  group('FileKnowledgeStore migration', () {
    late Directory tempDir;
    late FileKnowledgeStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ae_know_migrate_');
      store = FileKnowledgeStore(tempDir.path);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('migrate creates canonical and aliases from legacy dirs', () async {
      final meta = KnowMeta(
        name: 'legacy_one',
        source: const KnowSource(
          type: KnowSourceType.url,
          url: 'https://example.com/spec.pdf',
          format: KnowFormat.pdf,
        ),
        distillEngine: KnowDistillEngine.passthrough,
        fetchedAt: DateTime.now(),
      );
      final pack = KnowPack(
        meta: meta,
        indexContent: 'legacy index content',
        patternsContent: null,
      );
      await store.save('legacy_one', pack);

      final report = await store.migrate(dryRun: false);
      expect(report.aliasesCreated.length, 1);
      expect(report.aliasesCreated.first.name, 'legacy_one');
      expect(report.removedLegacy, contains('legacy_one'));

      final loaded = await store.load('legacy_one');
      expect(loaded, isNotNull);
      expect(loaded!.indexContent, 'legacy index content');
    });

    test('migrate dry-run does not write', () async {
      final meta = KnowMeta(
        name: 'dry_legacy',
        source: const KnowSource(
          type: KnowSourceType.url,
          url: 'https://dry.com/doc.pdf',
          format: KnowFormat.pdf,
        ),
        distillEngine: KnowDistillEngine.passthrough,
        fetchedAt: DateTime.now(),
      );
      await store.save('dry_legacy', KnowPack(meta: meta, indexContent: 'x', patternsContent: null));

      final report = await store.migrate(dryRun: true);
      expect(report.aliasesCreated.length, 1);
      expect(report.removedLegacy, isEmpty);

      final legacyDir = Directory(p.join(tempDir.path, 'dry_legacy'));
      expect(await legacyDir.exists(), isTrue);
    });

    test('migrate idempotency: second run no legacy to migrate', () async {
      final meta = KnowMeta(
        name: 'idem',
        source: const KnowSource(
          type: KnowSourceType.url,
          url: 'https://idem.com/a.pdf',
          format: KnowFormat.pdf,
        ),
        distillEngine: KnowDistillEngine.passthrough,
        fetchedAt: DateTime.now(),
      );
      await store.save('idem', KnowPack(meta: meta, indexContent: 'y', patternsContent: null));
      await store.migrate(dryRun: false);

      final report2 = await store.migrate(dryRun: false);
      expect(report2.aliasesCreated, isEmpty);
      expect(report2.merged, isEmpty);
    });
  });
}
