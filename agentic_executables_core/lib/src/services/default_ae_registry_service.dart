import 'package:path/path.dart' as path;

import '../config/ae_core_config.dart';
import '../models/ae_result.dart';
import '../models/registry.dart';
import '../models/types.dart';
import '../ports/registry_client.dart';
import 'ae_registry_service.dart';

class DefaultAeRegistryService implements AeRegistryService {
  const DefaultAeRegistryService(this._registryClient);

  final RegistryClient _registryClient;

  @override
  Future<AeResult<RegistrySubmitOutput>> submitToRegistry(
    final RegistrySubmitInput input,
  ) async {
    if (input.libraryUrl.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Parameter "library_url" is required',
      );
    }
    if (input.libraryId.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Parameter "library_id" is required',
      );
    }
    if (input.aeUseFiles.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Parameter "ae_use_files" is required',
      );
    }
    if (!AeCoreConfig.isValidLibraryId(input.libraryId)) {
      return AeResult.fail(
        code: 'validation_error',
        message:
            'Invalid library_id format: ${input.libraryId}. Expected <language>_<library_name>.',
      );
    }

    bool exists;
    try {
      exists = await _registryClient.libraryExists(input.libraryId);
    } catch (_) {
      exists = false;
    }

    final status = exists ? 'update' : 'new';
    final folder = AeCoreConfig.registryFolder(input.libraryId);

    final filesToCopy = input.aeUseFiles
        .map(
          (final source) => RegistryFileCopy(
            source: source,
            target: '$folder/${path.basename(source)}',
          ),
        )
        .toList(growable: true);

    final readme = _generateReadme(input.libraryUrl, input.libraryId);
    filesToCopy.add(
      RegistryFileCopy(
        source: 'generated',
        target: '$folder/README.md',
        content: readme,
      ),
    );

    final output = RegistrySubmitOutput(
      libraryId: input.libraryId,
      registryFolder: folder,
      registryRepoUrl: AeCoreConfig.registryRepositoryUrl,
      prInstructions: _generatePrInstructions(
        libraryId: input.libraryId,
        libraryUrl: input.libraryUrl,
        registryFolder: folder,
        status: status,
      ),
      filesToCopy: filesToCopy,
      status: status,
      message: status == 'new'
          ? 'Library ready for registration'
          : 'Library exists - ready for update',
    );

    return AeResult.ok(output, meta: {'operation': 'submit_to_registry'});
  }

  @override
  Future<AeResult<RegistryGetOutput>> getFromRegistry(
    final RegistryGetInput input,
  ) async {
    if (input.libraryId.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Parameter "library_id" is required',
      );
    }
    if (!AeCoreConfig.isValidLibraryId(input.libraryId)) {
      return AeResult.fail(
        code: 'validation_error',
        message:
            'Invalid library_id format: ${input.libraryId}. Expected <language>_<library_name>.',
      );
    }
    if (!input.action.isRegistryAction) {
      return AeResult.fail(
        code: 'validation_error',
        message:
            'Action must be one of: ${AeAction.registryActions.join(', ')}',
      );
    }

    final exists = await _registryClient.libraryExists(input.libraryId);
    if (!exists) {
      return AeResult.fail(
        code: 'registry_not_found',
        message:
            'Library "${input.libraryId}" not found in registry. Ask library author to submit it.',
      );
    }

    try {
      final content = await _registryClient.fetchRegistryFile(
        input.libraryId,
        input.action,
      );
      final sourceUrl = _registryClient.buildRegistryUrl(
        input.libraryId,
        input.action,
      );

      return AeResult.ok(
        RegistryGetOutput(
          libraryId: input.libraryId,
          action: input.action,
          content: content,
          sourceUrl: sourceUrl,
          message: 'File retrieved successfully from registry',
        ),
        meta: {'operation': 'get_from_registry'},
      );
    } catch (error) {
      return AeResult.fail(
        code: 'registry_fetch_failed',
        message:
            'Failed to fetch ${input.action.fileName} for ${input.libraryId}',
        details: error.toString(),
      );
    }
  }

  @override
  AeResult<RegistryBootstrapLocalOutput> bootstrapLocalRegistry(
    final RegistryBootstrapLocalInput input,
  ) {
    if (input.aeUsePath.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Parameter "ae_use_path" is required',
      );
    }

    final suggestedName = _suggestLibraryName(input.aeUsePath);
    final output = RegistryBootstrapLocalOutput(
      aeUsePath: input.aeUsePath,
      instructions: '''# Bootstrap Local Registry

## 1. Create structure

```text
ae_use_registry/
  README.md
  <language>_<library_name>/
    README.md
    ae_install.md
    ae_uninstall.md
    ae_update.md
    ae_use.md
```

## 2. Copy AE files

Copy from `${input.aeUsePath}` into `ae_use_registry/<language>_<library_name>/`.

## 3. Add README metadata

- Repository URL
- Authors/maintainers
- License

## 4. Validate registry fetch flow

Use `ae registry get --library-id <language>_<library_name> --action install` against your local mirror flow.
''',
      suggestedLibraryId: 'dart_$suggestedName',
      message: 'Local registry bootstrap instructions generated',
    );

    return AeResult.ok(output, meta: {'operation': 'bootstrap_local_registry'});
  }

  String _suggestLibraryName(final String aeUsePath) {
    final segments =
        aeUsePath.split('/').where((final s) => s.isNotEmpty).toList();
    if (segments.length >= 2) {
      final candidate = segments[segments.length - 2];
      if (candidate != 'ae_use' && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return 'my_library';
  }

  String _generateReadme(final String libraryUrl, final String libraryId) {
    final language = AeCoreConfig.extractLanguage(libraryId) ?? 'unknown';
    final libraryName = AeCoreConfig.extractLibraryName(libraryId) ?? libraryId;

    return '''# $libraryId

**Repository:** $libraryUrl  
**Authors:** [To be updated]  
**License:** [To be updated]

## Description

$language library: $libraryName

## Related Links

- [Repository]($libraryUrl)
- [Issue Tracker]($libraryUrl/issues)
''';
  }

  String _generatePrInstructions({
    required final String libraryId,
    required final String libraryUrl,
    required final String registryFolder,
    required final String status,
  }) {
    final actionWord = status == 'new' ? 'Add' : 'Update';
    final branchName = '${actionWord.toLowerCase()}-$libraryId';
    final repoUrl = AeCoreConfig.registryRepositoryUrl;

    return '''# $actionWord $libraryId to AE Registry

1. Fork repository: $repoUrl
2. Create branch: `git checkout -b $branchName`
3. Create folder: `mkdir -p $registryFolder`
4. Copy files listed in `files_to_copy`.
5. Commit and push changes.
6. Open PR with title: "$actionWord $libraryId to AE Registry"

Source: $libraryUrl
Status: $status
''';
  }
}
