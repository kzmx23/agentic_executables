import 'dart:convert';
import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'doctor/preflight_doctor.dart';
import 'engine/codex_exec_generation_engine.dart';
import 'io/safe_file_writer.dart';
import 'resources/embedded_cli_resources.dart';
import 'resources/embedded_document_store.dart';
import 'resources/skill_template_providers.dart';

class AeCli {
  AeCli({
    IOSink? out,
    IOSink? err,
    this.codexBinary,
    this.environment,
    this.inferenceClient,
    this.registryProbeUrl,
    this.registryClient,
  })  : _out = out ?? stdout,
        _err = err ?? stderr;

  final IOSink _out;
  final IOSink _err;
  final String? codexBinary;
  final Map<String, String>? environment;
  final InferenceClient? inferenceClient;
  final String? registryProbeUrl;
  final RegistryClient? registryClient;

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

    if (_shouldRenderHelp(results)) {
      _out.writeln(_helpText(results, parser));
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
      'versions': {'cli': '3.0.0', 'core': AeCoreConfig.frameworkVersion},
    };

    if (human) {
      _printHuman(envelope);
    } else {
      _out.writeln(jsonEncode(envelope));
    }

    if (commandPath == 'doctor' && envelope['success'] == true) {
      final data = envelope['data'] as Map<String, dynamic>?;
      final overall = data?['overall_status']?.toString();
      return overall == 'fail' ? 1 : 0;
    }

