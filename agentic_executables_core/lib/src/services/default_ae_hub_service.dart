import 'dart:io';

import 'package:path/path.dart' as path;

import '../config/ae_core_config.dart';
import '../models/ae_result.dart';
import '../models/hub.dart';
import '../models/types.dart';
import '../ports/hub_resolver.dart';
import '../ports/registry_client.dart';
import 'ae_hub_service.dart';

class DefaultAeHubService implements AeHubService {
  const DefaultAeHubService(this._resolver, {this.registryClient});

  final HubResolver _resolver;
  final RegistryClient? registryClient;

  @override
  Future<AeResult<HubInitOutput>> init(final HubInitInput input) async {
    try {
      final targetPath = _resolveTargetPath(input);
      final configFile = File(
        path.join(targetPath, AeCoreConfig.hubConfigFile),
      );

      if (await configFile.exists()) {
        return AeResult.ok(
          HubInitOutput(
            path: targetPath,
            created: false,
            message: 'Hub already exists',
          ),
        );
      }

      await Directory(targetPath).create(recursive: true);
      for (final sub in _hubSubdirs) {
        await Directory(path.join(targetPath, sub)).create(recursive: true);
      }

      await configFile.writeAsString(const HubConfig().toYamlString());

      return AeResult.ok(
        HubInitOutput(
          path: targetPath,
          created: true,
          message: 'Hub initialized',
        ),
      );
    } catch (e) {
      return AeResult.fail(
        code: 'hub_init_failed',
        message: 'Failed to initialize hub: $e',
      );
    }
  }

  @override
  Future<AeResult<HubStatus>> status(final HubStatusInput input) async {
    final hubPath = input.hubPath ?? await _resolver.resolveHub();
    if (hubPath == null) {
      return AeResult.fail(
        code: 'hub_not_found',
        message: 'No hub found. Run "ae hub init" to create one.',
      );
    }

    final config = await _resolver.loadConfig(hubPath);
    final knowCount = await _resolver.countArtifacts(
      hubPath,
      AeCoreConfig.hubKnowDir,
    );
    final useCount = await _resolver.countArtifacts(
      hubPath,
      AeCoreConfig.hubUseDir,
    );
    final packageCount = await _resolver.countArtifacts(
      hubPath,
      AeCoreConfig.hubPackagesDir,
    );

    return AeResult.ok(
      HubStatus(
        path: hubPath,
        knowCount: knowCount,
        useCount: useCount,
        packageCount: packageCount,
        config: config,
      ),
    );
  }

  @override
  Future<AeResult<HubPullOutput>> pull(final HubPullInput input) async {
    try {
      final hubPath = input.hubPath ?? await _resolver.resolveHub();
      if (hubPath == null) {
        return AeResult.fail(
          code: 'hub_not_found',
          message: 'No hub found. Run "ae hub init" to create one.',
        );
      }

      final config = await _resolver.loadConfig(hubPath);
      final remote = config.remotes[input.remote];
      if (remote == null) {
        return AeResult.fail(
          code: 'hub_pull_failed',
          message:
              'Remote "${input.remote}" not found in hub config. '
              'Available remotes: ${config.remotes.keys.join(', ')}',
        );
      }

      if (input.libraryId != null && registryClient != null) {
        return _pullLibrary(
          hubPath: hubPath,
          remote: remote,
          remoteName: input.remote,
          libraryId: input.libraryId!,
        );
      }

      return AeResult.ok(
        HubPullOutput(
          hubPath: hubPath,
          remote: input.remote,
          pulled: const [],
          message:
              'Remote "${input.remote}" → ${remote.url} (branch: ${remote.branch}). '
              'Use --library-id <id> to pull a specific library, '
              'or "ae registry get" for individual files.',
        ),
      );
    } catch (e) {
      return AeResult.fail(
        code: 'hub_pull_failed',
        message: 'Failed to pull from hub remote: $e',
      );
    }
  }

