import '../models/hub.dart';

abstract interface class HubResolver {
  /// Resolves the hub path by checking project-local then user-local.
  /// Returns null if no hub is found.
  Future<String?> resolveHub({final String? projectRoot});

  /// Loads hub config from the resolved hub path.
  Future<HubConfig> loadConfig(final String hubPath);

  /// Counts artifacts in a hub subdirectory.
  Future<int> countArtifacts(final String hubPath, final String subdirectory);
}
