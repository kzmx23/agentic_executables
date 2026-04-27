import '../models/canonical_pack.dart';
import '../models/distillation_task.dart';
import '../ports/artifact_store.dart';

/// Result of [CanonicalService.mergeDistillationDetailed]. Carries the merged
/// pack alongside an honest accounting of how many features the distillation
/// output produced vs. how many survived dedup-by-id, plus any warnings
/// (e.g. duplicate feature ids the merge collapsed).
class CanonicalMergeResult {
  const CanonicalMergeResult({
    required this.pack,
    required this.featureCountReceived,
    required this.featureCountAfterMerge,
    this.duplicateIds = const [],
    this.proposedConcepts = const [],
  });

  /// The merged + persisted canonical pack.
  final CanonicalPack pack;

  /// Raw count of features in the distillation output (pre-dedup).
  final int featureCountReceived;

  /// Final count of features in the persisted matrix (post-dedup + union).
  final int featureCountAfterMerge;

  /// Feature ids that appeared more than once in the distillation output and
  /// were collapsed by last-write-wins. Stable order, deduped.
  final List<String> duplicateIds;

  /// Cross-cutting concepts proposed by distill but not committed to the
  /// matrix. Promoted via `ae canonical accept-concept` (Phase B). Empty
  /// when distill output had no `proposed_concepts` field.
  final List<ProposedConcept> proposedConcepts;

  /// True when the distillation output contained one or more duplicate ids.
  bool get hasDuplicates => duplicateIds.isNotEmpty;

  /// Human-readable warnings derived from [duplicateIds]. Empty when none.
  List<String> get warnings => duplicateIds.isEmpty
      ? const []
      : [
          'distill output contained ${duplicateIds.length} duplicate '
              'feature id(s); collapsed by last-write-wins: '
              '${duplicateIds.join(', ')}',
        ];
}

/// Result of [CanonicalService.diff].
class CanonicalDiff {
  const CanonicalDiff({
    required this.addedFeatures,
    required this.removedFeatures,
    required this.changedFeatures,
  });

  final List<String> addedFeatures;
  final List<String> removedFeatures;
  final List<String> changedFeatures;

  bool get isEmpty =>
      addedFeatures.isEmpty &&
      removedFeatures.isEmpty &&
      changedFeatures.isEmpty;

  Map<String, dynamic> toJson() => {
        'added_features': addedFeatures,
        'removed_features': removedFeatures,
        'changed_features': changedFeatures,
      };
}

/// Thrown by [CanonicalService.mergeDistillationDetailed] when the distill
/// output contains feature rows whose `id` is not in the pre-distill
/// matrix. This enforces the id-stability contract: distill enriches; it
/// does not invent. New cross-cutting features must arrive as
/// [ProposedConcept] entries instead.
class IdNotInMatrixException implements Exception {
  const IdNotInMatrixException({
    required this.conceptId,
    required this.unknownIds,
    required this.knownIdCount,
  });

  final String conceptId;
  final List<String> unknownIds;
  final int knownIdCount;

  @override
  String toString() =>
      'IdNotInMatrixException(concept: $conceptId, unknown: $unknownIds, known: $knownIdCount)';
}

/// Result of [CanonicalService.scaffoldUpdate]. Reports the diff between
/// source-artifact symbols and the existing matrix.
class ScaffoldUpdateReport {
  const ScaffoldUpdateReport({
    required this.added,
    required this.removed,
    required this.renamed,
    required this.unchanged,
  });

  /// Feature ids appended to the matrix because they are present in the
  /// source artifact but were absent from the matrix.
  final List<String> added;

  /// Feature ids whose `removed` flag was set to true because they are
  /// absent from the source artifact but present in the matrix. Text
  /// (spec/invariant) is preserved on these rows.
  final List<String> removed;

  /// Pairs `[old_id, new_id]` for `--rename` migrations performed during
  /// this update. Empty unless `--rename` was supplied. See Task B2.
  final List<List<String>> renamed;

  /// Count of rows in the matrix that this run neither added nor newly
  /// tombstoned. Includes rows that were already `removed: true` from a
  /// prior `--update` (idempotent re-run) and rows whose
  /// `cells['provenance'] == 'accepted_concept'` (preserved by policy
  /// — never tombstoned by `--update`). Excludes both rows produced by
  /// each `--rename` pair (the new live row and the old tombstone are
  /// counted separately via [renamed], not here). Text is preserved
  /// verbatim on every row counted here.
  final int unchanged;

  Map<String, dynamic> toJson() => {
        'added': added,
        'removed': removed,
        'renamed': [for (final pair in renamed) {'from': pair[0], 'to': pair[1]}],
        'unchanged': unchanged,
      };
}

abstract interface class CanonicalService {
  /// List all canonical concept ids.
  Future<List<String>> list();

