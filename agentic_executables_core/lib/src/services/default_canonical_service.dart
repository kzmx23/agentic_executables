import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/ae_core_config.dart';
import '../models/canonical_matrix.dart';
import '../models/canonical_pack.dart';
import '../models/distillation_task.dart';
import '../ports/canonical_store.dart';
import 'canonical_service.dart';

class DefaultCanonicalService implements CanonicalService {
  const DefaultCanonicalService({required this.store});

  final CanonicalStore store;

  @override
  Future<List<String>> list() => store.list();

  @override
  Future<CanonicalPack?> load(
    final String conceptId, {
    final int? lockedVersion,
  }) =>
      store.load(conceptId, lockedVersion: lockedVersion);

  @override
  Future<CanonicalPack> scaffold(
    final String conceptId, {
    required final String title,
    final String indexContent = '',
  }) async {
    final pack = CanonicalPack(
      meta: CanonicalMeta(
        concept: conceptId,
        version: 1,
        title: title,
        license: const CanonicalLicense(
          spdx: 'CC-BY-4.0',
          url: 'https://creativecommons.org/licenses/by/4.0/',
        ),
        authors: const [],
        sources: const [],
        provenance: CanonicalProvenance(
          authored: CanonicalAuthored.hand,
          authoredAt: DateTime.now().toUtc(),
        ),
      ),
      indexContent: indexContent.isEmpty
          ? '# $title\n\nDescribe the concept here.\n'
          : indexContent,
      matrix: CanonicalMatrix(
        concept: conceptId,
        version: 1,
        columnSchema: const [
          CanonicalColumn(id: 'spec', type: 'text'),
          CanonicalColumn(id: 'invariant', type: 'text'),
        ],
        features: const [],
      ),
    );
    await store.save(conceptId, pack);
    return pack;
  }

  @override
  Future<void> upsert(final String conceptId, final CanonicalPack pack) =>
      store.save(conceptId, pack).then((final _) {});

  @override
  Future<CanonicalPack> mergeDistillation(
    final String conceptId,
    final DistillationOutput output,
  ) async {
    final result = await mergeDistillationDetailed(conceptId, output);
    return result.pack;
  }

  @override
  Future<CanonicalMergeResult> mergeDistillationDetailed(
    final String conceptId,
    final DistillationOutput output,
  ) async {
    // Detect duplicate ids in the raw distillation output. We track the order
    // of first appearance so warnings are stable across runs. last-write-wins
    // applies regardless — this just makes the collapse visible.
    final outputIdCounts = <String, int>{};
    for (final f in output.matrix.features) {
      final id = f.id.toString();
      outputIdCounts[id] = (outputIdCounts[id] ?? 0) + 1;
    }
    final duplicateIds = <String>[
      for (final entry in outputIdCounts.entries)
        if (entry.value > 1) entry.key,
    ];

    final existing = await store.load(conceptId);
    if (existing == null) {
      // Create new pack from distilled output. Even on the first write we
      // dedup the matrix so disk reflects what `byId` would have produced.
      final byId = <String, CanonicalFeature>{
        for (final f in output.matrix.features) f.id.toString(): f,
      };
      final dedupedMatrix = CanonicalMatrix(
        concept: output.matrix.concept,
        version: output.matrix.version,
        columnSchema: output.matrix.columnSchema,
        features: byId.values.toList(growable: false),
      );
      final pack = CanonicalPack(
        meta: CanonicalMeta(
          concept: conceptId,
          version: output.conceptVersion,
          title: conceptId,
          license: const CanonicalLicense(
            spdx: 'CC-BY-4.0',
            url: 'https://creativecommons.org/licenses/by/4.0/',
          ),
          authors: const [],
          sources: const [],
          provenance: CanonicalProvenance(
            authored: CanonicalAuthored.distilledFromArtifact,
            authoredAt: DateTime.now().toUtc(),
          ),
        ),
        indexContent: output.indexMd,
        matrix: dedupedMatrix,
      );
      await store.save(conceptId, pack);
      return CanonicalMergeResult(
        pack: pack,
        featureCountReceived: output.matrix.features.length,
        featureCountAfterMerge: dedupedMatrix.features.length,
        duplicateIds: duplicateIds,
      );
    }

    // Merge: union by feature id; new wins on conflict.
    final byId = <String, CanonicalFeature>{
      for (final f in existing.matrix.features) f.id.toString(): f,
    };
    for (final f in output.matrix.features) {
      byId[f.id.toString()] = f;
    }
    final mergedMatrix = CanonicalMatrix(
      concept: conceptId,
      version: existing.meta.version,
      columnSchema: existing.matrix.columnSchema.isNotEmpty
          ? existing.matrix.columnSchema
          : output.matrix.columnSchema,
      features: byId.values.toList(growable: false),
    );
    final merged = CanonicalPack(
      meta: existing.meta,
      indexContent: output.indexMd.isNotEmpty
          ? output.indexMd
          : existing.indexContent,
      matrix: mergedMatrix,
      changelogContent: existing.changelogContent,
    );
    await store.save(conceptId, merged);
    return CanonicalMergeResult(
      pack: merged,
      featureCountReceived: output.matrix.features.length,
      featureCountAfterMerge: mergedMatrix.features.length,
      duplicateIds: duplicateIds,
    );
  }

