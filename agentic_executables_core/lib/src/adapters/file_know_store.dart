import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/ae_core_config.dart';
import '../models/know.dart';
import '../models/know_matrix.dart';
import '../ports/know_store.dart';

class FileKnowledgeStore implements KnowledgeStore {
  const FileKnowledgeStore(this.basePath);

  final String basePath;

  static const _canonicalTypes = ['url', 'repo', 'local'];

  String _packDir(final String name) => p.join(basePath, name);

  String _aliasFile(final String name) =>
      p.join(basePath, AeCoreConfig.knowAliasesDir, '$name.yaml');

  String _bySourceFile(final String sourceId) =>
      p.join(basePath, AeCoreConfig.knowBySourceDir, '$sourceId.yaml');

  String _canonicalDir(final String type, final String format, final String sourceId) =>
      p.join(basePath, type, format, sourceId);

  String _versionDir(final String type, final String format, final String sourceId, final String contentSha) =>
      p.join(_canonicalDir(type, format, sourceId), AeCoreConfig.knowVersionsDir, contentSha);

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

    if (pack.matrixYamlContent != null) {
      final y = File(p.join(dir.path, AeCoreConfig.knowMatrixFile));
      await y.writeAsString(pack.matrixYamlContent!);
      written.add(y.path);
      final rendered =
          KnowFeatureMatrix.parseYamlString(pack.matrixYamlContent!);
      final md = File(p.join(dir.path, AeCoreConfig.knowMatrixMarkdownFile));
      await md.writeAsString(rendered.renderMarkdown());
      written.add(md.path);
    }

