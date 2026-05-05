import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

class _FakeRegistryClient implements RegistryClient {
  _FakeRegistryClient({this.exists = true});

  final bool exists;

  @override
  String buildRegistryUrl(final String libraryId, final AeAction action) =>
      'https://example.test/$libraryId/${action.fileName}';

  @override
  Future<String> fetchRegistryFile(
    final String libraryId,
    final AeAction action,
  ) async =>
      '# ${action.fileName}';

  @override
  Future<bool> libraryExists(final String libraryId) async => exists;
}

void main() {
  group('AeCoreConfig', () {
    test('validates library ids and paths', () {
      expect(AeCoreConfig.isValidLibraryId('dart_provider'), isTrue);
      expect(AeCoreConfig.isValidLibraryId('invalid'), isFalse);
      expect(
        AeCoreConfig.registryPath('dart_provider', AeAction.install),
        'ae_use/dart_provider/ae_install.md',
      );
      expect(
        AeCoreConfig.buildGitHubRawUrl(
          owner: 'owner',
          repo: 'repo',
          branch: 'main',
          path: '/ae_use/dart_provider/ae_install.md',
        ),
        'https://raw.githubusercontent.com/owner/repo/main/ae_use/dart_provider/ae_install.md',
      );
    });
  });

  group('DefaultAeRegistryService', () {
    test('submits with generated README mapping', () async {
      final service = DefaultAeRegistryService(_FakeRegistryClient());
      final result = await service.submitToRegistry(
        const RegistrySubmitInput(
          libraryUrl: 'https://github.com/owner/repo',
          libraryId: 'dart_provider',
          aeUseFiles: ['ae_use/ae_install.md', 'ae_use/ae_uninstall.md'],
        ),
      );

      expect(result.success, isTrue);
      final data = result.data!;
      expect(data.registryFolder, 'ae_use/dart_provider');
      expect(data.filesToCopy.length, 3);
    });

    test('gets file from registry', () async {
      final service = DefaultAeRegistryService(_FakeRegistryClient());
      final result = await service.getFromRegistry(
        const RegistryGetInput(
          libraryId: 'dart_provider',
          action: AeAction.install,
        ),
      );

      expect(result.success, isTrue);
      expect(result.data?.content, contains('ae_install.md'));
    });

    test('returns not-found for missing library', () async {
      final service = DefaultAeRegistryService(
        _FakeRegistryClient(exists: false),
      );
      final result = await service.getFromRegistry(
        const RegistryGetInput(
          libraryId: 'dart_provider',
          action: AeAction.install,
        ),
      );

      expect(result.success, isFalse);
      expect(result.error?.code, 'registry_not_found');
    });
  });
}
