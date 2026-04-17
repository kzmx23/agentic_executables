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
        ),
        _hubResolver = FileHubResolver() {
    _registryService = DefaultAeRegistryService(_registryClient);
    _hubService = DefaultAeHubService(
      _hubResolver,
      registryClient: _registryClient,
    );
  }

  final GitHubRawRegistryClient _registryClient;
  final AeDefinitionService _definitionService;
  final AeInstructionService _instructionService;
  final AeValidationService _validationService;
  late final AeRegistryService _registryService;
  final AeGenerationService _generationService;
  final FileHubResolver _hubResolver;
  late final AeHubService _hubService;

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

      final knowName = params['know_name']?.toString();
      String? knowContext;
      if (knowName != null && knowName.isNotEmpty) {
        final hubPath = await _hubResolver.resolveHub();
        KnowPack? pack;
        if (hubPath != null) {
          final store = FileKnowledgeStore(
            path.join(hubPath, AeCoreConfig.hubKnowDir),
          );
          pack = await store.load(knowName);
        }
        knowContext = _knowPackDomainContext(pack);
        if (knowContext == null) {
          return _validationError(
            'Knowledge pack "$knowName" not found in hub',
          );
        }
      }

      final result = await _instructionService.getInstructions(
        GetInstructionsInput(
          context: context,
          action: action,
          knowContext: knowContext,
        ),
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

    final knowName = params['know_name']?.toString();
    String? knowContext;
    if (knowName != null && knowName.isNotEmpty) {
      final hubPath = await _hubResolver.resolveHub();
      KnowPack? pack;
      if (hubPath != null) {
        final store = FileKnowledgeStore(
          path.join(hubPath, AeCoreConfig.hubKnowDir),
        );
        pack = await store.load(knowName);
      }
      knowContext = _knowPackDomainContext(pack);
      if (knowContext == null) {
        return _validationError('Knowledge pack "$knowName" not found in hub');
      }
    }

    final result = await _generationService.generate(
      GenerateInput(
        libraryId: libraryId,
        libraryRoot: libraryRoot,
        outputDir: outputDir,
        engineMode: mode,
        dryRun: dryRun,
        knowContext: knowContext,
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

  Future<Map<String, dynamic>> hub(
    final Map<String, dynamic> params,
  ) async {
    final operationRaw = params['operation']?.toString() ?? '';
    if (operationRaw.isEmpty) {
      return _validationError('Parameter "operation" is required');
    }

    const validOps = ['init', 'status', 'pull', 'push'];
    if (!validOps.contains(operationRaw)) {
      return _validationError(
        'Parameter "operation" must be one of: ${validOps.join(', ')}',
      );
    }

    try {
      switch (operationRaw) {
        case 'init':
          final hubPath = params['path']?.toString();
          final project =
              _typedBool(params, 'project', defaultValue: false);
          final result = await _hubService.init(
            HubInitInput(path: hubPath, project: project),
          );
          return _toEnvelope(result, (final data) => data.toJson());

        case 'status':
          final hubPath = params['hub_path']?.toString();
          final result = await _hubService.status(
            HubStatusInput(hubPath: hubPath),
          );
          return _toEnvelope(result, (final data) => data.toJson());

        case 'pull':
          final hubPath = params['hub_path']?.toString();
          final remote = params['remote']?.toString() ?? 'origin';
          final libraryId = params['library_id']?.toString();
          final type = params['type']?.toString();
          final result = await _hubService.pull(
            HubPullInput(
              hubPath: hubPath,
              remote: remote,
              libraryId: libraryId,
              type: type,
            ),
          );
          return _toEnvelope(result, (final data) => data.toJson());

        case 'push':
          final hubPath = params['hub_path']?.toString();
          final remote = params['remote']?.toString() ?? 'origin';
          final result = await _hubService.push(
            HubPushInput(hubPath: hubPath, remote: remote),
          );
          return _toEnvelope(result, (final data) => data.toJson());

        default:
          return _validationError('Unknown operation: $operationRaw');
      }
    } catch (error) {
      return _validationError(error.toString());
    }
  }

  Future<Map<String, dynamic>> init(
    final Map<String, dynamic> params,
  ) async {
    final root = params['root']?.toString() ?? Directory.current.path;
    final strict = _typedBool(params, 'strict', defaultValue: false);
    final hubPath = await _hubResolver.resolveHub(projectRoot: root);
    if (hubPath == null) {
      return {
        'success': false,
        'error': {
          'code': 'no_hub',
          'message': 'No .ae_hub at $root',
        },
      };
    }
    final artStore = FileArtifactStore(hubPath);
    final canStore = FileCanonicalStore(hubPath);
    final registry = HeuristicExtractorRegistry(const [
      DartHeuristicExtractor(),
      RustHeuristicExtractor(),
      KotlinSwiftHeuristicExtractor(),
    ]);
    final svc = DefaultArtifactService(
      artifactStore: artStore,
      canonicalStore: canStore,
      extractorRegistry: registry,
    );
    final ingested = <String>[];
    final skipped = <String>[];
    final rootDir = Directory(root);
    await for (final entity in rootDir.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final base = path.basename(entity.path);
      if (base.startsWith('.')) continue;
      final handler = await registry.findFor(entity);
      if (handler != null) {
        final name = await svc.ingest(entity);
        ingested.add(name);
      } else {
        skipped.add(entity.path);
      }
    }
    if (await registry.findFor(rootDir) != null) {
      ingested.add(await svc.ingest(rootDir));
    }
    if (strict && skipped.isNotEmpty) {
      return {
        'success': false,
        'error': {
          'code': 'unhandled_subdirs',
          'message': 'No extractor for ${skipped.length} subdirectories',
          'details': {'skipped': skipped},
        },
      };
    }
    return {
      'success': true,
      'data': {
        'hub_path': hubPath,
        'ingested': ingested,
        'skipped_count': skipped.length,
      },
    };
  }

  Future<Map<String, dynamic>> know(
    final Map<String, dynamic> params,
  ) async {
    final operationRaw = params['operation']?.toString() ?? '';
    if (operationRaw.isEmpty) {
      return _validationError('Parameter "operation" is required');
    }

    const validOps = [
      'build',
      'list',
      'show',
      'remove',
      'update',
      'diff',
      'matrix_init',
      'matrix_scaffold',
      'matrix_compare',
      'plan',
    ];
    if (!validOps.contains(operationRaw)) {
      return _validationError(
        'Parameter "operation" must be one of: ${validOps.join(', ')}',
      );
    }

    final hubPath = params['hub_path']?.toString();

    try {
      final knowService = await _resolveKnowService(hubPath: hubPath);
      if (knowService == null) {
        return _validationError(
          'No hub found. Run ae_hub with operation "init" first.',
        );
      }

      switch (operationRaw) {
        case 'build':
          final name = params['name']?.toString() ?? '';
          if (name.isEmpty) {
            return _validationError('Parameter "name" is required for build');
          }
          final url = params['url']?.toString();
          final localPath = params['local_path']?.toString();
          final repoUrl = params['repo']?.toString();
          final hasUrl = url != null && url.isNotEmpty;
          final hasPath = localPath != null && localPath.isNotEmpty;
          final hasRepo = repoUrl != null && repoUrl.isNotEmpty;
          if (hasUrl && hasPath ||
              hasUrl && hasRepo ||
              hasPath && hasRepo ||
              !(hasUrl || hasPath || hasRepo)) {
            return _validationError(
              'Provide exactly one of: url, local_path, or repo',
            );
          }
          final formatRaw = params['format']?.toString() ?? 'auto';
          final KnowFormat? format = formatRaw == 'auto'
              ? null
              : KnowFormat.fromString(formatRaw);
          final onConflictRaw = params['on_conflict']?.toString() ?? 'reuse';
          final onConflict = KnowOnConflict.fromString(onConflictRaw);
          final result = await knowService.build(
            KnowBuildInput(
              name: name,
              url: hasUrl ? url : null,
              localPath: hasPath ? localPath : null,
              repoUrl: hasRepo ? repoUrl : null,
              hubPath: hubPath,
              format: format,
              onConflict: onConflict,
            ),
          );
          return _toEnvelope(result, (final data) => data.toJson());

        case 'list':
          final result = await knowService.list(
            KnowListInput(hubPath: hubPath),
          );
          return _toEnvelope(result, (final data) => data.toJson());

        case 'show':
          final name = params['name']?.toString() ?? '';
          if (name.isEmpty) {
            return _validationError('Parameter "name" is required for show');
          }
          final result = await knowService.show(
            KnowShowInput(name: name, hubPath: hubPath),
          );
          return _toEnvelope(result, (final data) => data.toJson());

        case 'remove':
          final name = params['name']?.toString() ?? '';
          if (name.isEmpty) {
            return _validationError('Parameter "name" is required for remove');
          }
          final result = await knowService.remove(
            KnowRemoveInput(name: name, hubPath: hubPath),
          );
          return {
            'success': result.success,
            'data': result.success
                ? {'name': name, 'removed': true}
                : const {},
            if (result.error != null)
              'error': {
                'code': result.error!.code,
                'message': result.error!.message,
              },
            'warnings': result.warnings,
            'meta': result.meta,
          };

        case 'update':
          final name = params['name']?.toString() ?? '';
          if (name.isEmpty) {
            return _validationError('Parameter "name" is required for update');
          }
          final result = await knowService.update(
            KnowUpdateInput(name: name, hubPath: hubPath),
          );
          return _toEnvelope(result, (final data) => data.toJson());

        case 'diff':
          final fromName = params['from_name']?.toString() ?? '';
          final toName = params['to_name']?.toString() ?? '';
          if (fromName.isEmpty || toName.isEmpty) {
            return _validationError(
              'Parameters "from_name" and "to_name" are required for diff',
            );
          }
          final diffResult = await knowService.diff(
            KnowDiffInput(
              fromName: fromName,
              toName: toName,
              hubPath: hubPath,
            ),
          );
          return _toEnvelope(diffResult, (final data) => data.toJson());

        case 'matrix_init':
          final name = params['name']?.toString() ?? '';
          if (name.isEmpty) {
            return _validationError('Parameter "name" is required for matrix_init');
          }
          final columnsRaw = params['columns'];
          final columns = <String>[];
          if (columnsRaw is List) {
            columns.addAll(columnsRaw.map((final e) => e.toString()));
          } else if (columnsRaw is String && columnsRaw.isNotEmpty) {
            columns.addAll(
              columnsRaw
                  .split(',')
                  .map((final s) => s.trim())
                  .where((final s) => s.isNotEmpty),
            );
          }
          final result = await knowService.matrixInit(
            KnowMatrixInitInput(
              name: name,
              columns: columns,
              title: params['title']?.toString(),
              hubPath: hubPath,
              normativeKind: params['normative_kind']?.toString(),
              normativeRef: params['normative_ref']?.toString(),
            ),
          );
          return _toEnvelope(result, (final data) => data.toJson());

        case 'matrix_scaffold':
          final name = params['name']?.toString() ?? '';
          final repoPath = params['repo_path']?.toString() ?? '';
          if (name.isEmpty || repoPath.isEmpty) {
            return _validationError(
              'Parameters "name" and "repo_path" are required for matrix_scaffold',
            );
          }
          final result = await knowService.matrixScaffold(
            KnowMatrixScaffoldInput(
              name: name,
              repoPath: repoPath,
              outFile: params['out_file']?.toString(),
              hubPath: hubPath,
            ),
          );
          return _toEnvelope(result, (final data) => data.toJson());

        case 'matrix_compare':
          final result = await knowService.matrixCompare(
            KnowMatrixCompareInput(
              fromName: params['from_name']?.toString(),
              toName: params['to_name']?.toString(),
              fromFile: params['from_file']?.toString(),
              toFile: params['to_file']?.toString(),
              hubPath: hubPath,
            ),
          );
          return _toEnvelope(result, (final data) => data.toJson());

        case 'plan':
          final name = params['name']?.toString() ?? '';
          if (name.isEmpty) {
            return _validationError('Parameter "name" is required for plan');
          }
          final planResult = await knowService.plan(
            KnowPlanInput(name: name, hubPath: hubPath),
          );
          return _toEnvelope(planResult, (final data) => data.toJson());

        default:
          return _validationError('Unknown operation: $operationRaw');
      }
    } catch (error) {
      return _validationError(error.toString());
    }
  }

  Future<AeKnowService?> _resolveKnowService({final String? hubPath}) async {
    final resolved = hubPath ?? await _hubResolver.resolveHub();
    if (resolved == null) return null;

    final knowBasePath = path.join(resolved, AeCoreConfig.hubKnowDir);
    final store = FileKnowledgeStore(knowBasePath);

    return DefaultAeKnowService(
      store: store,
      extractors: [
        UrlExtractor(),
        PdfExtractor(),
        PassthroughExtractor(),
        RepoExtractor(),
      ],
    );
  }

  void close() {
    _registryClient.close();
  }

  /// Index + optional matrix + normative ref for instructions/generate.
  static String? _knowPackDomainContext(final KnowPack? pack) {
    if (pack == null) return null;
    final b = StringBuffer(pack.indexContent);
    if (pack.matrixYamlContent != null) {
      b
        ..writeln()
        ..writeln('## Feature matrix')
        ..writeln()
        ..writeln(
          KnowFeatureMatrix.parseYamlString(pack.matrixYamlContent!)
              .renderMarkdown(),
        );
    }
    final n = pack.meta.artifacts?.normative;
    if (n != null) {
      b
        ..writeln()
        ..writeln('## Normative reference')
        ..writeln()
        ..writeln('- **${n.kind}**: ${n.ref}');
    }
    return b.toString();
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
