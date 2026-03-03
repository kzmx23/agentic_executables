import 'dart:convert';
import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'engine/codex_exec_generation_engine.dart';

class AeCli {
  AeCli({
    IOSink? out,
    IOSink? err,
    this.repoRootOverride,
    this.codexBinary,
    this.environment,
    this.inferenceClient,
  })  : _out = out ?? stdout,
        _err = err ?? stderr;

  final IOSink _out;
  final IOSink _err;
  final String? repoRootOverride;
  final String? codexBinary;
  final Map<String, String>? environment;
  final InferenceClient? inferenceClient;

  Future<int> run(final List<String> args) async {
    final parser = _buildParser();

    late final ArgResults results;
    try {
      results = parser.parse(args);
    } on FormatException catch (error) {
      final envelope = _errorEnvelope(
        command: 'parse',
        code: 'invalid_arguments',
        message: error.message,
      );
      _out.writeln(jsonEncode(envelope));
      return 64;
    }

    if (results['help'] == true || results.command == null) {
      _out.writeln(_usage(parser));
      return 0;
    }

    final human = results['human'] == true;
    final commandPath = _commandPath(results);
    final stopwatch = Stopwatch()..start();

    late final Map<String, dynamic> envelope;
    try {
      final commandResult = await _dispatch(results);
      envelope = _resultToEnvelope(commandPath, commandResult);
    } catch (error, stack) {
      envelope = _errorEnvelope(
        command: commandPath,
        code: 'internal_error',
        message: 'Unhandled command error',
        details: '$error\n$stack',
      );
    }

    stopwatch.stop();

    final meta = (envelope['meta'] as Map<String, dynamic>?) ?? {};
    envelope['meta'] = {
      ...meta,
      'timing_ms': stopwatch.elapsedMilliseconds,
      'versions': {'cli': '0.1.0', 'core': AeCoreConfig.frameworkVersion},
    };

    if (human) {
      _printHuman(envelope);
    } else {
      _out.writeln(jsonEncode(envelope));
    }

    return envelope['success'] == true ? 0 : 1;
  }

  ArgParser _buildParser() {
    final parser = ArgParser()
      ..addFlag('human', negatable: false, help: 'Readable output mode')
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

    parser.addCommand('definition');

    parser.addCommand('instructions')
      ?..addOption(
        'context',
        allowed: AeContext.validValues,
        help: 'Context type',
      )
      ..addOption('action', allowed: AeAction.validValues, help: 'Action type')
      ..addOption('resources-path', help: 'Path to prompts resources');

    parser.addCommand('verify')
      ?..addOption(
        'input',
        defaultsTo: '-',
        help: 'JSON file path or - for stdin',
      );

    parser.addCommand('evaluate')
      ?..addOption(
        'input',
        defaultsTo: '-',
        help: 'JSON file path or - for stdin',
      );

    final registry = parser.addCommand('registry');
    registry?.addCommand('get')
      ?..addOption('library-id', help: 'Library id')
      ..addOption(
        'action',
        allowed: AeAction.registryActions,
        help: 'Registry action',
      );

    registry?.addCommand('submit')
      ?..addOption('library-url', help: 'Library repository URL')
      ..addOption('library-id', help: 'Library id')
      ..addMultiOption(
        'ae-use-files',
        splitCommas: true,
        help: 'AE file list (CSV or repeated flag)',
      );

    registry?.addCommand('bootstrap-local')
      ?..addOption('ae-use-path', help: 'Path to ae_use directory');

    parser.addCommand('generate')
      ?..addOption('library-id', help: 'Library id')
      ..addOption('library-root', help: 'Library root path')
      ..addOption('output-dir', help: 'Output directory for generated files')
      ..addOption(
        'engine',
        allowed: AeGenerationEngineMode.validValues,
        defaultsTo: AeGenerationEngineMode.auto.value,
        help: 'Generation engine mode',
      )
      ..addFlag('dry-run', negatable: false, help: 'Do not write files');

    final skill = parser.addCommand('skill');
    skill?.addCommand('install')
      ?..addOption('target', help: 'Skills directory target')
      ..addOption('name', defaultsTo: 'ae-cli', help: 'Skill folder name')
      ..addFlag('force', negatable: false, help: 'Overwrite existing skill');

    skill?.addCommand('update')
      ?..addOption('target', help: 'Skills directory target')
      ..addOption('name', defaultsTo: 'ae-cli', help: 'Skill folder name');

    return parser;
  }

