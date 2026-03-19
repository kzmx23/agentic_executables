import '../models/know.dart';

abstract interface class KnowledgeStore {
  /// Save a know pack to persistent storage. Returns list of files written.
  Future<List<String>> save(final String name, final KnowPack pack);

  /// Load a know pack by name. Returns null if not found.
  /// Resolves alias -> canonical path when using canonical layout.
  Future<KnowPack?> load(final String name);

  /// List all stored know pack metadata.
  Future<List<KnowMeta>> list();

  /// Check if a know pack exists (by name or alias).
  Future<bool> exists(final String name);

  /// Remove a know pack. Returns true if it existed.
  Future<bool> remove(final String name);

  // --- Canonical source / alias APIs ---

  /// Find canonical pack by source id. Returns null if not found.
  Future<KnowCanonicalRef?> findBySourceId(final String sourceId);

  /// Resolve name to canonical location. Returns null if not an alias or legacy pack.
  Future<KnowAliasRef?> resolveAlias(final String name);

  /// Check if a canonical pack exists for this source id.
  Future<bool> existsBySourceId(final String sourceId);

  /// Save pack under canonical path: type/format/sourceId/versions/contentSha/.
  /// Returns list of files written. [type] and [format] are e.g. "url", "pdf".
  Future<List<String>> saveCanonical(
    final String sourceId,
    final String contentSha,
    final KnowPack pack,
    final String type,
    final String format,
  );

  /// Attach alias [name] to canonical pack [sourceId], optionally [contentSha].
  Future<void> attachAlias(
    final String name,
    final String sourceId, {
    final String? contentSha,
  });

  /// Load pack by canonical path and version content sha.
  Future<KnowPack?> loadCanonical(
    final String canonicalPath,
    final String contentSha,
  );

  /// Migrate legacy name-keyed packs to canonical layout. Optional; may throw UnsupportedError.
  Future<KnowMigrationReport> migrate({bool dryRun = false});
}
