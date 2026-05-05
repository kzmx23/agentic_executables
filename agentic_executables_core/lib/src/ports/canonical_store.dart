import '../models/canonical_pack.dart';

/// Persistence for canonical packs.
abstract interface class CanonicalStore {
  /// List all canonical concept ids present in this store.
  Future<List<String>> list();

  /// Load a canonical pack by concept id, optionally locked to a snapshot.
  /// Returns null if not found.
  Future<CanonicalPack?> load(
    final String conceptId, {
    final int? lockedVersion,
  });

  /// Save (upsert) the canonical pack at the live location for [conceptId].
  /// Returns paths written.
  Future<List<String>> save(final String conceptId, final CanonicalPack pack);

  /// Whether a live canonical pack exists for [conceptId].
  Future<bool> exists(final String conceptId);

  /// Remove a canonical pack (live + all snapshots). Returns true if removed.
  Future<bool> remove(final String conceptId);

  /// Snapshot the current live state of [conceptId] into v<n>/, where <n> is
  /// the current `meta.version`. The live files become the new major; caller
  /// is responsible for bumping `meta.version` after this returns.
  /// Returns the snapshot directory path.
  Future<String> snapshot(final String conceptId);

  /// Absolute filesystem path to the concept's directory (where matrix.yaml
  /// and meta.yaml live). Used by services that need to write sidecar files
  /// alongside the canonical (e.g. `.last_proposals.json` for B4).
  Future<String> conceptDirectoryPath(final String conceptId);
}