  /// Load a pack by concept id (live by default; pass version to read snapshot).
  Future<CanonicalPack?> load(
    final String conceptId, {
    final int? lockedVersion,
  });

  /// Create a stub canonical with empty matrix and minimal meta.
  /// Useful for `ae canonical init`.
  Future<CanonicalPack> scaffold(final String conceptId, {
    required final String title,
    final String indexContent = '',
  });

  /// Heuristic seed (no LLM) of a draft canonical pack from one or more
  /// artifact packs. Spec §6.7. Parses each artifact's `## Public API`
  /// section in `index.md` (one bullet per public symbol, in the format
  /// emitted by the heuristic extractors) and emits one feature row per
  /// detected symbol with stub `spec`/`invariant` cells the user fills in.
  ///
  /// Feature ids: each symbol becomes `<artifact_pack>.<sanitized_symbol>`,
  /// where the artifact name is taken verbatim (it is already a snake_case
  /// pack id) and the symbol is lower-snake-cased and stripped of
  /// non-`[a-z0-9_]` characters. Two-segment ids (`pack.symbol`) satisfy
  /// [FeatureId]'s required dot. When two artifacts produce the same id,
  /// the first occurrence wins.
  ///
  /// If a live canonical already exists at [conceptId], throws unless
  /// [overwrite] is true; with overwrite, the existing pack is replaced.
  ///
  /// [artifactStore] is the source of artifact packs to read.
  Future<CanonicalPack> scaffoldFromArtifact(
    final String conceptId, {
    required final String title,
    required final List<String> artifactNames,
    required final ArtifactStore artifactStore,
    final bool overwrite = false,
  });

  /// Reconcile the existing canonical at [conceptId] against the current
  /// public-API symbols of [artifactNames]. Deterministic — no LLM. Adds
  /// rows for new symbols (stub spec/invariant), marks vanished symbols
  /// `removed: true` while preserving their text, and leaves unchanged
  /// rows untouched. Throws [StateError] with code `canonical_not_found`
  /// if no pack exists at [conceptId].
  ///
  /// [renames] is an optional list of `old=new` pairs (per Task B2): each
  /// pair migrates the row at `old` to `new`, preserving text under `new`
  /// and leaving a stub `removed: true` row at `old` with `renamed_to:
  /// <new>`. Validates that `old` exists in the matrix and `new` does not.
  Future<ScaffoldUpdateReport> scaffoldUpdate(
    final String conceptId, {
    required final List<String> artifactNames,
    required final ArtifactStore artifactStore,
    final List<List<String>> renames = const [],
  });

  /// Save (upsert) a canonical pack.
  Future<void> upsert(final String conceptId, final CanonicalPack pack);

  /// Run the distillation flow and merge into the canonical at [conceptId].
  /// If a live pack exists, [output] is merged into it (matrix + index);
  /// otherwise a new pack is created from [output].
  Future<CanonicalPack> mergeDistillation(
    final String conceptId,
    final DistillationOutput output,
  );

  /// Same as [mergeDistillation] but returns a [CanonicalMergeResult]
  /// carrying received vs. post-merge feature counts and any duplicate-id
  /// warnings collapsed during the merge. Prefer this in callers that emit
  /// envelopes; the legacy [mergeDistillation] returns only the pack.
  Future<CanonicalMergeResult> mergeDistillationDetailed(
    final String conceptId,
    final DistillationOutput output,
  );

  /// Snapshot the live canonical at [conceptId] into v<n>/.
  Future<String> snapshot(final String conceptId);

  /// Diff two canonical versions of the same concept. Either may be null
  /// (e.g. comparing live vs snapshot).
  Future<CanonicalDiff> diff(
    final String conceptId, {
    required final int? fromVersion,
    required final int? toVersion,
  });

  /// Copy a canonical from another hub directory into this hub.
  /// [externalConceptDir] points at a directory containing meta.yaml + index.md
  /// + matrix.yaml.
  Future<CanonicalPack> import(
    final String externalConceptDir, {
    required final String asConceptId,
  });

  /// Writes (or removes) the `.last_proposals.json` sidecar at the concept
  /// directory root. Called by CLI/MCP after a successful `distill` run, so
  /// `accept-concept` (Task B4) can look up proposals by name. When
  /// [proposals] is empty, any existing file is removed (stale-state hygiene).
  ///
  /// File schema: `ae.proposed_concepts.v1` — see Task B4 for the consumer.
  ///
  /// [producedAt] is optional. The distill-end caller leaves it null so the
  /// service stamps the current time. The accept-concept rewriter (B4) passes
  /// the original timestamp through to avoid drifting the file's "this is
  /// when distill produced these" semantics.
  Future<void> writeProposalsFile(
    final String conceptId, {
    required final List<ProposedConcept> proposals,
    required final String executorUsed,
    final DateTime? producedAt,
  });
}