  String _usage(final ArgParser parser) => '''
ae CLI v2

${parser.usage}

Commands:
  ae definition
  ae instructions --context <library|project> --action <...> [--resources-path <path>]
  ae verify --input <json-file|->
  ae evaluate --input <json-file|->
  ae registry get --library-id <id> --action <install|uninstall|update|use>
  ae registry submit --library-url <url> --library-id <id> --ae-use-files <csv|repeatable>
  ae registry bootstrap-local --ae-use-path <path>
  ae generate --library-id <id> --library-root <path> [--output-dir <path>] [--engine auto|codex|template] [--dry-run]
  ae skill install [--target <skills-dir>] [--name ae-cli] [--force]
  ae skill update [--target <skills-dir>] [--name ae-cli]
''';

  String _commandPath(final ArgResults root) {
    final parts = <String>[];
    var current = root;
    while (current.command != null) {
      current = current.command!;
      if (current.name != null) {
        parts.add(current.name!);
      }
    }
    return parts.join(' ');
  }

  Future<AeResult<Map<String, dynamic>>> _dispatch(
    final ArgResults root,
  ) async {
    final command = root.command;
    if (command == null) {
      return AeResult.fail(code: 'invalid_command', message: 'Missing command');
    }

    switch (command.name) {
      case 'definition':
        return _handleDefinition();
      case 'instructions':
        return _handleInstructions(command);
      case 'verify':
        return _handleVerify(command);
      case 'evaluate':
        return _handleEvaluate(command);
      case 'registry':
        return _handleRegistry(command);
      case 'generate':
        return _handleGenerate(command);
      case 'skill':
        return _handleSkill(command);
      default:
        return AeResult.fail(
          code: 'invalid_command',
          message: 'Unknown command: ${command.name}',
        );
    }
  }

