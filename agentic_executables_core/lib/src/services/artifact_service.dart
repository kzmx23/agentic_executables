import 'dart:io';

import '../models/artifact_pack.dart';
import '../models/verify_report.dart';

abstract interface class ArtifactService {
  /// List all artifact pack names.
  Future<List<String>> list();

  /// Load an artifact pack by name.
  Future<ArtifactPack?> load(final String name);

  /// Ingest [sourceDir] using the appropriate heuristic extractor and persist
  /// the resulting artifact under [ArtifactKind.local]. Returns the pack name.
  Future<String> ingest(final Directory sourceDir);

  /// Re-scan the source files for [packName], updating file hashes in
  /// `meta.source.files`. Returns true if any file changed.
  Future<bool> sync(final String packName);

  /// Add a canonical reference to [packName]'s `references_canonical` list.
  /// If [lockedVersion] is null, the reference is live.
  Future<void> link(
    final String packName,
    final String conceptId, {
    final int? lockedVersion,
  });

  /// Upgrade an existing canonical reference to a new locked version.
  /// Re-materializes matrix rows for the new feature set.
  Future<void> upgradeCanonical(
    final String packName,
    final String conceptId, {
    required final int toVersion,
  });

  /// Auto-add matrix rows for every canonical feature referenced by [packName]
  /// that doesn't already appear in the artifact matrix. Default impl status:
  /// missing. Existing rows are preserved (their cell values are not touched).
  Future<int> materialize(final String packName);

  /// Single-artifact tier-classified verify. Includes:
  ///   - Tier 1: invariant violations on referenced canonical features
  ///   - Tier 3: partial features
  ///   - Tier 4: unreferenced canonicals (present in hub but not in
  ///     [ArtifactMeta.referencesCanonical])
  /// Tier 2 (upstream blockers) is project-scoped — see [verifyProject].
  Future<VerifyReport> verifyOne(final String packName);

  /// Project-wide verify across all artifacts. Computes downstream-demand
  /// counts via the `requires:` graph. Tier 2 entries are sorted by
  /// descending downstream count.
  Future<VerifyReport> verifyProject();

  /// Remove an artifact pack.
  Future<bool> remove(final String packName);
}
