import 'types.dart';

class RegistrySubmitInput {
  const RegistrySubmitInput({
    required this.libraryUrl,
    required this.libraryId,
    required this.aeUseFiles,
  });

  final String libraryUrl;
  final String libraryId;
  final List<String> aeUseFiles;
}

class RegistryFileCopy {
  const RegistryFileCopy({
    required this.source,
    required this.target,
    this.content,
  });

  final String source;
  final String target;
  final String? content;

  Map<String, dynamic> toJson() => {
        'source': source,
        'target': target,
        if (content != null) 'content': content,
      };
}

class RegistrySubmitOutput {
  const RegistrySubmitOutput({
    required this.libraryId,
    required this.registryFolder,
    required this.registryRepoUrl,
    required this.prInstructions,
    required this.filesToCopy,
    required this.status,
    required this.message,
  });

  final String libraryId;
  final String registryFolder;
  final String registryRepoUrl;
  final String prInstructions;
  final List<RegistryFileCopy> filesToCopy;
  final String status;
  final String message;

  Map<String, dynamic> toJson() => {
        'library_id': libraryId,
        'registry_folder': registryFolder,
        'registry_repo_url': registryRepoUrl,
        'pr_instructions': prInstructions,
        'files_to_copy':
            filesToCopy.map((final e) => e.toJson()).toList(growable: false),
        'status': status,
        'message': message,
      };
}

class RegistryGetInput {
  const RegistryGetInput({required this.libraryId, required this.action});

  final String libraryId;
  final AeAction action;
}

class RegistryGetOutput {
  const RegistryGetOutput({
    required this.libraryId,
    required this.action,
    required this.content,
    required this.sourceUrl,
    required this.message,
  });

  final String libraryId;
  final AeAction action;
  final String content;
  final String sourceUrl;
  final String message;

  Map<String, dynamic> toJson() => {
        'library_id': libraryId,
        'action': action.value,
        'content': content,
        'source_url': sourceUrl,
        'message': message,
      };
}

class RegistryBootstrapLocalInput {
  const RegistryBootstrapLocalInput({required this.aeUsePath});

  final String aeUsePath;
}

class RegistryBootstrapLocalOutput {
  const RegistryBootstrapLocalOutput({
    required this.aeUsePath,
    required this.instructions,
    required this.suggestedLibraryId,
    required this.message,
  });

  final String aeUsePath;
  final String instructions;
  final String suggestedLibraryId;
  final String message;

  Map<String, dynamic> toJson() => {
        'ae_use_path': aeUsePath,
        'instructions': instructions,
        'suggested_library_id': suggestedLibraryId,
        'message': message,
      };
}

class RegistryRequest {
  const RegistryRequest.submit(this.input)
      : operation = AeRegistryOperation.submitToRegistry,
        getInput = null,
        bootstrapInput = null;

  const RegistryRequest.get(this.getInput)
      : operation = AeRegistryOperation.getFromRegistry,
        input = null,
        bootstrapInput = null;

  const RegistryRequest.bootstrap(this.bootstrapInput)
      : operation = AeRegistryOperation.bootstrapLocalRegistry,
        input = null,
        getInput = null;

  final AeRegistryOperation operation;
  final RegistrySubmitInput? input;
  final RegistryGetInput? getInput;
  final RegistryBootstrapLocalInput? bootstrapInput;
}