  AeResult<Map<String, dynamic>> _handleDefinition() {
    final result = const DefaultAeDefinitionService().getDefinition();
    if (!result.success || result.data == null) {
      return AeResult.fail(
        code: result.error?.code ?? 'definition_failed',
        message: result.error?.message ?? 'Failed to get definition',
        details: result.error?.details,
      );
    }

    return AeResult.ok(
      result.data!.toJson(),
      warnings: result.warnings,
      meta: result.meta,
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleInstructions(
    final ArgResults command,
  ) async {
    final contextRaw = command['context']?.toString();
    final actionRaw = command['action']?.toString();
    if (contextRaw == null || contextRaw.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Missing required argument: --context',
      );
    }
    if (actionRaw == null || actionRaw.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Missing required argument: --action',
      );
    }

    final AeContext context;
    final AeAction action;
    try {
      context = AeContext.fromString(contextRaw);
      action = AeAction.fromString(actionRaw);
    } catch (error) {
      return AeResult.fail(code: 'validation_error', message: error.toString());
    }

    final resourcesPath = command['resources-path']?.toString() ??
        path.join(_repoRoot(), 'prompts_framework');

    final service = DefaultAeInstructionService(
      FileDocumentStore(resourcesPath),
    );
    final result = await service.getInstructions(
      GetInstructionsInput(context: context, action: action),
    );

    if (!result.success || result.data == null) {
      return AeResult.fail(
        code: result.error?.code ?? 'instructions_failed',
        message: result.error?.message ?? 'Failed to get instructions',
        details: result.error?.details,
      );
    }

    return AeResult.ok(
      result.data!.toJson(),
      warnings: result.warnings,
      meta: {...result.meta, 'resources_path': resourcesPath},
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleVerify(
    final ArgResults command,
  ) async {
    final inputPath = command['input'].toString();
    final payload = await _readInputJson(inputPath);

    final contextRaw = payload['context_type']?.toString();
    final actionRaw = payload['action']?.toString();
    if (contextRaw == null || actionRaw == null) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'context_type and action are required',
      );
    }

    final AeContext context;
    final AeAction action;
    try {
      context = AeContext.fromString(contextRaw);
      action = AeAction.fromString(actionRaw);
    } catch (error) {
      return AeResult.fail(code: 'validation_error', message: error.toString());
    }

    final filesRaw = _parseList(payload['files_modified']);
    final files = filesRaw
        .whereType<Map>()
        .map(
          (final entry) => AeModifiedFile.fromJson(
            entry.map(
              (final key, final value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);

    final checklistRaw = _parseMap(payload['checklist_completed']);
    final checklist = <String, bool>{
      for (final entry in checklistRaw.entries)
        entry.key.toString(): _parseBool(entry.value),
    };

    final validation = const DefaultAeValidationService().verify(
      VerifyInput(
        context: context,
        action: action,
        filesModified: files,
        checklistCompleted: checklist,
      ),
    );

    if (!validation.success || validation.data == null) {
      return AeResult.fail(
        code: validation.error?.code ?? 'verify_failed',
        message: validation.error?.message ?? 'Verification failed',
        details: validation.error?.details,
      );
    }

    final output = validation.data!;
    return AeResult.ok(
      {
        'context_type': context.value,
        'action': action.value,
        'verification': output.toJson(),
        'overall_status': output.overallPass ? 'PASS' : 'FAIL',
        'message': output.overallPass
            ? 'Implementation verification passed.'
            : 'Implementation verification failed. Review missing items.',
      },
      warnings: validation.warnings,
      meta: validation.meta,
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleEvaluate(
    final ArgResults command,
  ) async {
    final inputPath = command['input'].toString();
    final payload = await _readInputJson(inputPath);

    final contextRaw = payload['context_type']?.toString();
    final actionRaw = payload['action']?.toString();
    if (contextRaw == null || actionRaw == null) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'context_type and action are required',
      );
    }

    final AeContext context;
    final AeAction action;
    try {
      context = AeContext.fromString(contextRaw);
      action = AeAction.fromString(actionRaw);
    } catch (error) {
      return AeResult.fail(code: 'validation_error', message: error.toString());
    }

    final filesRaw = _parseList(payload['files_created']);
    final files = filesRaw
        .whereType<Map>()
        .map(
          (final entry) => AeCreatedFile.fromJson(
            entry.map(
              (final key, final value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);

    final sections = _parseList(
      payload['sections_present'],
    ).map((final entry) => entry.toString()).toList(growable: false);

    final validation = const DefaultAeValidationService().evaluate(
      EvaluateInput(
        context: context,
        action: action,
        filesCreated: files,
        sectionsPresent: sections,
        validationStepsExists: _parseBool(payload['validation_steps_exists']),
        integrationPointsDefined: _parseBool(
          payload['integration_points_defined'],
        ),
        reversibilityIncluded: _parseBool(payload['reversibility_included']),
        hasMetaRules: _parseBool(payload['has_meta_rules']),
      ),
    );

    if (!validation.success || validation.data == null) {
      return AeResult.fail(
        code: validation.error?.code ?? 'evaluate_failed',
        message: validation.error?.message ?? 'Evaluation failed',
        details: validation.error?.details,
      );
    }

    final output = validation.data!;
    return AeResult.ok(
      {
        'context_type': context.value,
        'action': action.value,
        'evaluation': output.toJson(),
        'overall_status': output.overallPass ? 'PASS' : 'FAIL',
        'message': output.overallPass
            ? 'Implementation meets AE compliance requirements.'
            : 'Implementation has issues that need to be addressed.',
      },
      warnings: validation.warnings,
      meta: validation.meta,
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleRegistry(
    final ArgResults command,
  ) async {
    final sub = command.command;
    if (sub == null) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Registry subcommand is required',
      );
    }

    final client = GitHubRawRegistryClient();
    final service = DefaultAeRegistryService(client);

    switch (sub.name) {
      case 'get':
        final libraryId = sub['library-id']?.toString() ?? '';
        final actionRaw = sub['action']?.toString() ?? '';
        if (actionRaw.isEmpty) {
          client.close();
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing required argument: --action',
          );
        }

        final AeAction action;
        try {
          action = AeAction.fromString(actionRaw);
        } catch (error) {
          client.close();
          return AeResult.fail(
            code: 'validation_error',
            message: error.toString(),
          );
        }

        final result = await service.getFromRegistry(
          RegistryGetInput(libraryId: libraryId, action: action),
        );
        client.close();

        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'registry_get_failed',
            message: result.error?.message ?? 'Registry get failed',
            details: result.error?.details,
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        return AeResult.ok(
          result.data!.toJson(),
          warnings: result.warnings,
          meta: result.meta,
        );

      case 'submit':
        final libraryUrl = sub['library-url']?.toString() ?? '';
        final libraryId = sub['library-id']?.toString() ?? '';
        final files = (sub['ae-use-files'] as List)
            .map((final value) => value.toString())
            .where((final value) => value.isNotEmpty)
            .toList(growable: false);

        final result = await service.submitToRegistry(
          RegistrySubmitInput(
            libraryUrl: libraryUrl,
            libraryId: libraryId,
            aeUseFiles: files,
          ),
        );
        client.close();

        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'registry_submit_failed',
            message: result.error?.message ?? 'Registry submit failed',
            details: result.error?.details,
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        return AeResult.ok(
          result.data!.toJson(),
          warnings: result.warnings,
          meta: result.meta,
        );

      case 'bootstrap-local':
        final aeUsePath = sub['ae-use-path']?.toString() ?? '';
        final result = service.bootstrapLocalRegistry(
          RegistryBootstrapLocalInput(aeUsePath: aeUsePath),
        );
        client.close();

        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'registry_bootstrap_failed',
            message: result.error?.message ?? 'Registry bootstrap failed',
            details: result.error?.details,
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        return AeResult.ok(
          result.data!.toJson(),
          warnings: result.warnings,
          meta: result.meta,
        );
      default:
        client.close();
        return AeResult.fail(
          code: 'invalid_command',
          message: 'Unknown registry subcommand: ${sub.name}',
        );
    }
  }

  Future<AeResult<Map<String, dynamic>>> _handleGenerate(
    final ArgResults command,
  ) async {
    final libraryId = command['library-id']?.toString() ?? '';
    final libraryRoot = command['library-root']?.toString() ?? '';
    if (libraryId.isEmpty || libraryRoot.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: '--library-id and --library-root are required',
      );
    }

    final engineModeRaw = command['engine']?.toString() ?? 'auto';
    final outputDir =
        command['output-dir']?.toString() ?? path.join(libraryRoot, 'ae_use');

    final AeGenerationEngineMode engineMode;
    try {
      engineMode = AeGenerationEngineMode.fromString(engineModeRaw);
    } catch (error) {
      return AeResult.fail(code: 'validation_error', message: error.toString());
    }

    final dryRun = command['dry-run'] == true;
    final codexClient = inferenceClient ??
        CodexExecInferenceClient(
          binaryName: codexBinary ?? 'codex',
          environment: environment,
        );

    final generationService = DefaultAeGenerationService(
      templateEngine: const TemplateGenerationEngine(),
      codexEngine: InferenceGenerationEngine(
        client: codexClient,
      ),
    );

    final generationResult = await generationService.generate(
      GenerateInput(
        libraryId: libraryId,
        libraryRoot: libraryRoot,
        outputDir: outputDir,
        engineMode: engineMode,
        dryRun: dryRun,
      ),
    );

    if (!generationResult.success || generationResult.data == null) {
      return AeResult.fail(
        code: generationResult.error?.code ?? 'generation_failed',
        message: generationResult.error?.message ?? 'Generation failed',
        details: generationResult.error?.details,
        warnings: generationResult.warnings,
        meta: generationResult.meta,
      );
    }

    final output = generationResult.data!;
    final unresolvedWarnings = output.files
        .where((final file) => file.content.contains('TODO:'))
        .map(
          (final file) =>
              'Unresolved placeholder markers found in ${file.path}',
        )
        .toList(growable: false);

    final writtenFiles = <String>[];
    if (!dryRun) {
      final directory = Directory(outputDir);
      await directory.create(recursive: true);

      for (final file in output.files) {
        final filePath = path.join(outputDir, file.path);
        final diskFile = File(filePath);
        await diskFile.writeAsString(file.content);
        writtenFiles.add(filePath);
      }
    }

    return AeResult.ok(
      {
        ...output.toJson(),
        'output_dir': outputDir,
        'dry_run': dryRun,
        'written_files': writtenFiles,
      },
      warnings: [...generationResult.warnings, ...unresolvedWarnings],
      meta: generationResult.meta,
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleSkill(
    final ArgResults command,
  ) async {
    final sub = command.command;
    if (sub == null) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Skill subcommand is required',
      );
    }

    switch (sub.name) {
      case 'install':
        return _handleSkillInstall(sub);
      case 'update':
        return _handleSkillUpdate(sub);
      default:
        return AeResult.fail(
          code: 'invalid_command',
          message: 'Unknown skill subcommand: ${sub.name}',
        );
    }
  }

  Future<AeResult<Map<String, dynamic>>> _handleSkillInstall(
    final ArgResults command,
  ) async {
    final name = command['name'].toString();
    final targetBase = command['target']?.toString() ?? _defaultSkillsBaseDir();
    final force = command['force'] == true;

    final provider = RepoSkillTemplateProvider(repoRoot: _repoRoot());
    final template = await provider.readTemplate();
    final version = await provider.readVersion();

    final skillDir = Directory(path.join(targetBase, name));
    final skillFile = File(path.join(skillDir.path, 'SKILL.md'));

    if (await skillFile.exists() && !force) {
      return AeResult.fail(
        code: 'skill_exists',
        message:
            'Skill already exists at ${skillDir.path}. Use --force to overwrite.',
      );
    }

    await skillDir.create(recursive: true);
    await skillFile.writeAsString(template);

    if (version != null) {
      await File(
        path.join(skillDir.path, '.ae_cli_skill_version'),
      ).writeAsString(version);
    }

    return AeResult.ok(
      {
        'name': name,
        'target': skillDir.path,
        'installed': true,
        'version': version,
      },
      meta: const {'operation': 'skill_install'},
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleSkillUpdate(
    final ArgResults command,
  ) async {
    final name = command['name'].toString();
    final targetBase = command['target']?.toString() ?? _defaultSkillsBaseDir();
    final skillDir = Directory(path.join(targetBase, name));
    final skillFile = File(path.join(skillDir.path, 'SKILL.md'));

    if (!await skillFile.exists()) {
      return AeResult.fail(
        code: 'skill_missing',
        message:
            'Skill not found at ${skillDir.path}. Run skill install first.',
      );
    }

    final provider = RepoSkillTemplateProvider(repoRoot: _repoRoot());
    final template = await provider.readTemplate();
    final newVersion = await provider.readVersion();

    final currentContent = await skillFile.readAsString();
    final currentVersion = await _readInstalledSkillVersion(skillDir.path);

    if (currentContent == template) {
      return AeResult.ok(
        {
          'name': name,
          'target': skillDir.path,
          'updated': false,
          'version': currentVersion,
          'message': 'Skill already up-to-date',
        },
        meta: const {'operation': 'skill_update'},
      );
    }

    final backupDir = Directory(
      '${skillDir.path}.backup.${DateTime.now().millisecondsSinceEpoch}',
    );
    await backupDir.create(recursive: true);
    await skillFile.copy(path.join(backupDir.path, 'SKILL.md'));

    await skillFile.writeAsString(template);

    if (newVersion != null) {
      await File(
        path.join(skillDir.path, '.ae_cli_skill_version'),
      ).writeAsString(newVersion);
    }

    return AeResult.ok(
      {
        'name': name,
        'target': skillDir.path,
        'updated': true,
        'previous_version': currentVersion,
        'version': newVersion,
        'backup_path': backupDir.path,
      },
      meta: const {'operation': 'skill_update'},
    );
  }

  Future<String?> _readInstalledSkillVersion(final String skillDir) async {
    final markerFile = File(path.join(skillDir, '.ae_cli_skill_version'));
    if (await markerFile.exists()) {
      final marker = (await markerFile.readAsString()).trim();
      if (marker.isNotEmpty) {
        return marker;
      }
    }

    final skillFile = File(path.join(skillDir, 'SKILL.md'));
    if (!await skillFile.exists()) {
      return null;
    }
    final content = await skillFile.readAsString();
    final lines = content.split('\n');
    for (final line in lines) {
      final normalized = line.trim();
      if (normalized.startsWith('<!-- ae-cli-skill-version:')) {
        return normalized
            .replaceFirst('<!-- ae-cli-skill-version:', '')
            .replaceFirst('-->', '')
            .trim();
      }
    }
    return null;
  }

  String _defaultSkillsBaseDir() {
    final envMap = environment ?? Platform.environment;
    final codexHome = envMap['CODEX_HOME'];
    if (codexHome != null && codexHome.isNotEmpty) {
      return path.join(codexHome, 'skills');
    }

    final home = envMap['HOME'] ?? envMap['USERPROFILE'];
    if (home == null || home.isEmpty) {
      throw StateError(
        'Unable to resolve home directory for skill target path',
      );
    }

    return path.join(home, '.codex', 'skills');
  }

  String _repoRoot() {
    if (repoRootOverride != null) {
      return repoRootOverride!;
    }

    var current = Directory.current.absolute;
    while (true) {
      final hasPrompts = Directory(
        path.join(current.path, 'prompts_framework'),
      ).existsSync();
      final hasSkillTemplate = File(
        path.join(current.path, 'skills', 'ae-cli', 'SKILL.md'),
      ).existsSync();
      if (hasPrompts || hasSkillTemplate) {
        return current.path;
      }

      final parent = current.parent;
      if (parent.path == current.path) {
        return Directory.current.path;
      }
      current = parent;
    }
  }

  Future<Map<String, dynamic>> _readInputJson(final String source) async {
    final raw = source == '-'
        ? await stdin.transform(utf8.decoder).join()
        : await File(source).readAsString();

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Input JSON must be an object');
    }
    return decoded;
  }

  List _parseList(final Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is List) {
      return value;
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded;
        }
      } catch (_) {
        return value
            .split(',')
            .map((final part) => part.trim())
            .where((final part) => part.isNotEmpty)
            .toList(growable: false);
      }
    }
    return const [];
  }

  Map _parseMap(final Object? value) {
    if (value == null) {
      return const {};
    }
    if (value is Map) {
      return value;
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        return decoded is Map ? decoded : const {};
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  bool _parseBool(final Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  Map<String, dynamic> _resultToEnvelope(
    final String command,
    final AeResult<Map<String, dynamic>> result,
  ) {
    if (!result.success || result.data == null) {
      return _errorEnvelope(
        command: command,
        code: result.error?.code ?? 'command_failed',
        message: result.error?.message ?? 'Command failed',
        details: result.error?.details,
        warnings: result.warnings,
        meta: result.meta,
      );
    }

    return {
      'success': true,
      'command': command,
      'data': result.data,
      'warnings': result.warnings,
      'meta': result.meta,
    };
  }

  Map<String, dynamic> _errorEnvelope({
    required final String command,
    required final String code,
    required final String message,
    final Object? details,
    final List<String> warnings = const [],
    final Map<String, dynamic> meta = const {},
  }) =>
      {
        'success': false,
        'command': command,
        'data': const {},
        'error': {
          'code': code,
          'message': message,
          if (details != null) 'details': details,
        },
        'warnings': warnings,
        'meta': meta,
      };

  void _printHuman(final Map<String, dynamic> envelope) {
    if (envelope['success'] == true) {
      _out.writeln('Success: ${envelope['command']}');
      _out.writeln(
        const JsonEncoder.withIndent('  ').convert(envelope['data']),
      );
      final warnings = envelope['warnings'] as List<dynamic>?;
      if (warnings != null && warnings.isNotEmpty) {
        _out.writeln('Warnings:');
        for (final warning in warnings) {
          _out.writeln('- $warning');
        }
      }
    } else {
      final error = envelope['error'] as Map<String, dynamic>?;
      _err.writeln(
        'Error [${error?['code'] ?? 'unknown'}]: ${error?['message'] ?? 'Unknown error'}',
      );
      if (error?['details'] != null) {
        _err.writeln(error!['details']);
      }
    }
  }
}