    return envelope['success'] == true ? 0 : 1;
  }

  ArgParser _buildParser() {
    final parser = ArgParser()
      ..addFlag('human', negatable: false, help: 'Readable output mode')
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

    parser.addCommand('definition')?.addFlag(
          'help',
          abbr: 'h',
          negatable: false,
          help: 'Show help',
        );

    parser.addCommand('instructions')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption(
        'context',
        allowed: AeContext.validValues,
        help: 'Context type',
      )
      ..addOption('action', allowed: AeAction.validValues, help: 'Action type')
      ..addOption(
        'resources-path',
        help: 'Optional override path to prompts resources',
      );

    parser.addCommand('verify')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption(
        'input',
        defaultsTo: '-',
        help: 'JSON file path or - for stdin',
      );

    parser.addCommand('evaluate')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption(
        'input',
        defaultsTo: '-',
        help: 'JSON file path or - for stdin',
      );

    parser.addCommand('doctor')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption(
        'target',
        help: 'Override target skill directory checked for writability',
      );

    final registry = parser.addCommand('registry')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');
    registry?.addCommand('get')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('library-id', help: 'Library id')
      ..addOption(
        'action',
        allowed: AeAction.registryActions,
        help: 'Registry action',
      )
      ..addOption('out', help: 'Write fetched file to output path')
      ..addFlag('check', negatable: false, help: 'Detect drift without writes')
      ..addFlag('diff', negatable: false, help: 'Emit unified diff metadata')
      ..addFlag(
        'backup',
        negatable: false,
        help: 'Create timestamped backup before overwrite',
      )
      ..addFlag(
        'no-overwrite',
        negatable: false,
        help: 'Block overwriting existing files',
      );

    registry?.addCommand('submit')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('library-url', help: 'Library repository URL')
      ..addOption('library-id', help: 'Library id')
      ..addMultiOption(
        'ae-use-files',
        splitCommas: true,
        help: 'AE file list (CSV or repeated flag)',
      );

    registry?.addCommand('bootstrap-local')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('ae-use-path', help: 'Path to ae_use directory');

    parser.addCommand('generate')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('library-id', help: 'Library id')
      ..addOption('library-root', help: 'Library root path')
      ..addOption('output-dir', help: 'Output directory for generated files')
      ..addOption(
        'engine',
        allowed: AeGenerationEngineMode.validValues,
        defaultsTo: AeGenerationEngineMode.auto.value,
        help: 'Generation engine mode',
      )
      ..addFlag('dry-run', negatable: false, help: 'Do not write files')
      ..addFlag('check', negatable: false, help: 'Detect drift without writes')
      ..addFlag('diff', negatable: false, help: 'Emit unified diff metadata')
      ..addFlag(
        'backup',
        negatable: false,
        help: 'Create timestamped backup before overwrite',
      )
      ..addFlag(
        'no-overwrite',
        negatable: false,
        help: 'Block overwriting existing files',
      );

    final skill = parser.addCommand('skill')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');
    skill?.addCommand('install')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('target', help: 'Skills directory target')
      ..addOption('name', defaultsTo: 'ae-cli', help: 'Skill folder name')
      ..addFlag('upgrade', negatable: false, help: 'Upgrade existing skill')
      ..addOption(
        'template-path',
        help: 'Optional override path to SKILL.md template',
      );

    skill?.addCommand('update')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('target', help: 'Skills directory target')
      ..addOption('name', defaultsTo: 'ae-cli', help: 'Skill folder name')
      ..addOption(
        'template-path',
        help: 'Optional override path to SKILL.md template',
      );

    return parser;
  }

  bool _shouldRenderHelp(final ArgResults root) {
    if (root.command == null) {
      return true;
    }

    if (root['help'] == true) {
      return true;
    }

    var current = root.command!;
    while (true) {
      if (current['help'] == true) {
        return true;
      }
      if (current.command == null) {
        return false;
      }
      current = current.command!;
    }
  }

  String _helpText(final ArgResults root, final ArgParser parser) {
    if (root.command == null || root['help'] == true && root.command == null) {
      return _globalUsage(parser);
    }

    final segments = <String>[];
    var current = root.command!;
    while (true) {
      final name = current.name;
      if (name != null) {
        segments.add(name);
      }
      if (current.command == null) {
        break;
      }
      current = current.command!;
    }

    final commandPath = segments.join(' ');
    return _contextualHelp(commandPath);
  }

  String _globalUsage(final ArgParser parser) => '''
ae CLI v3

${parser.usage}

Run `ae <command> --help` for contextual command help and examples.

Commands:
  ae definition
  ae instructions --context <library|project> --action <...> [--resources-path <path>]
  ae verify --input <json-file|->
  ae evaluate --input <json-file|->
  ae doctor [--target <skills-dir>]
  ae registry get --library-id <id> --action <install|uninstall|update|use> [--out <path>] [--check] [--diff] [--backup] [--no-overwrite]
  ae registry submit --library-url <url> --library-id <id> --ae-use-files <csv|repeatable>
  ae registry bootstrap-local --ae-use-path <path>
  ae generate --library-id <id> --library-root <path> [--output-dir <path>] [--engine auto|codex|template] [--dry-run] [--check] [--diff] [--backup] [--no-overwrite]
  ae skill install [--target <skills-dir>] [--name ae-cli] [--upgrade] [--template-path <path>]
  ae skill update [--target <skills-dir>] [--name ae-cli] [--template-path <path>]
''';

  String _contextualHelp(final String commandPath) {
    switch (commandPath) {
      case 'definition':
        return '''
Usage: ae definition

Returns AE framework definition and capability matrix.

Example:
  ae definition
''';
      case 'instructions':
        return '''
Usage: ae instructions --context <library|project> --action <bootstrap|install|uninstall|update|use> [--resources-path <path>]

Options:
  --context         Required context type.
  --action          Required action type.
  --resources-path  Optional filesystem override for prompt documents.

Examples:
  ae instructions --context library --action bootstrap
  ae instructions --context project --action install
''';
      case 'verify':
        return '''
Usage: ae verify --input <json-file|->

Examples:
  ae verify --input verify.json
  cat verify.json | ae verify --input -
''';
      case 'evaluate':
        return '''
Usage: ae evaluate --input <json-file|->

Examples:
  ae evaluate --input evaluate.json
  cat evaluate.json | ae evaluate --input -
''';
      case 'doctor':
        return '''
Usage: ae doctor [--target <skills-dir>]

Performs CLI preflight checks for:
- Codex availability (warning)
- Dart SDK availability (warning)
- Skill target writability (critical)
- Registry reachability (critical)

Examples:
  ae doctor
  ae doctor --target ~/.codex/skills
''';
      case 'registry':
        return '''
Usage: ae registry <get|submit|bootstrap-local> [options]

Subcommands:
  ae registry get --help
  ae registry submit --help
  ae registry bootstrap-local --help
''';
      case 'registry get':
        return '''
Usage: ae registry get --library-id <id> --action <install|uninstall|update|use> [--out <path>] [--check] [--diff] [--backup] [--no-overwrite]

Options:
  --out           Optional output destination.
  --check         Detect drift and skip writes.
  --diff          Include unified diff metadata for changes.
  --backup        Backup overwritten files to timestamped copies.
  --no-overwrite  Block overwrites of existing files.

Examples:
  ae registry get --library-id python_requests --action install
  ae registry get --library-id python_requests --action install --out ./ae_use
  ae registry get --library-id python_requests --action install --out ./ae_use --check --diff
''';
      case 'registry submit':
        return '''
Usage: ae registry submit --library-url <url> --library-id <id> --ae-use-files <csv|repeatable>

Example:
  ae registry submit --library-url https://github.com/example/lib --library-id dart_provider --ae-use-files ae_use/ae_install.md,ae_use/ae_uninstall.md,ae_use/ae_update.md,ae_use/ae_use.md
''';
      case 'registry bootstrap-local':
        return '''
Usage: ae registry bootstrap-local --ae-use-path <path>

Example:
  ae registry bootstrap-local --ae-use-path ./ae_use
''';
      case 'generate':
        return '''
Usage: ae generate --library-id <id> --library-root <path> [--output-dir <path>] [--engine auto|codex|template] [--dry-run] [--check] [--diff] [--backup] [--no-overwrite]

Options:
  --check         Detect drift and skip writes.
  --diff          Include unified diff metadata for changes.
  --backup        Backup overwritten files to timestamped copies.
  --no-overwrite  Block overwrites of existing files.

Examples:
  ae generate --library-id dart_provider --library-root . --engine auto
  ae generate --library-id dart_provider --library-root . --engine template --check --diff
''';
      case 'skill':
        return '''
Usage: ae skill <install|update> [options]

Subcommands:
  ae skill install --help
  ae skill update --help
''';
      case 'skill install':
        return '''
Usage: ae skill install [--target <skills-dir>] [--name ae-cli] [--upgrade] [--template-path <path>]

Behavior:
- Missing skill: install.
- Same template content: success with no_op=true.
- Different installed content: fail with skill_upgrade_required unless --upgrade is provided.

Examples:
  ae skill install
  ae skill install --target ~/.codex/skills --name ae-cli
  ae skill install --upgrade
''';
      case 'skill update':
        return '''
Usage: ae skill update [--target <skills-dir>] [--name ae-cli] [--template-path <path>]

Compatibility wrapper for upgrade semantics.

Examples:
  ae skill update
  ae skill update --target ~/.codex/skills
''';
      default:
        return 'No contextual help found for "$commandPath"';
    }
  }

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
      case 'doctor':
        return _handleDoctor(command);
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

    final resourcesPath = command['resources-path']?.toString();
    final documentStore = resourcesPath == null || resourcesPath.isEmpty
        ? EmbeddedDocumentStore(EmbeddedCliResources.prompts)
        : FileDocumentStore(resourcesPath);

    final service = DefaultAeInstructionService(documentStore);
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
      meta: {
        ...result.meta,
        if (resourcesPath == null || resourcesPath.isEmpty)
          'resources_source': 'embedded',
        if (resourcesPath != null && resourcesPath.isNotEmpty)
          'resources_path': resourcesPath,
      },
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

  Future<AeResult<Map<String, dynamic>>> _handleDoctor(
    final ArgResults command,
  ) async {
    final target = command['target']?.toString() ?? _defaultSkillsBaseDir();

    final doctor = AeDoctor(
      codexBinary: codexBinary ?? 'codex',
      environment: environment,
      registryProbeUrl: registryProbeUrl,
    );

    final output = await doctor.run(skillTarget: target);

    return AeResult.ok(
      output.toJson(),
      meta: const {'operation': 'doctor'},
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

    final client = registryClient ?? GitHubRawRegistryClient();
    final ownsClient = registryClient == null;
    final service = DefaultAeRegistryService(client);
    void closeClient() {
      if (!ownsClient) {
        return;
      }
      if (client is GitHubRawRegistryClient) {
        client.close();
      }
    }

    switch (sub.name) {
      case 'get':
        final libraryId = sub['library-id']?.toString() ?? '';
        final actionRaw = sub['action']?.toString() ?? '';
        if (actionRaw.isEmpty) {
          closeClient();
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing required argument: --action',
          );
        }

        final AeAction action;
        try {
          action = AeAction.fromString(actionRaw);
        } catch (error) {
          closeClient();
          return AeResult.fail(
            code: 'validation_error',
            message: error.toString(),
          );
        }

        final result = await service.getFromRegistry(
          RegistryGetInput(libraryId: libraryId, action: action),
        );

        if (!result.success || result.data == null) {
          closeClient();
          return AeResult.fail(
            code: result.error?.code ?? 'registry_get_failed',
            message: result.error?.message ?? 'Registry get failed',
            details: result.error?.details,
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        final outPathRaw = sub['out']?.toString();
        if (outPathRaw == null || outPathRaw.isEmpty) {
          closeClient();
          return AeResult.ok(
            result.data!.toJson(),
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        final String resolvedOut;
        try {
          resolvedOut = _resolveRegistryOutPath(outPathRaw, action);
        } catch (error) {
          closeClient();
          return AeResult.fail(
            code: 'validation_error',
            message: error.toString(),
          );
        }
        final writeOptions = _safeWriteOptions(sub);
        final writeResult = await const SafeFileWriter().writeAll(
          requests: [
            FileWriteRequest(path: resolvedOut, content: result.data!.content),
          ],
          options: writeOptions,
        );

        closeClient();

        if (writeOptions.check && writeResult.hasChanges) {
          return AeResult.fail(
            code: 'check_mode_changes_detected',
            message: 'Changes detected in --check mode',
            details: writeResult.toJson(),
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        if (writeResult.hasBlocked) {
          return AeResult.fail(
            code: 'write_conflict_no_overwrite',
            message: 'One or more writes were blocked by --no-overwrite',
            details: writeResult.toJson(),
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        return AeResult.ok(
          {
            ...result.data!.toJson(),
            'out_path': resolvedOut,
            'write': writeResult.toJson(),
            'no_op': !writeResult.hasChanges,
          },
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
        closeClient();

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
        closeClient();

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
        closeClient();
        return AeResult.fail(
          code: 'invalid_command',
          message: 'Unknown registry subcommand: ${sub.name}',
        );
    }
  }

  String _resolveRegistryOutPath(final String out, final AeAction action) {
    final normalized = path.normalize(out);
    final entityType = FileSystemEntity.typeSync(normalized);

    final looksDirectory = normalized.endsWith(path.separator) ||
        path.extension(path.basename(normalized)).isEmpty;

    if (entityType == FileSystemEntityType.directory ||
        (entityType == FileSystemEntityType.notFound && looksDirectory)) {
      return path.join(normalized, action.fileName);
    }

    if (entityType == FileSystemEntityType.file && looksDirectory) {
      throw ArgumentError(
        'Path "$normalized" looks like a directory but already exists as a file',
      );
    }

    return normalized;
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
    final writeOptions = _safeWriteOptions(command);

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

    if (dryRun && !writeOptions.check) {
      return AeResult.ok(
        {
          ...output.toJson(),
          'output_dir': outputDir,
          'dry_run': true,
          'write': {
            'files': const [],
            'has_changes': false,
            'has_blocked': false,
            'wrote_any': false,
          },
          'no_op': false,
        },
        warnings: [...generationResult.warnings, ...unresolvedWarnings],
        meta: generationResult.meta,
      );
    }

    final requests = output.files
        .map(
          (final file) => FileWriteRequest(
            path: path.join(outputDir, file.path),
            content: file.content,
          ),
        )
        .toList(growable: false);

    final effectiveOptions = dryRun
        ? SafeWriteOptions(
            check: true,
            diff: writeOptions.diff,
            backup: false,
            noOverwrite: writeOptions.noOverwrite,
          )
        : writeOptions;

    final writeResult = await const SafeFileWriter().writeAll(
      requests: requests,
      options: effectiveOptions,
    );

    if (writeOptions.check && writeResult.hasChanges) {
      return AeResult.fail(
        code: 'check_mode_changes_detected',
        message: 'Changes detected in --check mode',
        details: writeResult.toJson(),
        warnings: [...generationResult.warnings, ...unresolvedWarnings],
        meta: generationResult.meta,
      );
    }

    if (writeResult.hasBlocked) {
      return AeResult.fail(
        code: 'write_conflict_no_overwrite',
        message: 'One or more writes were blocked by --no-overwrite',
        details: writeResult.toJson(),
        warnings: [...generationResult.warnings, ...unresolvedWarnings],
        meta: generationResult.meta,
      );
    }

    return AeResult.ok(
      {
        ...output.toJson(),
        'output_dir': outputDir,
        'dry_run': dryRun,
        'write': writeResult.toJson(),
        'no_op': !writeResult.hasChanges,
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
    return _installOrUpgradeSkill(
      name: command['name'].toString(),
      targetBase: command['target']?.toString() ?? _defaultSkillsBaseDir(),
      upgrade: command['upgrade'] == true,
      templatePath: command['template-path']?.toString(),
      operation: 'skill_install',
      requireExisting: false,
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleSkillUpdate(
    final ArgResults command,
  ) async {
    return _installOrUpgradeSkill(
      name: command['name'].toString(),
      targetBase: command['target']?.toString() ?? _defaultSkillsBaseDir(),
      upgrade: true,
      templatePath: command['template-path']?.toString(),
      operation: 'skill_update',
      requireExisting: true,
    );
  }

  Future<AeResult<Map<String, dynamic>>> _installOrUpgradeSkill({
    required final String name,
    required final String targetBase,
    required final bool upgrade,
    required final String operation,
    required final bool requireExisting,
    final String? templatePath,
  }) async {
    final SkillTemplateProvider provider;
    if (templatePath != null && templatePath.isNotEmpty) {
      provider = FileSkillTemplateProvider(templatePath);
    } else {
      provider = const EmbeddedSkillTemplateProvider();
    }

    final String template;
    final String? version;
    try {
      template = await provider.readTemplate();
      version = await provider.readVersion();
    } catch (error) {
      return AeResult.fail(
        code: 'skill_template_load_failed',
        message: 'Failed to load skill template',
        details: error.toString(),
      );
    }

    final skillDir = Directory(path.join(targetBase, name));
    final skillFile = File(path.join(skillDir.path, 'SKILL.md'));

    final exists = await skillFile.exists();
    if (!exists && requireExisting) {
      return AeResult.fail(
        code: 'skill_missing',
        message:
            'Skill not found at ${skillDir.path}. Run skill install first.',
      );
    }

    if (!exists) {
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
          'upgraded': false,
          'version': version,
          'no_op': false,
        },
        meta: {'operation': operation},
      );
    }

    final currentContent = await skillFile.readAsString();
    final currentVersion = await _readInstalledSkillVersion(skillDir.path);

    if (currentContent == template) {
      return AeResult.ok(
        {
          'name': name,
          'target': skillDir.path,
          'installed': false,
          'upgraded': false,
          'version': currentVersion,
          'no_op': true,
          'message': 'Skill already up-to-date',
        },
        meta: {'operation': operation},
      );
    }

    if (!upgrade) {
      return AeResult.fail(
        code: 'skill_upgrade_required',
        message:
            'Skill at ${skillDir.path} differs from bundled template. Re-run with --upgrade to replace it.',
        details: {
          'name': name,
          'target': skillDir.path,
          'installed_version': currentVersion,
          'available_version': version,
        },
      );
    }

    final backupDir = Directory(
      '${skillDir.path}.backup.${DateTime.now().millisecondsSinceEpoch}',
    );
    await _copyDirectory(skillDir, backupDir);

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
        'installed': false,
        'upgraded': true,
        'previous_version': currentVersion,
        'version': version,
        'backup_path': backupDir.path,
        'no_op': false,
      },
      meta: {'operation': operation},
    );
  }

  Future<void> _copyDirectory(
    final Directory source,
    final Directory destination,
  ) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: true)) {
      final relative = path.relative(entity.path, from: source.path);
      final targetPath = path.join(destination.path, relative);

      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
        continue;
      }
      if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }
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

  SafeWriteOptions _safeWriteOptions(final ArgResults command) {
    return SafeWriteOptions(
      check: command['check'] == true,
      diff: command['diff'] == true,
      backup: command['backup'] == true,
      noOverwrite: command['no-overwrite'] == true,
    );
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
