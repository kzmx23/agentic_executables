import '../models/canonical_pack.dart';
import '../models/distillation_task.dart';

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
