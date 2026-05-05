import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import '../config/ae_core_config.dart';
import '../models/hub.dart';
import '../ports/hub_resolver.dart';

class FileHubResolver implements HubResolver {
  FileHubResolver({this.userHomeOverride});

  /// Test seam: when set, used instead of $HOME / $USERPROFILE.
  final String? userHomeOverride;

  String? _homePath() =>
      userHomeOverride ??
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'];

  static Future<String?> _hubAtProjectRoot(final String projectRoot) async {
    final hubFile = path.join(
      projectRoot,
      '.${AeCoreConfig.hubDirName}',
      AeCoreConfig.hubConfigFile,
    );
    if (await File(hubFile).exists()) {
      return path.join(projectRoot, '.${AeCoreConfig.hubDirName}');
    }
    return null;
  }

  Future<String?> _projectHubFor(final String? projectRoot) async {
    if (projectRoot != null) {
      // Walk up from projectRoot only — do NOT fall back to Directory.current.
      var dir = Directory(path.normalize(projectRoot));
      while (true) {
        final found = await _hubAtProjectRoot(dir.path);
        if (found != null) return found;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
      return null;
    }
    // No projectRoot supplied: walk up from Directory.current.
    var dir = Directory.current;
    while (true) {
      final found = await _hubAtProjectRoot(dir.path);
      if (found != null) return found;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  @override
  Future<String?> resolveHub({final String? projectRoot}) async {
    final projHub = await _projectHubFor(projectRoot);
    if (projHub != null) return projHub;

    final home = _homePath();
    if (home == null) return null;
    final userHub = path.join(
      home,
      '.${AeCoreConfig.hubDirName}',
      AeCoreConfig.hubConfigFile,
    );
    if (await File(userHub).exists()) {
      return path.join(home, '.${AeCoreConfig.hubDirName}');
    }
    return null;
  }

  @override
  Future<HubConfig> loadConfig(final String hubPath) async {
    final configFile = File(
      path.join(hubPath, AeCoreConfig.hubConfigFile),
    );
    if (!await configFile.exists()) return const HubConfig();
    final content = await configFile.readAsString();
    final yaml = loadYaml(content);
    if (yaml is! Map) return const HubConfig();
    return HubConfig.fromMap(yaml);
  }

  @override
  Future<int> countArtifacts(
    final String hubPath,
    final String subdirectory,
  ) async {
    final dir = Directory(path.join(hubPath, subdirectory));
    if (!await dir.exists()) return 0;
    var count = 0;
    await for (final entity in dir.list()) {
      if (entity is Directory) count++;
    }
    return count;
  }

  @override
  Future<String> userHubPath() async {
    final home = _homePath() ?? Directory.current.path;
    return path.join(home, '.${AeCoreConfig.hubDirName}');
  }

  Future<String?> _canonicalAt(
    final String hubPath,
    final String conceptId,
  ) async {
    final candidate = path.joinAll([
      hubPath,
      AeCoreConfig.hubCanonicalDir,
      ...conceptId.split('/'),
    ]);
    final metaFile = File(
      path.join(candidate, AeCoreConfig.canonicalMetaFile),
    );
    if (await metaFile.exists()) return candidate;
    return null;
  }

  @override
  Future<String?> resolveCanonical(
    final String conceptId, {
    final String? projectRoot,
  }) async {
    // 1. Project hub
    final projHub = await _projectHubFor(projectRoot);
    if (projHub != null) {
      final r = await _canonicalAt(projHub, conceptId);
      if (r != null) return r;
    }

    // 2. Package hubs (stubbed in 3.0; activated in 3.x)
    final pkg = await resolvePackageHub(conceptId);
    if (pkg != null) {
      final r = await _canonicalAt(pkg, conceptId);
      if (r != null) return r;
    }

    // 3. User hub
    final userPath = await userHubPath();
    final r = await _canonicalAt(userPath, conceptId);
    if (r != null) return r;

    return null;
  }

  @override
  Future<String?> resolveArtifact(
    final String packName, {
    final String? projectRoot,
  }) async {
    final projHub = await _projectHubFor(projectRoot);
    if (projHub == null) return null;
    final kinds = <String>[
      AeCoreConfig.artifactKindLocal,
      AeCoreConfig.artifactKindExternal,
      AeCoreConfig.artifactKindUse,
    ];
    for (final kind in kinds) {
      final candidate = path.join(
        projHub,
        AeCoreConfig.hubArtifactsDir,
        kind,
        packName,
      );
      final metaFile = File(
        path.join(candidate, AeCoreConfig.artifactMetaFile),
      );
      if (await metaFile.exists()) return candidate;
    }
    return null;
  }

  @override
  Future<String?> resolvePackageHub(final String packageId) async {
    // Stubbed in 3.0. 3.x will discover `<pkg>/.ae_hub/` directories.
    return null;
  }
}