  Future<AeResult<HubPullOutput>> _pullLibrary({
    required final String hubPath,
    required final HubRemote remote,
    required final String remoteName,
    required final String libraryId,
  }) async {
    final client = registryClient!;
    final useDir = Directory(
      path.join(hubPath, AeCoreConfig.hubUseDir, libraryId),
    );
    await useDir.create(recursive: true);

    final pulled = <String>[];
    final errors = <String>[];

    for (final action in AeAction.values) {
      try {
        final content = await client.fetchRegistryFile(libraryId, action);
        final dest = File(path.join(useDir.path, action.fileName));
        await dest.writeAsString(content);
        pulled.add(action.fileName);
      } catch (_) {
        errors.add(action.fileName);
      }
    }

    if (pulled.isEmpty) {
      return AeResult.fail(
        code: 'hub_pull_failed',
        message: 'No files found for library "$libraryId" on remote.',
      );
    }

    return AeResult.ok(
      HubPullOutput(
        hubPath: hubPath,
        remote: remoteName,
        pulled: pulled,
        message:
            'Pulled ${pulled.length} file(s) for "$libraryId" into '
            '${useDir.path}',
      ),
      warnings: errors.isNotEmpty
          ? ['Skipped missing: ${errors.join(', ')}']
          : const [],
    );
  }

  @override
  Future<AeResult<HubPushOutput>> push(final HubPushInput input) async {
    try {
      final hubPath = input.hubPath ?? await _resolver.resolveHub();
      if (hubPath == null) {
        return AeResult.fail(
          code: 'hub_not_found',
          message: 'No hub found. Run "ae hub init" to create one.',
        );
      }

      final config = await _resolver.loadConfig(hubPath);
      final remote = config.remotes[input.remote];
      if (remote == null) {
        return AeResult.fail(
          code: 'hub_push_failed',
          message:
              'Remote "${input.remote}" not found in hub config. '
              'Available remotes: ${config.remotes.keys.join(', ')}',
        );
      }

      final useDir = Directory(
        path.join(hubPath, AeCoreConfig.hubUseDir),
      );
      final libraries = <String>[];
      if (await useDir.exists()) {
        await for (final entity in useDir.list()) {
          if (entity is Directory) {
            libraries.add(path.basename(entity.path));
          }
        }
      }

      final buffer = StringBuffer()
        ..writeln('Push to remote "${input.remote}" (${remote.url}):')
        ..writeln()
        ..writeln('1. Fork/clone ${remote.url}')
        ..writeln('2. Copy hub use/ artifacts:');
      for (final lib in libraries) {
        buffer.writeln(
          '   cp -r $hubPath/${AeCoreConfig.hubUseDir}/$lib '
          '${AeCoreConfig.registryBasePath}/$lib',
        );
      }
      buffer
        ..writeln('3. Commit and push to a feature branch')
        ..writeln('4. Open a pull request against ${remote.branch}');

      return AeResult.ok(
        HubPushOutput(
          hubPath: hubPath,
          remote: input.remote,
          instructions: buffer.toString(),
          message:
              'Found ${libraries.length} library(ies) in use/. '
              'Follow instructions to submit to ${remote.url}.',
        ),
      );
    } catch (e) {
      return AeResult.fail(
        code: 'hub_push_failed',
        message: 'Failed to generate push instructions: $e',
      );
    }
  }

  String _resolveTargetPath(final HubInitInput input) {
    if (input.path != null) return input.path!;

    if (input.project) {
      return path.join(
        Directory.current.path,
        '.${AeCoreConfig.hubDirName}',
      );
    }

    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return path.join(home, '.${AeCoreConfig.hubDirName}');
  }

  static const _hubSubdirs = [
    AeCoreConfig.hubKnowDir,
    AeCoreConfig.hubUseDir,
    AeCoreConfig.hubPackagesDir,
  ];
}
