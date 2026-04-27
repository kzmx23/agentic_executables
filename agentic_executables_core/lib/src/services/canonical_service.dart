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
}