  @override
  Future<String> snapshot(final String conceptId) => store.snapshot(conceptId);

  @override
  Future<CanonicalDiff> diff(
    final String conceptId, {
    required final int? fromVersion,
    required final int? toVersion,
  }) async {
    final from = await store.load(conceptId, lockedVersion: fromVersion);
    final to = await store.load(conceptId, lockedVersion: toVersion);
    final fromIds = from == null
        ? <String>{}
        : from.matrix.features.map((final f) => f.id.toString()).toSet();
    final toIds = to == null
        ? <String>{}
        : to.matrix.features.map((final f) => f.id.toString()).toSet();
    final added = toIds.difference(fromIds).toList()..sort();
    final removed = fromIds.difference(toIds).toList()..sort();
    final common = fromIds.intersection(toIds);
    final changed = <String>[];
    if (from != null && to != null) {
      final fromMap = {
        for (final f in from.matrix.features) f.id.toString(): f.cells,
      };
      final toMap = {
        for (final f in to.matrix.features) f.id.toString(): f.cells,
      };
      for (final id in common) {
        if (!_mapsEqual(fromMap[id]!, toMap[id]!)) changed.add(id);
      }
      changed.sort();
    }
    return CanonicalDiff(
      addedFeatures: added,
      removedFeatures: removed,
      changedFeatures: changed,
    );
  }

  bool _mapsEqual(
    final Map<String, String> a,
    final Map<String, String> b,
  ) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  Future<CanonicalPack> import(
    final String externalConceptDir, {
    required final String asConceptId,
  }) async {
    final dir = Directory(externalConceptDir);
    if (!await dir.exists()) {
      throw ArgumentError('External canonical dir does not exist: $externalConceptDir');
    }
    final metaFile = File(p.join(dir.path, AeCoreConfig.canonicalMetaFile));
    final indexFile = File(p.join(dir.path, AeCoreConfig.canonicalIndexFile));
    final matrixFile = File(p.join(dir.path, AeCoreConfig.canonicalMatrixFile));
    if (!await metaFile.exists()) {
      throw ArgumentError('External canonical missing meta.yaml: $externalConceptDir');
    }
    final metaYaml = loadYaml(await metaFile.readAsString());
    if (metaYaml is! Map) {
      throw ArgumentError('External meta.yaml is not a map');
    }
    final meta = CanonicalMeta.fromMap(metaYaml);
    final indexContent = await indexFile.exists()
        ? await indexFile.readAsString()
        : '';
    CanonicalMatrix matrix;
    if (await matrixFile.exists()) {
      final raw = loadYaml(await matrixFile.readAsString());
      matrix = raw is Map
          ? CanonicalMatrix.fromMap(raw)
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
    final pack = CanonicalPack(
      meta: meta,
      indexContent: indexContent,
      matrix: matrix,
    );
    await store.save(asConceptId, pack);
    return pack;
  }
}
