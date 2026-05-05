import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('registry get without --out keeps JSON content output', () async {
    final result = await runCli(
      [
        'registry',
        'get',
        '--library-id',
        'dart_provider',
        '--action',
        'install'
      ],
      registryClient: _FakeRegistryClient(),
    );

    expect(result.exitCode, 0);
    expect(result.json['data']['content'], '# install doc');
    expect(
        (result.json['data'] as Map<String, dynamic>).containsKey('out_path'),
        isFalse);
  });

  test('registry get --out directory writes action file', () async {
    final temp = await Directory.systemTemp.createTemp('ae_registry_out_dir_');
    addTearDown(() => temp.delete(recursive: true));

    final outDir = Directory(p.join(temp.path, 'ae_use'));
    await outDir.create(recursive: true);

    final result = await runCli(
      [
        'registry',
        'get',
        '--library-id',
        'dart_provider',
        '--action',
        'install',
        '--out',
        outDir.path,
      ],
      registryClient: _FakeRegistryClient(),
    );

    expect(result.exitCode, 0);
    final expectedFile = File(p.join(outDir.path, 'ae_install.md'));
    expect(expectedFile.existsSync(), isTrue);
    expect(expectedFile.readAsStringSync(), '# install doc');
  });

  test('registry get --out path inference supports directory and file targets',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('ae_registry_out_infer_');
    addTearDown(() => temp.delete(recursive: true));

    final directoryLike = p.join(temp.path, 'nested', 'docs');
    final directoryLikeResult = await runCli(
      [
        'registry',
        'get',
        '--library-id',
        'dart_provider',
        '--action',
        'install',
        '--out',
        directoryLike,
      ],
      registryClient: _FakeRegistryClient(),
    );

    expect(directoryLikeResult.exitCode, 0);
    expect(File(p.join(directoryLike, 'ae_install.md')).existsSync(), isTrue);

    final fileLike = p.join(temp.path, 'custom_install.md');
    final fileLikeResult = await runCli(
      [
        'registry',
        'get',
        '--library-id',
        'dart_provider',
        '--action',
        'install',
        '--out',
        fileLike,
      ],
      registryClient: _FakeRegistryClient(),
    );

    expect(fileLikeResult.exitCode, 0);
    expect(File(fileLike).existsSync(), isTrue);
  });

  test('registry get --out honors safe-write check mode', () async {
    final temp =
        await Directory.systemTemp.createTemp('ae_registry_out_check_');
    addTearDown(() => temp.delete(recursive: true));

    final outFile = File(p.join(temp.path, 'ae_install.md'));
    await outFile.writeAsString('drift');

    final result = await runCli(
      [
        'registry',
        'get',
        '--library-id',
        'dart_provider',
        '--action',
        'install',
        '--out',
        outFile.path,
        '--check',
      ],
      registryClient: _FakeRegistryClient(),
    );

    expect(result.exitCode, 1);
    expect(result.json['error']['code'], 'check_mode_changes_detected');
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
