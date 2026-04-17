import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/ae_core_config.dart';
import '../models/artifact_matrix.dart';
import '../models/artifact_pack.dart';
import '../models/requires_spec.dart';
import '../ports/artifact_store.dart';

class FileArtifactStore implements ArtifactStore {
  FileArtifactStore(this._hubRoot);

  final String _hubRoot;

  String get _artifactsRoot =>
      p.join(_hubRoot, AeCoreConfig.hubArtifactsDir);

  String _kindDir(final ArtifactKind kind) =>
      p.join(_artifactsRoot, kind.value);

  String _packDir(final ArtifactKind kind, final String name) =>
      p.join(_kindDir(kind), name);

  Future<ArtifactKind?> _findKindOf(final String name) async {
    for (final kind in ArtifactKind.values) {
      final metaFile = File(
        p.join(_packDir(kind, name), AeCoreConfig.artifactMetaFile),
      );
      if (await metaFile.exists()) return kind;
    }
    return null;
  }

  @override
  Future<List<String>> list() async {
    final all = <String>[];
    for (final kind in ArtifactKind.values) {
      all.addAll(await listByKind(kind));
    }
    all.sort();
    return all;
  }

  @override
  Future<List<String>> listByKind(final ArtifactKind kind) async {
    final dir = Directory(_kindDir(kind));
    if (!await dir.exists()) return const [];
    final names = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory) {
        final metaFile = File(
          p.join(entity.path, AeCoreConfig.artifactMetaFile),
        );
        if (await metaFile.exists()) {
          names.add(p.basename(entity.path));
        }
      }
    }
    names.sort();
    return names;
  }

  @override
  Future<ArtifactPack?> load(final String name) async {
    final kind = await _findKindOf(name);
    if (kind == null) return null;
    final base = _packDir(kind, name);

    final metaFile = File(p.join(base, AeCoreConfig.artifactMetaFile));
    final metaYaml = loadYaml(await metaFile.readAsString());
    if (metaYaml is! Map) return null;
    final meta = ArtifactMeta.fromMap(metaYaml);

    final indexFile = File(p.join(base, AeCoreConfig.artifactIndexFile));
    final indexContent =
        await indexFile.exists() ? await indexFile.readAsString() : '';

    final matrixFile = File(p.join(base, AeCoreConfig.artifactMatrixFile));
    ArtifactMatrix matrix;
    if (await matrixFile.exists()) {
      final matrixYaml = loadYaml(await matrixFile.readAsString());
      matrix = matrixYaml is Map
          ? ArtifactMatrix.fromMap(matrixYaml)
          : const ArtifactMatrix(columnSchema: [], features: []);
    } else {
      matrix = const ArtifactMatrix(columnSchema: [], features: []);
    }

    final patternsFile = File(p.join(base, AeCoreConfig.artifactPatternsFile));
    final patternsContent =
        await patternsFile.exists() ? await patternsFile.readAsString() : null;

    final requiresFile = File(p.join(base, 'requires.yaml'));
    RequiresSpec? requires;
    if (await requiresFile.exists()) {
      final requiresYaml = loadYaml(await requiresFile.readAsString());
      if (requiresYaml is List) {
        requires = RequiresSpec.fromList(requiresYaml);
      }
    }

    return ArtifactPack(
      name: name,
      meta: meta,
      indexContent: indexContent,
      matrix: matrix,
      patternsContent: patternsContent,
      requires: requires,
    );
  }

  @override
  Future<List<String>> save(final ArtifactPack pack) async {
    final base = _packDir(pack.meta.kind, pack.name);
    await Directory(base).create(recursive: true);
    final paths = <String>[];

    final metaPath = p.join(base, AeCoreConfig.artifactMetaFile);
    await File(metaPath).writeAsString(pack.meta.toYamlString());
    paths.add(metaPath);

    final indexPath = p.join(base, AeCoreConfig.artifactIndexFile);
    await File(indexPath).writeAsString(pack.indexContent);
    paths.add(indexPath);

    final matrixPath = p.join(base, AeCoreConfig.artifactMatrixFile);
    await File(matrixPath).writeAsString(pack.matrix.toYamlString());
    paths.add(matrixPath);

    if (pack.patternsContent != null) {
      final patternsPath = p.join(base, AeCoreConfig.artifactPatternsFile);
      await File(patternsPath).writeAsString(pack.patternsContent!);
      paths.add(patternsPath);
    }

    if (pack.requires != null && pack.requires!.entries.isNotEmpty) {
      final requiresPath = p.join(base, 'requires.yaml');
      final buffer = StringBuffer();
      for (final entry in pack.requires!.entries) {
        buffer
          ..writeln('- artifact: ${entry.artifact}')
          ..writeln('  canonical: ${entry.canonical}')
          ..writeln('  features:');
        if (entry.featuresAll) {
          buffer.writeln('    - "*"');
        } else {
          for (final f in entry.features) {
            buffer.writeln('    - ${f.toString()}');
          }
        }
      }
      await File(requiresPath).writeAsString(buffer.toString());
      paths.add(requiresPath);
    }
    return paths;
  }

  @override
  Future<bool> exists(final String name) async => (await _findKindOf(name)) != null;

  @override
  Future<bool> remove(final String name) async {
    final kind = await _findKindOf(name);
    if (kind == null) return false;
    await Directory(_packDir(kind, name)).delete(recursive: true);
    return true;
  }
}
