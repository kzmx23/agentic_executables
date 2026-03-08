import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as path;

class AeMcpAdapter {
  AeMcpAdapter({required final String resourcesPath})
      : _registryClient = GitHubRawRegistryClient(),
        _definitionService = const DefaultAeDefinitionService(),
        _instructionService =
            DefaultAeInstructionService(FileDocumentStore(resourcesPath)),
        _validationService = const DefaultAeValidationService(),
        _generationService = const DefaultAeGenerationService(
          templateEngine: TemplateGenerationEngine(),
        ) {
    _registryService = DefaultAeRegistryService(_registryClient);
  }

  final GitHubRawRegistryClient _registryClient;
  final AeDefinitionService _definitionService;
  final AeInstructionService _instructionService;
  final AeValidationService _validationService;
  late final AeRegistryService _registryService;
  final AeGenerationService _generationService;

  Future<Map<String, dynamic>> definition(
    final Map<String, dynamic> params,
  ) async {
    final result = _definitionService.getDefinition();
    return _toEnvelope(result, (final data) => data.toJson());
  }

  Future<Map<String, dynamic>> instructions(
    final Map<String, dynamic> params,
  ) async {
    final contextRaw = params['context_type']?.toString() ?? '';
    final actionRaw = params['action']?.toString() ?? '';

    if (contextRaw.isEmpty) {
      return _validationError('Parameter "context_type" is required');
    }
    if (actionRaw.isEmpty) {
      return _validationError('Parameter "action" is required');
    }

    try {
      final context = AeContext.fromString(contextRaw);
      final action = AeAction.fromString(actionRaw);

      final result = await _instructionService.getInstructions(
        GetInstructionsInput(context: context, action: action),
      );
      return _toEnvelope(result, (final data) => data.toJson());
    } catch (error) {
      return _validationError(error.toString());
    }
  }