    return written;
  }

  @override
  Future<KnowPack?> load(final String name) async {
    final aliasRef = await resolveAlias(name);
    if (aliasRef != null) {
      return _loadCanonical(aliasRef.canonicalPath, aliasRef.contentSha);
    }
    return _loadLegacy(name);
  }

  Future<KnowPack?> _loadLegacy(final String name) async {
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

    final matrixFile = File(p.join(_packDir(name), AeCoreConfig.knowMatrixFile));
    final matrixYaml = await matrixFile.exists()
        ? await matrixFile.readAsString()
        : null;

    return KnowPack(
      meta: meta,
      indexContent: indexContent,
      patternsContent: patternsContent,
      matrixYamlContent: matrixYaml,
    );
  }

  Future<KnowPack?> _loadCanonical(final String canonicalPath, final String? contentSha) async {
    final dir = p.join(basePath, canonicalPath);
    final metaPath = p.join(dir, AeCoreConfig.knowMetaFile);
    final metaFile = File(metaPath);
    if (!await metaFile.exists()) return null;

    final metaRaw = await metaFile.readAsString();
    final metaYaml = loadYaml(metaRaw) as Map;
    final currentSha = metaYaml['current_content_sha']?.toString();
    final versionSha = contentSha ?? currentSha;
    if (versionSha == null) return null;

    final versionDir = p.join(dir, AeCoreConfig.knowVersionsDir, versionSha);
    final indexFile = File(p.join(versionDir, AeCoreConfig.knowIndexFile));
    if (!await indexFile.exists()) return null;

    final indexContent = await indexFile.readAsString();
    final meta = KnowMeta.fromMap(metaYaml);
    final patternsFile = File(p.join(versionDir, AeCoreConfig.knowPatternsFile));
    final patternsContent =
        await patternsFile.exists() ? await patternsFile.readAsString() : null;

    final matrixFile = File(p.join(versionDir, AeCoreConfig.knowMatrixFile));
    final matrixYaml =
        await matrixFile.exists() ? await matrixFile.readAsString() : null;

    return KnowPack(
      meta: meta,
      indexContent: indexContent,
      patternsContent: patternsContent,
      matrixYamlContent: matrixYaml,
    );
  }

  @override
  Future<List<KnowMeta>> list() async {
    final metas = <KnowMeta>[];
    final dir = Directory(basePath);
    if (!await dir.exists()) return const [];

    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('_')) continue;
      if (_canonicalTypes.contains(name)) {
        await for (final formatEntity in entity.list()) {
          if (formatEntity is! Directory) continue;
          await for (final sourceEntity in formatEntity.list()) {
            if (sourceEntity is! Directory) continue;
            final metaFile = File(
              p.join(sourceEntity.path, AeCoreConfig.knowMetaFile),
            );
            if (!await metaFile.exists()) continue;
            final raw = await metaFile.readAsString();
            final yaml = loadYaml(raw);
            if (yaml is Map) metas.add(KnowMeta.fromMap(yaml));
          }
        }
        continue;
      }
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
    final aliasFile = File(_aliasFile(name));
    if (await aliasFile.exists()) return true;
    final indexFile = File(
      p.join(_packDir(name), AeCoreConfig.knowIndexFile),
    );
    return indexFile.exists();
  }

  @override
  Future<bool> remove(final String name) async {
    final aliasFile = File(_aliasFile(name));
    if (await aliasFile.exists()) {
      final yaml = loadYaml(await aliasFile.readAsString()) as Map?;
      final sourceId = yaml?['source_id']?.toString();
      final canonicalPath = yaml?['canonical_path']?.toString();
      await aliasFile.delete();
      if (sourceId != null && canonicalPath != null) {
        await _removeAliasFromCanonical(canonicalPath, name);
      }
      return true;
    }
    final dir = Directory(_packDir(name));
    if (!await dir.exists()) return false;
    await dir.delete(recursive: true);
    return true;
  }

  Future<void> _removeAliasFromCanonical(final String canonicalPath, final String aliasName) async {
    final aliasesPath = p.join(basePath, canonicalPath, AeCoreConfig.knowAliasesFile);
    final file = File(aliasesPath);
    if (!await file.exists()) return;
    final raw = await file.readAsString();
    final yaml = loadYaml(raw);
    if (yaml is! Map) return;
    final list = yaml['aliases'];
    if (list is! List) return;
    final newList = list.where((e) => e.toString() != aliasName).toList();
    if (newList.isEmpty) {
      await file.delete();
      return;
    }
    final buffer = StringBuffer()..writeln('aliases:');
    for (final a in newList) {
      buffer.writeln('  - $a');
    }
    await file.writeAsString(buffer.toString());
  }

  @override
  Future<KnowCanonicalRef?> findBySourceId(final String sourceId) async {
    final bySourceFile = File(_bySourceFile(sourceId));
    if (!await bySourceFile.exists()) return null;
    final raw = await bySourceFile.readAsString();
    final yaml = loadYaml(raw) as Map?;
    final type = yaml?['type']?.toString();
    final format = yaml?['format']?.toString();
    if (type == null || format == null) return null;
    final canonicalPath = '$type/$format/$sourceId';
    final metaPath = p.join(basePath, canonicalPath, AeCoreConfig.knowMetaFile);
    final metaFile = File(metaPath);
    if (!await metaFile.exists()) return null;
    final metaRaw = await metaFile.readAsString();
    final metaYaml = loadYaml(metaRaw) as Map;
    final contentSha = metaYaml['current_content_sha']?.toString() ?? '';
    final aliases = <String>[];
    final aliasesPath = p.join(basePath, canonicalPath, AeCoreConfig.knowAliasesFile);
    final aliasesFile = File(aliasesPath);
    if (await aliasesFile.exists()) {
      final ar = loadYaml(await aliasesFile.readAsString());
      if (ar is Map && ar['aliases'] is List) {
        aliases.addAll((ar['aliases'] as List).map((e) => e.toString()));
      }
    }
    return KnowCanonicalRef(
      sourceId: sourceId,
      contentSha: contentSha,
      canonicalPath: canonicalPath,
      aliases: aliases,
    );
  }

  @override
  Future<KnowAliasRef?> resolveAlias(final String name) async {
    final aliasFile = File(_aliasFile(name));
    if (!await aliasFile.exists()) return null;
    final raw = await aliasFile.readAsString();
    final yaml = loadYaml(raw) as Map?;
    final sourceId = yaml?['source_id']?.toString();
    final canonicalPath = yaml?['canonical_path']?.toString();
    if (sourceId == null || canonicalPath == null) return null;
    final contentSha = yaml?['content_sha']?.toString();
    return KnowAliasRef(
      sourceId: sourceId,
      canonicalPath: canonicalPath,
      contentSha: contentSha,
    );
  }

  @override
  Future<bool> existsBySourceId(final String sourceId) async {
    final ref = await findBySourceId(sourceId);
    return ref != null;
  }

  @override
  Future<List<String>> saveCanonical(
    final String sourceId,
    final String contentSha,
    final KnowPack pack,
    final String type,
    final String format,
  ) async {
    final written = <String>[];
    final versionDirPath = _versionDir(type, format, sourceId, contentSha);
    await Directory(versionDirPath).create(recursive: true);

    final indexFile = File(p.join(versionDirPath, AeCoreConfig.knowIndexFile));
    await indexFile.writeAsString(pack.indexContent);
    written.add(indexFile.path);

    if (pack.patternsContent != null) {
      final patternsFile = File(p.join(versionDirPath, AeCoreConfig.knowPatternsFile));
      await patternsFile.writeAsString(pack.patternsContent!);
      written.add(patternsFile.path);
    }

    if (pack.matrixYamlContent != null) {
      final y = File(p.join(versionDirPath, AeCoreConfig.knowMatrixFile));
      await y.writeAsString(pack.matrixYamlContent!);
      written.add(y.path);
      final rendered =
          KnowFeatureMatrix.parseYamlString(pack.matrixYamlContent!);
      final md = File(p.join(versionDirPath, AeCoreConfig.knowMatrixMarkdownFile));
      await md.writeAsString(rendered.renderMarkdown());
      written.add(md.path);
    }

    final canonicalPath = _canonicalDir(type, format, sourceId);
    await Directory(canonicalPath).create(recursive: true);

    final metaWithCurrent = KnowMeta(
      name: pack.meta.name,
      version: pack.meta.version,
      source: pack.meta.source,
      distillEngine: pack.meta.distillEngine,
      tokenEstimate: pack.meta.tokenEstimate,
      tags: pack.meta.tags,
      fetchedAt: pack.meta.fetchedAt,
      sha256: pack.meta.sha256,
      sourceId: sourceId,
      contentSha: contentSha,
      aliases: pack.meta.aliases,
      artifacts: pack.meta.artifacts,
    );
    final metaPath = p.join(canonicalPath, AeCoreConfig.knowMetaFile);
    final metaContent = '${metaWithCurrent.toYamlString()}current_content_sha: $contentSha\n';
    await File(metaPath).writeAsString(metaContent);
    written.add(metaPath);

    final bySourcePath = _bySourceFile(sourceId);
    await Directory(p.join(basePath, AeCoreConfig.knowBySourceDir)).create(recursive: true);
    await File(bySourcePath).writeAsString('type: $type\nformat: $format\n');
    written.add(bySourcePath);

    return written;
  }

  @override
  Future<KnowPack?> loadCanonical(
    final String canonicalPath,
    final String contentSha,
  ) =>
      _loadCanonical(canonicalPath, contentSha);

  @override
  Future<void> attachAlias(
    final String name,
    final String sourceId, {
    final String? contentSha,
  }) async {
    final ref = await findBySourceId(sourceId);
    if (ref == null) return;
    final aliasPath = _aliasFile(name);
    await Directory(p.dirname(aliasPath)).create(recursive: true);
    final buffer = StringBuffer()
      ..writeln('source_id: $sourceId')
      ..writeln('canonical_path: ${ref.canonicalPath}');
    if (contentSha != null) buffer.writeln('content_sha: $contentSha');
    await File(aliasPath).writeAsString(buffer.toString());

    final aliasesPath = p.join(basePath, ref.canonicalPath, AeCoreConfig.knowAliasesFile);
    final aliasesFile = File(aliasesPath);
    final List<String> existing = [];
    if (await aliasesFile.exists()) {
      final yaml = loadYaml(await aliasesFile.readAsString());
      if (yaml is Map && yaml['aliases'] is List) {
        existing.addAll((yaml['aliases'] as List).map((e) => e.toString()));
      }
    }
    if (!existing.contains(name)) {
      existing.add(name);
      final buf = StringBuffer()..writeln('aliases:');
      for (final a in existing) {
        buf.writeln('  - $a');
      }
      await aliasesFile.writeAsString(buf.toString());
    }
  }

  @override
  Future<String?> resolvePackContentRoot(final String name) async {
    final aliasRef = await resolveAlias(name);
    if (aliasRef != null) {
      final dir = p.join(basePath, aliasRef.canonicalPath);
      final metaPath = p.join(dir, AeCoreConfig.knowMetaFile);
      final metaFile = File(metaPath);
      if (!await metaFile.exists()) return null;
      final metaYaml = loadYaml(await metaFile.readAsString()) as Map;
      final sha = (aliasRef.contentSha != null &&
              aliasRef.contentSha!.isNotEmpty)
          ? aliasRef.contentSha
          : metaYaml['current_content_sha']?.toString();
      if (sha == null || sha.isEmpty) return null;
      return p.join(dir, AeCoreConfig.knowVersionsDir, sha);
    }
    final legacy = _packDir(name);
    final idx = File(p.join(legacy, AeCoreConfig.knowIndexFile));
    if (await idx.exists()) return legacy;
    return null;
  }

  @override
  Future<String?> resolvePackMetaPath(final String name) async {
    final aliasRef = await resolveAlias(name);
    if (aliasRef != null) {
      return p.join(basePath, aliasRef.canonicalPath, AeCoreConfig.knowMetaFile);
    }
    final legacy = _packDir(name);
    final idx = File(p.join(legacy, AeCoreConfig.knowIndexFile));
    if (await idx.exists()) {
      return p.join(legacy, AeCoreConfig.knowMetaFile);
    }
    return null;
  }

  @override
  Future<void> writePackMeta(final String name, final KnowMeta meta) async {
    final path = await resolvePackMetaPath(name);
    if (path == null) {
      throw StateError('Cannot resolve meta path for pack $name');
    }
    final file = File(path);
    var currentShaLine = '';
    if (await file.exists()) {
      final raw = await file.readAsString();
      for (final line in raw.split('\n')) {
        if (line.startsWith('current_content_sha:')) {
          currentShaLine = line;
          break;
        }
      }
    }
    final buffer = StringBuffer()..write(meta.toYamlString());
    if (currentShaLine.isNotEmpty) {
      buffer.writeln(currentShaLine);
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(buffer.toString());
  }

  @override
  Future<KnowMigrationReport> migrate({bool dryRun = false}) async {
    final merged = <KnowMigrationMerge>[];
    final aliasesCreated = <KnowMigrationAlias>[];
    final errors = <KnowMigrationError>[];
    final removedLegacy = <String>[];

    final dir = Directory(basePath);
    if (!await dir.exists()) {
      return KnowMigrationReport();
    }

    final legacyCandidates = <String>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('_') || _canonicalTypes.contains(name)) continue;
      final indexFile = File(p.join(entity.path, AeCoreConfig.knowIndexFile));
      final metaFile = File(p.join(entity.path, AeCoreConfig.knowMetaFile));
      if (await indexFile.exists() && await metaFile.exists()) {
        legacyCandidates.add(name);
      }
    }

    final bySourceId = <String, List<({String name, KnowPack pack})>>{};
    for (final name in legacyCandidates) {
      final pack = await _loadLegacy(name);
      if (pack == null) {
        errors.add(KnowMigrationError(name: name, message: 'Failed to load pack'));
        continue;
      }
      final meta = pack.meta;
      final sourceId = KnowCanonicalId.sourceId(
        meta.source,
        meta.source.format,
        meta.distillEngine,
      );
      final contentSha = KnowCanonicalId.contentSha256(pack.indexContent);
      final metaWithCanonical = KnowMeta(
        name: meta.name,
        version: meta.version,
        source: meta.source,
        distillEngine: meta.distillEngine,
        tokenEstimate: meta.tokenEstimate,
        tags: meta.tags,
        fetchedAt: meta.fetchedAt,
        sha256: meta.sha256,
        sourceId: sourceId,
        contentSha: contentSha,
        aliases: meta.aliases,
        artifacts: meta.artifacts,
      );
      final packWithMeta = KnowPack(
        meta: metaWithCanonical,
        indexContent: pack.indexContent,
        patternsContent: pack.patternsContent,
        matrixYamlContent: pack.matrixYamlContent,
      );
      bySourceId.putIfAbsent(sourceId, () => []).add((name: name, pack: packWithMeta));
    }

    for (final entry in bySourceId.entries) {
      final sourceId = entry.key;
      final items = entry.value;
      final names = items.map((e) => e.name).toList(growable: false);
      if (names.length > 1) {
        merged.add(KnowMigrationMerge(sourceId: sourceId, names: names));
      }
      final existing = await findBySourceId(sourceId);
      final typeStr = items.first.pack.meta.source.type.value;
      final formatStr = items.first.pack.meta.source.format?.value ?? 'markdown';
      if (existing == null && !dryRun) {
        final first = items.first;
        await saveCanonical(
          sourceId,
          KnowCanonicalId.contentSha256(first.pack.indexContent),
          first.pack,
          typeStr,
          formatStr,
        );
      }
      for (final item in items) {
        if (!dryRun) {
          await attachAlias(
            item.name,
            sourceId,
            contentSha: KnowCanonicalId.contentSha256(item.pack.indexContent),
          );
        }
        aliasesCreated.add(KnowMigrationAlias(name: item.name, sourceId: sourceId));
      }
    }

    if (!dryRun) {
      for (final name in legacyCandidates) {
        final aliasRef = await resolveAlias(name);
        if (aliasRef != null) {
          final legacyDir = Directory(_packDir(name));
          if (await legacyDir.exists()) {
            await legacyDir.delete(recursive: true);
            removedLegacy.add(name);
          }
        }
      }
    }

    return KnowMigrationReport(
      merged: merged,
      aliasesCreated: aliasesCreated,
      errors: errors,
      removedLegacy: removedLegacy,
    );
  }
}
