import '../models/hub.dart';

abstract interface class HubResolver {
  /// v2 method (carry-over): resolves the hub path by checking project-local
  /// then user-local. Returns null if no hub is found.
  Future<String?> resolveHub({final String? projectRoot});

  /// Loads hub config from the resolved hub path.
  Future<HubConfig> loadConfig(final String hubPath);

  /// Counts artifacts in a hub subdirectory (carry-over from v2).
  Future<int> countArtifacts(final String hubPath, final String subdirectory);

  // --- AE 3.0 additions ---

  /// Path to the user-level hub directory (e.g. `~/.ae_hub`).
  /// Returned even if the directory doesn't exist; callers may create it.
  Future<String> userHubPath();

  /// Resolve a canonical concept by id (e.g. `ecs`, `gltf/core`).
  /// Walks the v3 resolution chain: project hub -> package hubs (3.x) -> user hub.
  /// Returns the directory containing the canonical pack's meta.yaml,
  /// or null if not found.
  Future<String?> resolveCanonical(
    final String conceptId, {
    final String? projectRoot,
  });

  /// Resolve an artifact pack by name. Project hub only.
  /// Returns the directory containing the artifact pack's meta.yaml,
  /// or null if not found.
  Future<String?> resolveArtifact(
    final String packName, {
    final String? projectRoot,
  });

  /// Resolve a package-shipped hub. Stubbed in 3.0 (always null);
  /// activated in 3.x with auto-discovery.
  Future<String?> resolvePackageHub(final String packageId);
}
