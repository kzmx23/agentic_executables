import '../models/artifact_pack.dart';

/// Persistence for artifact packs.
abstract interface class ArtifactStore {
  /// List ALL artifact pack names across all kinds.
  Future<List<String>> list();

  /// List artifact pack names for a specific kind.
  Future<List<String>> listByKind(final ArtifactKind kind);

  /// Load an artifact pack by name. Returns null if not found.
  /// The store determines the [ArtifactKind] from disk layout.
  Future<ArtifactPack?> load(final String name);

  /// Save (upsert) the artifact pack. Returns paths written.
  Future<List<String>> save(final ArtifactPack pack);

  /// Whether an artifact pack exists with the given name.
  Future<bool> exists(final String name);

  /// Remove an artifact pack. Returns true if removed.
  Future<bool> remove(final String name);
}
