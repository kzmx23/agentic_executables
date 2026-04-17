import 'dart:io';

import 'package:crypto/crypto.dart';

import '../adapters/heuristic_extractor_registry.dart';
import '../models/artifact_matrix.dart';
import '../models/artifact_pack.dart';
import '../ports/artifact_store.dart';
import '../ports/canonical_store.dart';
import 'artifact_service.dart';

class DefaultArtifactService implements ArtifactService {
  const DefaultArtifactService({
    required this.artifactStore,
    required this.canonicalStore,
    required this.extractorRegistry,
  });

  final ArtifactStore artifactStore;
  final CanonicalStore canonicalStore;
  final HeuristicExtractorRegistry extractorRegistry;

  @override
  Future<List<String>> list() => artifactStore.list();

  @override
  Future<ArtifactPack?> load(final String name) => artifactStore.load(name);

  @override
  Future<bool> remove(final String name) => artifactStore.remove(name);

  @override
  Future<String> ingest(final Directory sourceDir) async {
    final extractor = await extractorRegistry.findFor(sourceDir);
    if (extractor == null) {
      throw ArgumentError(
        'No heuristic extractor handles ${sourceDir.path}',
      );
    }
    final artifact = await extractor.extract(sourceDir);
    final pack = artifact.toArtifactPack();
    await artifactStore.save(pack);
    return pack.name;
  }

  @override
  Future<bool> sync(final String packName) async {
    final pack = await artifactStore.load(packName);
    if (pack == null) {
      throw ArgumentError('Unknown artifact: $packName');
    }
    final basePath = pack.meta.source.path;
    if (basePath == null) {
      throw StateError('Cannot sync $packName: source.path is null');
    }
    final newFiles = <ArtifactSourceFile>[];
    var changed = false;
    for (final entry in pack.meta.source.files) {
      final file = File('$basePath/${entry.path}');
      if (!await file.exists()) {
        // Drop missing files; mark changed.
        changed = true;
        continue;
      }
      final bytes = await file.readAsBytes();
      final newHash = sha256.convert(bytes).toString();
      if (newHash != entry.sha256) changed = true;
      newFiles.add(ArtifactSourceFile(path: entry.path, sha256: newHash));
    }
    if (changed) {
      final updated = ArtifactPack(
        name: pack.name,
        meta: ArtifactMeta(
          kind: pack.meta.kind,
          title: pack.meta.title,
          source: ArtifactSource(
            type: pack.meta.source.type,
            path: pack.meta.source.path,
            url: pack.meta.source.url,
            files: newFiles,
          ),
          scannedAt: DateTime.now().toUtc(),
          license: pack.meta.license,
          authors: pack.meta.authors,
          referencesCanonical: pack.meta.referencesCanonical,
          extractor: pack.meta.extractor,
          distill: pack.meta.distill,
        ),
        indexContent: pack.indexContent,
        matrix: pack.matrix,
        patternsContent: pack.patternsContent,
        requires: pack.requires,
      );
      await artifactStore.save(updated);
    }
    return changed;
  }

  @override
  Future<void> link(
    final String packName,
    final String conceptId, {
    final int? lockedVersion,
  }) async {
    final pack = await artifactStore.load(packName);
    if (pack == null) {
      throw ArgumentError('Unknown artifact: $packName');
    }
    final ref = CanonicalReference.parse(
      lockedVersion == null ? conceptId : '$conceptId@v$lockedVersion',
    );
    // De-dup by toString() — replace if same conceptId@version, else append.
    final list = List<CanonicalReference>.from(pack.meta.referencesCanonical);
    final existingIndex = list.indexWhere(
      (final r) => r.conceptId == ref.conceptId,
    );
    if (existingIndex >= 0) {
      list[existingIndex] = ref;
    } else {
      list.add(ref);
    }
    await _saveWithUpdatedMeta(pack, referencesCanonical: list);
  }

  @override
  Future<void> upgradeCanonical(
    final String packName,
    final String conceptId, {
    required final int toVersion,
  }) async {
    await link(packName, conceptId, lockedVersion: toVersion);
  }

  @override
  Future<int> materialize(final String packName) async {
    final pack = await artifactStore.load(packName);
    if (pack == null) {
      throw ArgumentError('Unknown artifact: $packName');
    }
    final existingIds =
        pack.matrix.features.map((final f) => f.id.toString()).toSet();
    final newRows = <ArtifactFeatureRow>[];
    for (final ref in pack.meta.referencesCanonical) {
      final canonicalPack = await canonicalStore.load(
        ref.conceptId,
        lockedVersion: ref.lockedVersion,
      );
      if (canonicalPack == null) continue;
      for (final feature in canonicalPack.matrix.features) {
        if (existingIds.contains(feature.id.toString())) continue;
        newRows.add(ArtifactFeatureRow(
          id: feature.id,
          canonical: ref.conceptId,
          cell: const ArtifactCell(impl: ImplStatus.missing),
        ));
        existingIds.add(feature.id.toString());
      }
    }
    if (newRows.isEmpty) return 0;
    final mergedFeatures = [
      ...pack.matrix.features,
      ...newRows,
    ];
    final updated = ArtifactPack(
      name: pack.name,
      meta: pack.meta,
      indexContent: pack.indexContent,
      matrix: ArtifactMatrix(
        columnSchema: pack.matrix.columnSchema,
        features: mergedFeatures,
      ),
      patternsContent: pack.patternsContent,
      requires: pack.requires,
    );
    await artifactStore.save(updated);
    return newRows.length;
  }

  Future<void> _saveWithUpdatedMeta(
    final ArtifactPack pack, {
    final List<CanonicalReference>? referencesCanonical,
  }) async {
    final updated = ArtifactPack(
      name: pack.name,
      meta: ArtifactMeta(
        kind: pack.meta.kind,
        title: pack.meta.title,
        source: pack.meta.source,
        scannedAt: pack.meta.scannedAt,
        license: pack.meta.license,
        authors: pack.meta.authors,
        referencesCanonical:
            referencesCanonical ?? pack.meta.referencesCanonical,
        extractor: pack.meta.extractor,
        distill: pack.meta.distill,
      ),
      indexContent: pack.indexContent,
      matrix: pack.matrix,
      patternsContent: pack.patternsContent,
      requires: pack.requires,
    );
    await artifactStore.save(updated);
  }
}
