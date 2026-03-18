import '../models/know.dart';

abstract interface class KnowledgeStore {
  /// Save a know pack to persistent storage. Returns list of files written.
  Future<List<String>> save(final String name, final KnowPack pack);

  /// Load a know pack by name. Returns null if not found.
  Future<KnowPack?> load(final String name);

  /// List all stored know pack metadata.
  Future<List<KnowMeta>> list();

  /// Check if a know pack exists.
  Future<bool> exists(final String name);

  /// Remove a know pack. Returns true if it existed.
  Future<bool> remove(final String name);
}
