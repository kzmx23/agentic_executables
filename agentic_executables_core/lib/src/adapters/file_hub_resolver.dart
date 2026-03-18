import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import '../config/ae_core_config.dart';
import '../models/hub.dart';
import '../ports/hub_resolver.dart';

class FileHubResolver implements HubResolver {
  @override
  Future<String?> resolveHub({final String? projectRoot}) async {
    if (projectRoot != null) {
      final projectHub = path.join(
        projectRoot,
        '.${AeCoreConfig.hubDirName}',
        AeCoreConfig.hubConfigFile,
      );
      if (await File(projectHub).exists()) {
        return path.join(projectRoot, '.${AeCoreConfig.hubDirName}');
      }
    }

    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
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
}