  Future<Map<String, dynamic>> verify(final Map<String, dynamic> params) async {
    final contextRaw = params['context_type']?.toString() ?? '';
    final actionRaw = params['action']?.toString() ?? '';

    if (contextRaw.isEmpty) {
      return _validationError('Parameter "context_type" is required');
    }
    if (actionRaw.isEmpty) {
      return _validationError('Parameter "action" is required');
    }

    try {
      final context = AeContext.fromString(contextRaw);
      final action = AeAction.fromString(actionRaw);

      final files = _typedListOfObjects(params, 'files_modified')
          .map((final file) => AeModifiedFile.fromJson(file))
          .toList(growable: false);

      final checklistRaw = _typedMap(params, 'checklist_completed');
      final checklist = <String, bool>{};
      for (final entry in checklistRaw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is! bool) {
          throw ArgumentError(
            'Parameter "checklist_completed.$key" must be a bool',
          );
        }
        checklist[key] = value;
      }

      final result = _validationService.verify(
        VerifyInput(
          context: context,
          action: action,
          filesModified: files,
          checklistCompleted: checklist,
        ),
      );

      return _toEnvelope(
        result,
        (final data) => {
          'context_type': context.value,
          'action': action.value,
          'verification': data.toJson(),
          'overall_status': data.overallPass ? 'PASS' : 'FAIL',
          'message': data.overallPass
              ? 'Implementation verification passed.'
              : 'Implementation verification failed. Review missing items.',
        },
      );
    } catch (error) {
      return _validationError(error.toString());
    }
  }

  Future<Map<String, dynamic>> evaluate(
    final Map<String, dynamic> params,
  ) async {
    final contextRaw = params['context_type']?.toString() ?? '';
    final actionRaw = params['action']?.toString() ?? '';

    if (contextRaw.isEmpty) {
      return _validationError('Parameter "context_type" is required');
    }
    if (actionRaw.isEmpty) {
      return _validationError('Parameter "action" is required');
    }

    try {
      final context = AeContext.fromString(contextRaw);
      final action = AeAction.fromString(actionRaw);

      final files = _typedListOfObjects(params, 'files_created')
          .map((final file) => AeCreatedFile.fromJson(file))
          .toList(growable: false);

      final sections = _typedList(params, 'sections_present')
          .map((final entry) => entry.toString())
          .toList(growable: false);

      final result = _validationService.evaluate(
        EvaluateInput(
          context: context,
          action: action,
          filesCreated: files,
          sectionsPresent: sections,
          validationStepsExists: _typedBool(params, 'validation_steps_exists',
              defaultValue: false),
          integrationPointsDefined: _typedBool(
            params,
            'integration_points_defined',
            defaultValue: false,
          ),
          reversibilityIncluded:
              _typedBool(params, 'reversibility_included', defaultValue: false),
          hasMetaRules:
              _typedBool(params, 'has_meta_rules', defaultValue: false),
        ),
      );

      return _toEnvelope(
        result,
        (final data) => {
          'context_type': context.value,
          'action': action.value,
          'evaluation': data.toJson(),
          'overall_status': data.overallPass ? 'PASS' : 'FAIL',
          'message': data.overallPass
              ? 'Implementation meets AE compliance requirements.'
              : 'Implementation has issues that need to be addressed.',
        },
      );
    } catch (error) {
      return _validationError(error.toString());
    }
  }

  Future<Map<String, dynamic>> registry(
      final Map<String, dynamic> params) async {
    final operationRaw = params['operation']?.toString() ?? '';
    if (operationRaw.isEmpty) {
      return _validationError('Parameter "operation" is required');
    }

    final AeRegistryOperation operation;
    try {
      operation = AeRegistryOperation.fromString(operationRaw);
    } catch (error) {
      return _validationError(error.toString());
    }

    switch (operation) {
      case AeRegistryOperation.submitToRegistry:
        final libraryUrl = params['library_url']?.toString() ?? '';
        final libraryId = params['library_id']?.toString() ?? '';
        final files = _parseRegistryFiles(params['ae_use_files']);

        final result = await _registryService.submitToRegistry(
          RegistrySubmitInput(
            libraryUrl: libraryUrl,
            libraryId: libraryId,
            aeUseFiles: files,
          ),
        );

        return _toEnvelope(result, (final data) => data.toJson());

      case AeRegistryOperation.getFromRegistry:
        final libraryId = params['library_id']?.toString() ?? '';
        final actionRaw = params['action']?.toString() ?? '';
        if (actionRaw.isEmpty) {
          return _validationError('Parameter "action" is required');
        }

        final AeAction action;
        try {
          action = AeAction.fromString(actionRaw);
        } catch (error) {
          return _validationError(error.toString());
        }
        final result = await _registryService.getFromRegistry(
          RegistryGetInput(libraryId: libraryId, action: action),
        );

        return _toEnvelope(result, (final data) => data.toJson());

      case AeRegistryOperation.bootstrapLocalRegistry:
        final aeUsePath = params['ae_use_path']?.toString() ?? '';
        final result = _registryService.bootstrapLocalRegistry(
          RegistryBootstrapLocalInput(aeUsePath: aeUsePath),
        );
        return _toEnvelope(result, (final data) => data.toJson());
    }
  }

  Future<Map<String, dynamic>> generate(
      final Map<String, dynamic> params) async {
    final libraryId = params['library_id']?.toString() ?? '';
    final libraryRoot = params['library_root']?.toString() ?? '';
    if (libraryId.isEmpty || libraryRoot.isEmpty) {
      return _validationError(
        'Parameters "library_id" and "library_root" are required',
      );
    }

    final outputDir =
        params['output_dir']?.toString() ?? path.join(libraryRoot, 'ae_use');
    final dryRun = _typedBool(params, 'dry_run', defaultValue: false);

    final modeRaw = (params['engine']?.toString() ?? 'auto').toLowerCase();
    if (modeRaw != 'auto' && modeRaw != 'template') {
      return _validationError(
        'Parameter "engine" must be one of: auto, template',
      );
    }

    const mode = AeGenerationEngineMode.template;

    final result = await _generationService.generate(
      GenerateInput(
        libraryId: libraryId,
        libraryRoot: libraryRoot,
        outputDir: outputDir,
        engineMode: mode,
        dryRun: dryRun,
      ),
    );

    if (!result.success || result.data == null) {
      return _toEnvelope(result, (final data) => data.toJson());
    }

    final generated = result.data!;
    final writtenFiles = <String>[];

    if (!dryRun) {
      final directory = Directory(outputDir);
      await directory.create(recursive: true);
      for (final file in generated.files) {
        final diskPath = path.join(outputDir, file.path);
        await File(diskPath).writeAsString(file.content);
        writtenFiles.add(diskPath);
      }
    }

    final warnings = <String>[...result.warnings];
    for (final file in generated.files) {
      if (file.content.contains('TODO:')) {
        warnings.add('Unresolved placeholder markers found in ${file.path}');
      }
    }

    return {
      'success': true,
      'data': {
        ...generated.toJson(),
        'output_dir': outputDir,
        'dry_run': dryRun,
        'written_files': writtenFiles,
        'engine_requested': modeRaw,
        'engine_resolved': 'template',
      },
      'warnings': warnings,
      'meta': result.meta,
    };
  }

  void close() {
    _registryClient.close();
  }

  Map<String, dynamic> _toEnvelope<T>(
    final AeResult<T> result,
    final Map<String, dynamic> Function(T data) serializer,
  ) {
    if (!result.success || result.data == null) {
      return {
        'success': false,
        'data': const {},
        'error': {
          'code': result.error?.code ?? 'tool_failed',
          'message': result.error?.message ?? 'Tool failed',
          if (result.error?.details != null) 'details': result.error?.details,
        },
        'warnings': result.warnings,
        'meta': result.meta,
      };
    }

    return {
      'success': true,
      'data': serializer(result.data as T),
      'warnings': result.warnings,
      'meta': result.meta,
    };
  }

  Map<String, dynamic> _validationError(final String message) => {
        'success': false,
        'data': const {},
        'error': {
          'code': 'validation_error',
          'message': message,
        },
        'warnings': const [],
        'meta': const {},
      };

  List<Map<String, dynamic>> _typedListOfObjects(
    final Map<String, dynamic> params,
    final String key,
  ) {
    final value = params[key];
    if (value == null) {
      return const [];
    }
    if (value is String) {
      throw ArgumentError(
        'Parameter "$key" must be a typed list of objects. '
        'String-encoded JSON is no longer supported.',
      );
    }
    if (value is! List) {
      throw ArgumentError('Parameter "$key" must be a list of objects');
    }

    final output = <Map<String, dynamic>>[];
    for (final entry in value) {
      if (entry is! Map) {
        throw ArgumentError('Parameter "$key" must contain only objects');
      }
      output.add(
        entry.map(
          (final mapKey, final mapValue) =>
              MapEntry(mapKey.toString(), mapValue),
        ),
      );
    }
    return output;
  }

  Map<String, dynamic> _typedMap(
    final Map<String, dynamic> params,
    final String key,
  ) {
    final value = params[key];
    if (value == null) {
      return const {};
    }
    if (value is String) {
      throw ArgumentError(
        'Parameter "$key" must be a typed object. '
        'String-encoded JSON is no longer supported.',
      );
    }
    if (value is! Map) {
      throw ArgumentError('Parameter "$key" must be an object');
    }
    return value.map(
      (final mapKey, final mapValue) => MapEntry(mapKey.toString(), mapValue),
    );
  }

  List _typedList(final Map<String, dynamic> params, final String key) {
    final value = params[key];
    if (value == null) {
      return const [];
    }
    if (value is String) {
      throw ArgumentError(
        'Parameter "$key" must be a typed list. '
        'String-encoded JSON is no longer supported.',
      );
    }
    if (value is! List) {
      throw ArgumentError('Parameter "$key" must be a list');
    }
    return value;
  }

  bool _typedBool(
    final Map<String, dynamic> params,
    final String key, {
    required final bool defaultValue,
  }) {
    final value = params[key];
    if (value == null) {
      return defaultValue;
    }
    if (value is! bool) {
      throw ArgumentError('Parameter "$key" must be a bool');
    }
    return value;
  }

  List<String> _parseRegistryFiles(final Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is String) {
      return value
          .split(',')
          .map((final entry) => entry.trim())
          .where((final entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    if (value is List) {
      return value
          .map((final entry) => entry.toString())
          .where((final entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    throw ArgumentError(
      'Parameter "ae_use_files" must be a comma-separated string or list',
    );
  }
}
