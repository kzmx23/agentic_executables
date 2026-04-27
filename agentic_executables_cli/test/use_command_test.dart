import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('ae use', () {
    test('install reads local artifact when present', () async {
      final temp = await Directory.systemTemp.createTemp('ae_use_local_');
      addTearDown(() => temp.delete(recursive: true));

      final hubDir = Directory(p.join(temp.path, '.ae_hub'));
      await hubDir.create(recursive: true);
      await File(p.join(hubDir.path, 'hub.yaml')).writeAsString('version: 1\n');
      final useDir = Directory(
        p.join(hubDir.path, 'artifacts', 'use', 'dart_provider'),
      );
      await useDir.create(recursive: true);
      final localFile = File(p.join(useDir.path, 'ae_install.md'));
      await localFile.writeAsString('# local install doc');

      final result = await runCli(
        [
          'use',
          'install',
          '--library-id',
          'dart_provider',
          '--root',
          temp.path,
        ],
      );

      expect(result.exitCode, 0);
      expect(result.json['success'], isTrue);
      final data = result.json['data'] as Map<String, dynamic>;
      expect(data['source'], 'local_artifact');
      expect(data['content'], '# local install doc');
      expect(data['path'], localFile.path);
      expect(data['action'], 'install');
      expect(data['library_id'], 'dart_provider');
    });

    test('install falls back to registry when no local artifact', () async {
      final temp = await Directory.systemTemp.createTemp('ae_use_reg_');
      addTearDown(() => temp.delete(recursive: true));

      // Hub exists but no artifacts/use/<id> directory.
      final hubDir = Directory(p.join(temp.path, '.ae_hub'));
      await hubDir.create();
      await File(p.join(hubDir.path, 'hub.yaml')).writeAsString('version: 1\n');

      final result = await runCli(
        [
          'use',
          'install',
          '--library-id',
          'dart_provider',
          '--root',
          temp.path,
        ],
        registryClient: _FakeRegistryClient(),
      );

      expect(result.exitCode, 0);
      expect(result.json['success'], isTrue);
      final data = result.json['data'] as Map<String, dynamic>;
      expect(data['source'], 'registry');
      expect(data['content'], '# install doc');
      expect(data['path'], 'https://example.invalid/ae_install.md');
      expect(data['action'], 'install');
    });

    test('install fails when --library-id is missing', () async {
      final temp = await Directory.systemTemp.createTemp('ae_use_validate_');
      addTearDown(() => temp.delete(recursive: true));

      final hubDir = Directory(p.join(temp.path, '.ae_hub'));
      await hubDir.create();
      await File(p.join(hubDir.path, 'hub.yaml')).writeAsString('version: 1\n');

      final result = await runCli(
        ['use', 'install', '--root', temp.path],
        registryClient: _FakeRegistryClient(),
      );

      expect(result.exitCode, 1);
      expect(result.json['success'], isFalse);
      expect(
        (result.json['error'] as Map<String, dynamic>)['code'],
        'validation_error',
      );
    });

    test('uninstall returns no_hub when project has no hub', () async {
      final temp = await Directory.systemTemp.createTemp('ae_use_no_hub_');
      addTearDown(() => temp.delete(recursive: true));

      final result = await runCli(
        [
          'use',
          'uninstall',
          '--library-id',
          'dart_provider',
          '--root',
          temp.path,
        ],
        registryClient: _FakeRegistryClient(),
      );

      expect(result.exitCode, 1);
      expect(result.json['success'], isFalse);
      expect(
        (result.json['error'] as Map<String, dynamic>)['code'],
        'no_hub',
      );
    });

    test('update reads local artifact when present', () async {
      final temp = await Directory.systemTemp.createTemp('ae_use_update_');
      addTearDown(() => temp.delete(recursive: true));

      final hubDir = Directory(p.join(temp.path, '.ae_hub'));
      await hubDir.create(recursive: true);
      await File(p.join(hubDir.path, 'hub.yaml')).writeAsString('version: 1\n');
      final useDir = Directory(
        p.join(hubDir.path, 'artifacts', 'use', 'dart_provider'),
      );
      await useDir.create(recursive: true);
      await File(
        p.join(useDir.path, 'ae_update.md'),
      ).writeAsString('# local update doc');

      final result = await runCli(
        [
          'use',
          'update',
          '--library-id',
          'dart_provider',
          '--root',
          temp.path,
        ],
      );

      expect(result.exitCode, 0);
      final data = result.json['data'] as Map<String, dynamic>;
      expect(data['source'], 'local_artifact');
      expect(data['content'], '# local update doc');
    });
  });
}

class _FakeRegistryClient implements RegistryClient {
  @override
  String buildRegistryUrl(final String libraryId, final AeAction action) =>
      'https://example.invalid/${action.fileName}';

  @override
  Future<String> fetchRegistryFile(
    final String libraryId,
    final AeAction action,
  ) async {
    if (action == AeAction.install) {
      return '# install doc';
    }
    return '# ${action.fileName}';
  }

  @override
  Future<bool> libraryExists(final String libraryId) async =>
      libraryId == 'dart_provider';
}
