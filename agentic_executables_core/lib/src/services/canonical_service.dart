import '../models/canonical_pack.dart';
import '../models/distillation_task.dart';

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
