import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/ae_core_config.dart';
import '../models/canonical_matrix.dart';
import '../models/canonical_pack.dart';
import '../ports/canonical_store.dart';

class FileCanonicalStore implements CanonicalStore {
  FileCanonicalStore(this._hubRoot);

  final String _hubRoot;

  String get _canonicalRoot =>
      p.join(_hubRoot, AeCoreConfig.hubCanonicalDir);

  String _conceptDir(final String conceptId) =>
      p.joinAll([_canonicalRoot, ...conceptId.split('/')]);

  String _snapshotDir(final String conceptId, final int version) =>
      p.join(_conceptDir(conceptId), 'v$version');

  @override
  Future<List<String>> list() async {
    final root = Directory(_canonicalRoot);
    if (!await root.exists()) return const [];
    final found = <String>[];
    await _walkConcepts(root, '', found);
    found.sort();
    return found;
  }

  Future<void> _walkConcepts(
    final Directory dir,
    final String prefix,
    final List<String> out,
  ) async {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      // Skip snapshot directories: v<int>
      if (RegExp(r'^v\d+$').hasMatch(name)) continue;
      final metaPath = p.join(entity.path, AeCoreConfig.canonicalMetaFile);
      final hasLiveMeta = await File(metaPath).exists();
      final id = prefix.isEmpty ? name : '$prefix/$name';
      if (hasLiveMeta) {
        out.add(id);
      }
      // Recurse for nested concepts (gltf/core, gltf/extensions/khr_*).
      await _walkConcepts(entity, id, out);
    }
  }

  @override
  Future<CanonicalPack?> load(
    final String conceptId, {
    final int? lockedVersion,
  }) async {
    final base = lockedVersion == null
        ? _conceptDir(conceptId)
        : _snapshotDir(conceptId, lockedVersion);
    final metaFile = File(p.join(base, AeCoreConfig.canonicalMetaFile));
    if (!await metaFile.exists()) return null;

    final metaYaml = loadYaml(await metaFile.readAsString());
    if (metaYaml is! Map) return null;
    final meta = CanonicalMeta.fromMap(metaYaml);

    final indexFile = File(p.join(base, AeCoreConfig.canonicalIndexFile));
    final indexContent =
        await indexFile.exists() ? await indexFile.readAsString() : '';

    final matrixFile = File(p.join(base, AeCoreConfig.canonicalMatrixFile));
    CanonicalMatrix matrix;
    if (await matrixFile.exists()) {
      final matrixYaml = loadYaml(await matrixFile.readAsString());
      matrix = matrixYaml is Map
          ? CanonicalMatrix.fromMap(matrixYaml)
          : CanonicalMatrix(
              concept: meta.concept,
              version: meta.version,
              columnSchema: const [],
              features: const [],
            );
    } else {
      matrix = CanonicalMatrix(
        concept: meta.concept,
        version: meta.version,
        columnSchema: const [],
        features: const [],
      );
    }

    final changelogFile =
        File(p.join(base, AeCoreConfig.canonicalChangelogFile));
    final changelog =
        await changelogFile.exists() ? await changelogFile.readAsString() : null;

    return CanonicalPack(
      meta: meta,
      indexContent: indexContent,
      matrix: matrix,
      changelogContent: changelog,
    );
  }

  @override
  Future<List<String>> save(
    final String conceptId,
    final CanonicalPack pack,
  ) async {
    final base = _conceptDir(conceptId);
    await Directory(base).create(recursive: true);
    final paths = <String>[];

    final metaPath = p.join(base, AeCoreConfig.canonicalMetaFile);
    await File(metaPath).writeAsString(pack.meta.toYamlString());
    paths.add(metaPath);

    final indexPath = p.join(base, AeCoreConfig.canonicalIndexFile);
    await File(indexPath).writeAsString(pack.indexContent);
    paths.add(indexPath);

    final matrixPath = p.join(base, AeCoreConfig.canonicalMatrixFile);
    await File(matrixPath).writeAsString(pack.matrix.toYamlString());
    paths.add(matrixPath);

    if (pack.changelogContent != null) {
      final clPath = p.join(base, AeCoreConfig.canonicalChangelogFile);
      await File(clPath).writeAsString(pack.changelogContent!);
      paths.add(clPath);
    }
    return paths;
  }

  @override
  Future<bool> exists(final String conceptId) async {
    final metaFile = File(
      p.join(_conceptDir(conceptId), AeCoreConfig.canonicalMetaFile),
    );
    return metaFile.exists();
  }

  @override
  Future<bool> remove(final String conceptId) async {
    final dir = Directory(_conceptDir(conceptId));
    if (!await dir.exists()) return false;
    await dir.delete(recursive: true);
    return true;
  }

  @override
  Future<String> snapshot(final String conceptId) async {
    final live = await load(conceptId);
    if (live == null) {
      throw StateError('Cannot snapshot $conceptId: no live pack');
    }
    final version = live.meta.version;
    final snapDir = _snapshotDir(conceptId, version);
    await Directory(snapDir).create(recursive: true);

    final base = _conceptDir(conceptId);
    // Move live files into snap dir.
    Future<void> moveIfExists(final String filename) async {
      final src = File(p.join(base, filename));
      if (await src.exists()) {
        final dst = File(p.join(snapDir, filename));
        await src.copy(dst.path);
        await src.delete();
      }
    }

    await moveIfExists(AeCoreConfig.canonicalMetaFile);
    await moveIfExists(AeCoreConfig.canonicalIndexFile);
    await moveIfExists(AeCoreConfig.canonicalMatrixFile);
    await moveIfExists(AeCoreConfig.canonicalChangelogFile);
    return snapDir;
  }
}
