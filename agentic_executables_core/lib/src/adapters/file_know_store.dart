import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/ae_core_config.dart';
import '../models/know.dart';
import '../ports/know_store.dart';

class FileKnowledgeStore implements KnowledgeStore {
  const FileKnowledgeStore(this.basePath);

  final String basePath;

  String _packDir(final String name) => p.join(basePath, name);

  @override
  Future<List<String>> save(final String name, final KnowPack pack) async {
    final dir = Directory(_packDir(name));
    await dir.create(recursive: true);
    final written = <String>[];

    final indexFile = File(p.join(dir.path, AeCoreConfig.knowIndexFile));
    await indexFile.writeAsString(pack.indexContent);
    written.add(indexFile.path);

    final metaFile = File(p.join(dir.path, AeCoreConfig.knowMetaFile));
    await metaFile.writeAsString(pack.meta.toYamlString());
    written.add(metaFile.path);

    if (pack.patternsContent != null) {
      final patternsFile = File(
        p.join(dir.path, AeCoreConfig.knowPatternsFile),
      );
      await patternsFile.writeAsString(pack.patternsContent!);
      written.add(patternsFile.path);
    }

    return written;
  }

  @override
  Future<KnowPack?> load(final String name) async {
    final indexFile = File(
      p.join(_packDir(name), AeCoreConfig.knowIndexFile),
    );
    if (!await indexFile.exists()) return null;

    final indexContent = await indexFile.readAsString();

    final metaFile = File(
      p.join(_packDir(name), AeCoreConfig.knowMetaFile),
    );
    final metaRaw = await metaFile.readAsString();
    final metaYaml = loadYaml(metaRaw);
    final meta = KnowMeta.fromMap(metaYaml as Map);

    final patternsFile = File(
      p.join(_packDir(name), AeCoreConfig.knowPatternsFile),
    );
    final patternsContent =
        await patternsFile.exists() ? await patternsFile.readAsString() : null;

    return KnowPack(
      meta: meta,
      indexContent: indexContent,
      patternsContent: patternsContent,
    );
  }

  @override
  Future<List<KnowMeta>> list() async {
    final dir = Directory(basePath);
    if (!await dir.exists()) return const [];

    final metas = <KnowMeta>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final metaFile = File(
        p.join(entity.path, AeCoreConfig.knowMetaFile),
      );
      if (!await metaFile.exists()) continue;

      final raw = await metaFile.readAsString();
      final yaml = loadYaml(raw);
      if (yaml is Map) metas.add(KnowMeta.fromMap(yaml));
    }
    return metas;
  }

  @override
  Future<bool> exists(final String name) async {
    final indexFile = File(
      p.join(_packDir(name), AeCoreConfig.knowIndexFile),
    );
    return indexFile.exists();
  }

  @override
  Future<bool> remove(final String name) async {
    final dir = Directory(_packDir(name));
    if (!await dir.exists()) return false;
    await dir.delete(recursive: true);
    return true;
  }
}
